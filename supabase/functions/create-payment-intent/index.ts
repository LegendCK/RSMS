// create-payment-intent/index.ts
// Edge Function — creates + confirms a Stripe PaymentIntent for card checkout.
// Returns { clientSecret, paymentIntentId, status }.
//
// Env vars required (set via Supabase Dashboard → Edge Functions → Secrets):
//   STRIPE_SECRET_KEY   — sk_test_... or sk_live_...

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

interface CardDetails {
  number: string;
  expMonth: number;
  expYear: number;
  cvc: string;
}

interface CreatePaymentIntentPayload {
  amount: number;       // Amount in smallest currency unit (e.g. paise for INR)
  currency?: string;    // ISO 4217, defaults to "inr"
  orderId?: string;     // Optional — linked order UUID for metadata
  description?: string; // Optional — shown on Stripe dashboard
  card?: CardDetails;   // Required for direct card confirmation in this flow
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

    if (!payload.card?.number || !payload.card?.expMonth || !payload.card?.expYear || !payload.card?.cvc) {
      return json({ error: "Missing card details" }, 400);
    }

    const currency = (payload.currency ?? "inr").toLowerCase();
    const amountInt = Math.round(payload.amount);

    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      console.error("[create-payment-intent] STRIPE_SECRET_KEY not set in env");
      return json({ error: "Stripe is not configured on the server" }, 500);
    }

    const cardNumber = payload.card.number.replace(/\s+/g, "");

    const params = new URLSearchParams();
    params.append("amount", String(amountInt));
    params.append("currency", currency);
    params.append("confirm", "true");
    params.append("payment_method_data[type]", "card");
    params.append("payment_method_data[card][number]", cardNumber);
    params.append("payment_method_data[card][exp_month]", String(payload.card.expMonth));
    params.append("payment_method_data[card][exp_year]", String(payload.card.expYear));
    params.append("payment_method_data[card][cvc]", payload.card.cvc);
    params.append("payment_method_options[card][request_three_d_secure]", "automatic");

    if (payload.description) {
      params.append("description", payload.description);
    }
    if (payload.orderId) {
      params.append("metadata[order_id]", payload.orderId);
    }

    console.log(`[create-payment-intent] Creating+confirming PI — amount: ${amountInt} ${currency}`);

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
      console.error("[create-payment-intent] Stripe error:", JSON.stringify(stripeData));
      return json({
        error: stripeData.error?.message ?? "Failed to create/confirm payment intent",
      }, stripeResponse.status);
    }

    console.log(`[create-payment-intent] ✅ PaymentIntent: ${stripeData.id} status=${stripeData.status}`);

    return json({
      clientSecret: stripeData.client_secret,
      paymentIntentId: stripeData.id,
      status: stripeData.status,
      amount: amountInt,
      currency,
    });
  } catch (err) {
    console.error("[create-payment-intent] Unexpected error:", err);
    return json({ error: String(err) }, 500);
  }
});
