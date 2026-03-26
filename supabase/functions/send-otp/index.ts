// send-otp/index.ts
// Edge Function — generates a 6-digit OTP, stores it in the otp_codes table,
// and sends it to the customer's email via Resend API.
// verify_jwt is OFF — called during login before full session is established.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

function generateOTP(): string {
  const digits = "0123456789";
  let otp = "";
  for (let i = 0; i < 6; i++) {
    otp += digits[Math.floor(Math.random() * 10)];
  }
  return otp;
}

function buildOTPHtml(code: string): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Maison Luxe - Verification Code</title>
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
              <h2 style="margin:0 0 16px;font-size:22px;font-weight:400;color:#333333;">Verification Code</h2>
              <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#555555;">
                Use the following code to verify your identity. This code expires in <strong>10 minutes</strong>.
              </p>
              <!-- OTP Box -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr>
                  <td align="center">
                    <div style="display:inline-block;background-color:#fafafa;border:2px solid #1a1a1a;border-radius:8px;padding:20px 40px;">
                      <span style="font-size:36px;font-weight:700;letter-spacing:12px;color:#1a1a1a;font-family:monospace;">${code}</span>
                    </div>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 8px;font-size:14px;line-height:1.6;color:#555555;">
                If you did not request this code, please ignore this email.
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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email } = await req.json();

    if (!email) {
      return json({ error: "Missing email" }, 400);
    }

    // Use service role client for DB operations
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Invalidate any existing unused OTPs for this email
    await adminClient
      .from("otp_codes")
      .update({ used: true })
      .eq("email", email.toLowerCase())
      .eq("used", false);

    // Generate and store new OTP (expires in 10 minutes)
    const code = generateOTP();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { error: insertError } = await adminClient
      .from("otp_codes")
      .insert({
        email: email.toLowerCase(),
        code,
        expires_at: expiresAt,
        used: false,
      });

    if (insertError) {
      console.error("[send-otp] DB insert error:", insertError);
      return json({ error: "Failed to generate OTP" }, 500);
    }

    // Send via Resend
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (!resendApiKey) {
      console.error("[send-otp] RESEND_API_KEY not configured");
      return json({ error: "Email service not configured" }, 500);
    }

    console.log(`[send-otp] Sending OTP to ${email}`);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Maison Luxe <noreply@maisonluxe.me>",
        to: [email.toLowerCase()],
        subject: "Your Maison Luxe Verification Code",
        html: buildOTPHtml(code),
      }),
    });

    if (!resendResponse.ok) {
      const errBody = await resendResponse.text();
      console.error("[send-otp] Resend API error:", resendResponse.status, errBody);
      return json({ error: "Failed to send email" }, 500);
    }

    const resendData = await resendResponse.json();
    console.log("[send-otp] Email sent successfully:", resendData.id);

    return json({ success: true });
  } catch (err) {
    console.error("[send-otp] Unexpected error:", err);
    return json({ error: String(err) }, 500);
  }
});
