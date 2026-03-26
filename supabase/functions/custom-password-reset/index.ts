// custom-password-reset/index.ts
// Edge Function — custom password reset that routes the reset link to the
// user's personal email (for staff whose corporate emails have no real mailbox).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface Payload {
  email: string;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function buildResetEmailHtml(recipientName: string, resetLink: string): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Password Reset — Maison Luxe</title>
</head>
<body style="margin:0;padding:0;background-color:#f5f5f5;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f5f5f5;padding:40px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
          <!-- Header -->
          <tr>
            <td style="background-color:#1a1a1a;padding:32px 40px;text-align:center;">
              <h1 style="margin:0;font-size:28px;font-weight:300;letter-spacing:4px;color:#ffffff;">MAISON LUXE</h1>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:40px;">
              <h2 style="margin:0 0 16px;font-size:22px;font-weight:400;color:#333333;">Password Reset Request</h2>
              <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#555555;">
                Hi${recipientName ? " " + recipientName : ""},<br/><br/>
                We received a request to reset your Maison Luxe account password. Click the button below to set a new password:
              </p>
              <!-- CTA Button -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr>
                  <td align="center">
                    <a href="${resetLink}" style="display:inline-block;padding:14px 40px;background-color:#1a1a1a;color:#ffffff;text-decoration:none;font-size:15px;font-weight:500;letter-spacing:1px;border-radius:4px;">RESET PASSWORD</a>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 16px;font-size:14px;line-height:1.6;color:#555555;">
                If the button above does not work, copy and paste this link into your browser:
              </p>
              <p style="margin:0 0 24px;font-size:13px;line-height:1.6;color:#888888;word-break:break-all;">
                ${resetLink}
              </p>
              <p style="margin:0;font-size:14px;line-height:1.6;color:#555555;">
                If you did not request a password reset, you can safely ignore this email. Your password will remain unchanged.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color:#fafafa;border-top:1px solid #e8e8e8;padding:24px 40px;text-align:center;">
              <p style="margin:0 0 4px;font-size:12px;color:#999999;">Maison Luxe &mdash; Luxury Retail Management</p>
              <p style="margin:0;font-size:12px;color:#999999;">For support, contact <a href="mailto:support@maisonluxe.me" style="color:#666666;">support@maisonluxe.me</a></p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`.trim();
}

async function sendResetEmail(
  resendApiKey: string,
  toEmail: string,
  recipientName: string,
  resetLink: string,
): Promise<void> {
  const htmlBody = buildResetEmailHtml(recipientName, resetLink);

  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Maison Luxe <noreply@maisonluxe.me>",
      to: [toEmail],
      subject: "Reset Your Maison Luxe Password",
      html: htmlBody,
    }),
  });

  if (!resendResponse.ok) {
    const errBody = await resendResponse.text();
    console.error("[custom-password-reset] Resend API error:", resendResponse.status, errBody);
    throw new Error("Failed to send reset email: " + errBody);
  }

  const resendData = await resendResponse.json();
  console.log("[custom-password-reset] Reset email sent:", resendData.id);
}

serve(async (req: Request) => {
  // CORS pre-flight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. No JWT validation — user is not logged in ────────────────────────

    // ── 2. Parse payload ────────────────────────────────────────────────────
    const payload: Payload = await req.json();

    if (!payload.email) {
      return json({ error: "Missing required field: email" }, 400);
    }

    const email = payload.email.trim().toLowerCase();

    // ── 3. Resend API key check ─────────────────────────────────────────────
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (!resendApiKey) {
      console.error("[custom-password-reset] RESEND_API_KEY not configured");
      return json({ error: "Email service not configured" }, 500);
    }

    // ── 4. Admin client — bypasses RLS ──────────────────────────────────────
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // ── 5. Look up email in users table (check both email and corporate_email) ──
    const { data: userByEmail } = await admin
      .from("users")
      .select("id, email, corporate_email, personal_email, first_name, last_name")
      .or(`email.ilike.${email},corporate_email.ilike.${email}`)
      .maybeSingle();

    if (userByEmail && userByEmail.personal_email) {
      // ── 5a. Staff / known user with personal_email ────────────────────────
      const authEmail = userByEmail.email; // the Supabase Auth email
      const personalEmail = userByEmail.personal_email;
      const recipientName = [userByEmail.first_name, userByEmail.last_name].filter(Boolean).join(" ");

      console.log(`[custom-password-reset] Found user in users table. Auth email: ${authEmail}, sending to personal: ${personalEmail}`);

      const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
        type: "recovery",
        email: authEmail,
        options: {
          redirectTo: "maisonluxe://login-callback",
        },
      });

      if (linkError || !linkData) {
        console.error("[custom-password-reset] generateLink failed:", linkError?.message);
        // Return success anyway to not reveal account existence
        return json({ success: true, message: "If an account exists, a reset link has been sent." });
      }

      const resetLink = linkData.properties?.action_link ?? "";
      if (!resetLink) {
        console.error("[custom-password-reset] No action_link in generateLink response");
        return json({ success: true, message: "If an account exists, a reset link has been sent." });
      }

      await sendResetEmail(resendApiKey, personalEmail, recipientName, resetLink);

      return json({ success: true, message: "Reset link sent to your registered email" });
    }

    if (!userByEmail) {
      // ── 6. Not found in users table — likely a customer ───────────────────
      console.log(`[custom-password-reset] Email not in users table, treating as customer: ${email}`);

      const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
        type: "recovery",
        email: email,
        options: {
          redirectTo: "maisonluxe://login-callback",
        },
      });

      if (linkError || !linkData) {
        console.error("[custom-password-reset] generateLink failed for customer:", linkError?.message);
        // Return success to not reveal whether account exists
        return json({ success: true, message: "If an account exists, a reset link has been sent." });
      }

      const resetLink = linkData.properties?.action_link ?? "";
      if (!resetLink) {
        console.error("[custom-password-reset] No action_link for customer");
        return json({ success: true, message: "If an account exists, a reset link has been sent." });
      }

      await sendResetEmail(resendApiKey, email, "", resetLink);

      return json({ success: true, message: "Reset link sent" });
    }

    // ── 7. Found in users table but no personal_email — edge case ───────────
    // Still return success for security (don't reveal account existence)
    console.warn(`[custom-password-reset] User found but no personal_email: ${userByEmail.id}`);
    return json({ success: true, message: "If an account exists, a reset link has been sent." });

  } catch (err) {
    console.error("[custom-password-reset] Unexpected error:", err);
    return json({ error: String(err) }, 500);
  }
});
