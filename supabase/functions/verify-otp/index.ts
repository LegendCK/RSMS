// verify-otp/index.ts
// Edge Function — verifies a 6-digit OTP code against the otp_codes table.
// Returns { verified: true } if valid, { verified: false } otherwise.
// verify_jwt is OFF — called during login flow.

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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, code } = await req.json();

    if (!email || !code) {
      return json({ error: "Missing email or code", verified: false }, 400);
    }

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Find matching OTP: correct email + code, not used, not expired
    const { data: otpRecords, error } = await adminClient
      .from("otp_codes")
      .select("id, expires_at")
      .eq("email", email.toLowerCase())
      .eq("code", code)
      .eq("used", false)
      .order("created_at", { ascending: false })
      .limit(1);

    if (error) {
      console.error("[verify-otp] DB query error:", error);
      return json({ verified: false, error: "Verification failed" }, 500);
    }

    if (!otpRecords || otpRecords.length === 0) {
      console.log(`[verify-otp] No matching OTP for ${email}`);
      return json({ verified: false });
    }

    const otp = otpRecords[0];

    // Check expiry
    if (new Date(otp.expires_at) < new Date()) {
      console.log(`[verify-otp] OTP expired for ${email}`);
      // Mark as used so it can't be retried
      await adminClient
        .from("otp_codes")
        .update({ used: true })
        .eq("id", otp.id);
      return json({ verified: false });
    }

    // Mark OTP as used
    await adminClient
      .from("otp_codes")
      .update({ used: true })
      .eq("id", otp.id);

    console.log(`[verify-otp] OTP verified for ${email}`);
    return json({ verified: true });
  } catch (err) {
    console.error("[verify-otp] Unexpected error:", err);
    return json({ verified: false, error: String(err) }, 500);
  }
});
