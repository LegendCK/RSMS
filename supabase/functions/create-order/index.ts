// create-order/index.ts
// Edge Function — creates an order + order_items using the service role key.
// Runs server-side so RLS policies on `orders`/`order_items` are bypassed.
// The caller's JWT is still validated, ensuring only authenticated users can place orders.
//
// Store routing priority:
//   1. Client city  → store city  (case-insensitive, exact match)
//   2. Client state → store region (case-insensitive, exact match)
//   3. Fallback     → first active store (original behaviour)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface CartItemPayload {
  productId: string;
  productName: string;
  quantity: number;
  unitPrice: number;
}

interface CreateOrderPayload {
  orderNumber: string;
  cartItems: CartItemPayload[];
  subtotal: number;
  discountTotal?: number;
  taxTotal: number;
  grandTotal: number;
  channel: string;   // "online" | "bopis" | "in_store" | "ship_from_store"
  currency?: string; // defaults to "USD"
}

interface StoreRow {
  id: string;
  name: string;
  city: string | null;
  region: string | null;
}

interface ClientAddressRow {
  city: string | null;
  state: string | null;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── Smart Store Resolution ──────────────────────────────────────────────────
// Tries city match → state/region match → fallback (first active store).
async function resolveStore(
  admin: ReturnType<typeof createClient>,
  clientId: string
): Promise<StoreRow> {
  // Fetch all active stores once (ordered deterministically)
  const { data: allStores, error: storesError } = await admin
    .from("stores")
    .select("id, name, city, region")
    .eq("is_active", true)
    .order("created_at", { ascending: true });

  if (storesError || !allStores || allStores.length === 0) {
    throw new Error("No active stores found");
  }

  // Fetch the client's city + state for location matching
  const { data: clientAddr } = await admin
    .from("clients")
    .select("city, state")
    .eq("id", clientId)
    .maybeSingle() as { data: ClientAddressRow | null };

  const clientCity  = clientAddr?.city?.trim().toLowerCase()  ?? "";
  const clientState = clientAddr?.state?.trim().toLowerCase() ?? "";

  console.log(`[create-order] Client location — city: "${clientCity}", state: "${clientState}"`);

  // Tier 1: exact city match (e.g. "Mumbai" → Mumbai store)
  if (clientCity) {
    const cityMatch = (allStores as StoreRow[]).find(
      (s) => (s.city ?? "").trim().toLowerCase() === clientCity
    );
    if (cityMatch) {
      console.log(`[create-order] ✅ Store resolved by CITY: ${cityMatch.name} (${cityMatch.id})`);
      return cityMatch;
    }
  }

  // Tier 2: state → region match (e.g. "Maharashtra" → stores with region="Maharashtra")
  if (clientState) {
    const regionMatch = (allStores as StoreRow[]).find(
      (s) => (s.region ?? "").trim().toLowerCase() === clientState
    );
    if (regionMatch) {
      console.log(`[create-order] ✅ Store resolved by STATE/REGION: ${regionMatch.name} (${regionMatch.id})`);
      return regionMatch;
    }
  }

  // Tier 3: fallback — first active store (preserves original behaviour)
  const fallback = (allStores as StoreRow[])[0];
  console.log(`[create-order] ⚠️ Store resolved by FALLBACK (no location match): ${fallback.name} (${fallback.id})`);
  return fallback;
}

serve(async (req: Request) => {
  // CORS pre-flight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Validate JWT ────────────────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401);
    }

    // User-scoped client — used only to validate the token
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabaseUser.auth.getUser();
    if (userError || !user) {
      return json({ error: "Unauthorized: " + (userError?.message ?? "no user") }, 401);
    }

    // ── 2. Admin client — bypasses RLS ─────────────────────────────────────────
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ── 3. Resolve client_id ───────────────────────────────────────────────────
    // Pass 1: clients.id == auth.uid (self-registered customers)
    let clientId: string = user.id;

    const { data: clientById } = await admin
      .from("clients")
      .select("id")
      .eq("id", user.id)
      .maybeSingle();

    if (!clientById) {
      // Pass 2: match by email (client pre-created by sales associate)
      const email = user.email?.toLowerCase() ?? "";
      if (!email) {
        return json({ error: "Cannot resolve client: no matching clients row" }, 400);
      }
      const { data: clientByEmail } = await admin
        .from("clients")
        .select("id")
        .eq("email", email)
        .maybeSingle();

      if (clientByEmail) {
        clientId = clientByEmail.id;
        console.log(`[create-order] Resolved client by email: ${clientId}`);
      } else {
        return json({ error: "No client profile found for this user" }, 400);
      }
    } else {
      console.log(`[create-order] Resolved client by id: ${clientId}`);
    }

    // ── 4. Resolve store (city → state/region → fallback) ─────────────────────
    let store: StoreRow;
    try {
      store = await resolveStore(admin, clientId);
    } catch (e) {
      return json({ error: String(e) }, 400);
    }

    // ── 5. Parse payload ───────────────────────────────────────────────────────
    const payload: CreateOrderPayload = await req.json();
    const currency = payload.currency ?? "USD";
    const discountTotal = payload.discountTotal ?? 0;

    // ── 6. Insert order header ─────────────────────────────────────────────────
    const { data: order, error: orderError } = await admin
      .from("orders")
      .insert({
        order_number: payload.orderNumber,
        client_id: clientId,
        store_id: store.id,
        associate_id: null,
        channel: payload.channel,
        status: "confirmed",
        subtotal: payload.subtotal,
        discount_total: discountTotal,
        tax_total: payload.taxTotal,
        grand_total: payload.grandTotal,
        currency: currency,
        is_tax_free: false,
        notes: null,
      })
      .select()
      .single();

    if (orderError || !order) {
      console.error("[create-order] orders insert failed:", orderError);
      return json({ error: "Failed to create order: " + orderError?.message }, 500);
    }

    console.log(`[create-order] Order created: ${order.order_number} (${order.id}) → store: ${store.name}`);

    // ── 7. Insert order_items (best-effort) ────────────────────────────────────
    let itemsInserted = 0;
    if (payload.cartItems && payload.cartItems.length > 0) {
      const taxRate = payload.subtotal > 0 ? payload.taxTotal / payload.subtotal : 0.08;

      const items = payload.cartItems.map((item) => {
        const lineTotal = item.unitPrice * item.quantity;
        return {
          order_id: order.id,
          product_id: item.productId,
          quantity: item.quantity,
          unit_price: item.unitPrice,
          tax_amount: lineTotal * taxRate,
          line_total: lineTotal,
        };
      });

      const { error: itemsError } = await admin
        .from("order_items")
        .insert(items);

      if (itemsError) {
        // Non-fatal: order header already committed, associate can still see totals
        console.warn("[create-order] order_items insert failed (non-fatal):", itemsError.message);
      } else {
        itemsInserted = items.length;
        console.log(`[create-order] ${itemsInserted} order item(s) inserted`);
      }
    }

    // ── 8. Return success ──────────────────────────────────────────────────────
    return json({
      success: true,
      orderId: order.id,
      orderNumber: order.order_number,
      storeId: store.id,
      storeName: store.name,
      itemsInserted,
    });

  } catch (err) {
    console.error("[create-order] Unexpected error:", err);
    return json({ error: String(err) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
