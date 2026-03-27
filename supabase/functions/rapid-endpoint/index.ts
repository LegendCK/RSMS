// rapid-endpoint/index.ts
// Edge Function — creates a Stripe PaymentIntent for client-side PaymentSheet.
// Returns { clientSecret, paymentIntentId, status }.
//
// Env vars required (Supabase Dashboard -> Edge Functions -> Secrets):
//   STRIPE_SECRET_KEY   — sk_test_... or sk_live_...

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

interface CreatePaymentIntentPayload {
  amount: number;       // Amount in smallest currency unit (e.g. paise for INR)
  currency?: string;    // ISO 4217, defaults to "inr"
  orderId?: string;     // Optional — linked order UUID for metadata
  description?: string; // Optional — shown on Stripe dashboard
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
    const payload: CreatePaymentIntentPayload = await req.json();

    if (!payload.amount || payload.amount <= 0) {
      return json({ error: "Amount must be a positive number (in smallest currency unit, e.g. paise)" }, 400);
    }

    const currency = (payload.currency ?? "inr").toLowerCase();
    const amountInt = Math.round(payload.amount);

    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      console.error("[rapid-endpoint] STRIPE_SECRET_KEY not set in env");
      return json({ error: "Stripe is not configured on the server" }, 500);
    }

    const params = new URLSearchParams();
    params.append("amount", String(amountInt));
    params.append("currency", currency);
    params.append("automatic_payment_methods[enabled]", "true");

    if (payload.description) {
      params.append("description", payload.description);
    }
    if (payload.orderId) {
      params.append("metadata[order_id]", payload.orderId);
    }

    console.log(`[rapid-endpoint] Creating PaymentIntent — amount: ${amountInt} ${currency}`);

    const stripeResponse = await fetch("https://api.stripe.com/v1/payment_intents", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${stripeSecretKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
    });

    const stripeData = await stripeResponse.json();

    if (!stripeResponse.ok) {
      console.error("[rapid-endpoint] Stripe error:", JSON.stringify(stripeData));
      return json({
        error: stripeData.error?.message ?? "Failed to create payment intent",
        stripeStatus: stripeResponse.status,
        stripeCode: stripeData.error?.code ?? null,
        stripeDeclineCode: stripeData.error?.decline_code ?? null,
        stripeType: stripeData.error?.type ?? null,
      }, 200);
    }

    console.log(`[rapid-endpoint] ✅ PaymentIntent created: ${stripeData.id} status=${stripeData.status}`);

    return json({
      clientSecret: stripeData.client_secret,
      paymentIntentId: stripeData.id,
      status: stripeData.status,
      amount: amountInt,
      currency,
    });
  } catch (err) {
    console.error("[rapid-endpoint] Unexpected error:", err);
    return json({ error: String(err) }, 500);
  }
});
