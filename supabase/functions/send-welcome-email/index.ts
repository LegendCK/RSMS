// send-welcome-email/index.ts
// Edge Function — sends a branded welcome email with login credentials
// to a new user's personal email via the Resend API.
// verify_jwt is OFF because this is called during session juggling
// (admin session → new user signUp → restore admin), so the JWT may be in flux.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

interface Payload {
  personalEmail: string;
  corporateEmail?: string;
  recipientName: string;
  temporaryPassword: string;
  accountType: "staff" | "client";
  roleName?: string;
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

function buildWelcomeHtml(payload: Payload): string {
  const isStaff = payload.accountType === "staff";
  const loginUsername = isStaff && payload.corporateEmail
    ? payload.corporateEmail
    : payload.personalEmail;
  const roleLabel = payload.roleName ? ` as <strong>${payload.roleName}</strong>` : "";

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Welcome to Maison Luxe</title>
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
              <h2 style="margin:0 0 16px;font-size:22px;font-weight:400;color:#333333;">Welcome, ${payload.recipientName}!</h2>
              <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#555555;">
                Your Maison Luxe account has been created${roleLabel}. Below are your login credentials:
              </p>
              <!-- Credentials Box -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#fafafa;border:1px solid #e8e8e8;border-radius:6px;margin-bottom:24px;">
                <tr>
                  <td style="padding:24px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding-bottom:12px;">
                          <span style="font-size:12px;text-transform:uppercase;letter-spacing:1px;color:#999999;">Username</span><br/>
                          <span style="font-size:16px;font-weight:600;color:#333333;">${loginUsername}</span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          <span style="font-size:12px;text-transform:uppercase;letter-spacing:1px;color:#999999;">Temporary Password</span><br/>
                          <span style="font-size:16px;font-weight:600;color:#333333;font-family:monospace;">${payload.temporaryPassword}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 8px;font-size:14px;line-height:1.6;color:#555555;">
                <strong>Important:</strong> You will be prompted to set a new password on your first login. Please change your password immediately for security purposes.
              </p>
              <p style="margin:0;font-size:14px;line-height:1.6;color:#555555;">
                If you have any questions, please contact the Maison Luxe support team.
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

serve(async (req: Request) => {
  // CORS pre-flight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Parse payload ────────────────────────────────────────────────────
    const payload: Payload = await req.json();

    if (!payload.personalEmail || !payload.recipientName || !payload.temporaryPassword || !payload.accountType) {
      return json({ error: "Missing required fields: personalEmail, recipientName, temporaryPassword, accountType" }, 400);
    }

    // ── 2. Build email HTML ─────────────────────────────────────────────────
    const htmlBody = buildWelcomeHtml(payload);
    const subject = payload.accountType === "staff"
      ? "Welcome to Maison Luxe — Your Staff Account"
      : "Welcome to Maison Luxe — Your Account";

    // ── 3. Send via Resend API ──────────────────────────────────────────────
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (!resendApiKey) {
      console.error("[send-welcome-email] RESEND_API_KEY not configured");
      return json({ error: "Email service not configured" }, 500);
    }

    console.log(`[send-welcome-email] Sending to ${payload.personalEmail} for ${payload.accountType} account`);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Maison Luxe <noreply@maisonluxe.me>",
        to: [payload.personalEmail],
        subject,
        html: htmlBody,
      }),
    });

    if (!resendResponse.ok) {
      const errBody = await resendResponse.text();
      console.error("[send-welcome-email] Resend API error:", resendResponse.status, errBody);
      return json({ error: "Failed to send email: " + errBody }, 500);
    }

    const resendData = await resendResponse.json();
    console.log("[send-welcome-email] Email sent successfully:", resendData.id);

    return json({ success: true });
  } catch (err) {
    console.error("[send-welcome-email] Unexpected error:", err);
    return json({ error: String(err) }, 500);
  }
});
