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
  clientId?: string;      // explicit client UUID for POS/in-store sales (SA selects client)
  orderNumber: string;
  cartItems: CartItemPayload[];
  subtotal: number;
  discountTotal?: number;
  taxTotal: number;
  grandTotal: number;
  channel: string;        // "online" | "bopis" | "in_store" | "ship_from_store"
  currency?: string;      // defaults to "INR"
  storeId?: string;       // client-resolved store UUID — used directly when present, geo-routing only as fallback
  isTaxFree?: boolean;    // true for international visitors / tax-exempt purchases
  taxFreeReason?: string; // eligibility note captured by the sales associate
  notes?: string;         // free-form checkout notes from POS
  deliveryCity?: string;  // delivery-address city hint from app checkout
  deliveryState?: string; // delivery-address state hint from app checkout
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
  clientId: string,
  deliveryCityHint?: string,
  deliveryStateHint?: string
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

  // Prefer explicit delivery-address hints (from checkout form), then fall back
  // to client profile city/state if hints are absent.
  const hintedCity = deliveryCityHint?.trim().toLowerCase() ?? "";
  const hintedState = deliveryStateHint?.trim().toLowerCase() ?? "";

  let clientCity = hintedCity;
  let clientState = hintedState;

  if (!clientCity && !clientState) {
    const { data: clientAddr } = await admin
      .from("clients")
      .select("city, state")
      .eq("id", clientId)
      .maybeSingle() as { data: ClientAddressRow | null };

    clientCity  = clientAddr?.city?.trim().toLowerCase()  ?? "";
    clientState = clientAddr?.state?.trim().toLowerCase() ?? "";
  }

  console.log(`[create-order] Routing location — city: "${clientCity}", state: "${clientState}"`);

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

    // ── 2. Verify identity via user-scoped client (recommended pattern) ─────────
    // Using a user-context client with auth.getUser() is more reliable than
    // admin.auth.getUser(jwt) across Supabase SDK versions — it calls the simpler
    // GET /auth/v1/user endpoint rather than the admin JWT-decode path.
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      console.error("[create-order] Auth verification failed:", userError?.message);
      return json({ error: "Unauthorized: " + (userError?.message ?? "no user") }, 401);
    }

    // ── 2b. Admin client — bypasses RLS for privileged DB operations ───────────
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ── 3. Resolve client_id ───────────────────────────────────────────────────
    // For POS/in-store sales the caller is a sales associate, not the client.
    // For online sales the JWT owner IS the client — resolve by auth.uid or email.
    const payload: CreateOrderPayload = await req.json();
    const isPOS = payload.channel === "in_store";
    // SA can place orders for delivery (ship_from_store) when item is not in stock
    const isSADeliveryOrder = payload.channel === "ship_from_store";

    let clientId: string | null = null;

    if (payload.clientId) {
      // POS sale with known client — SA explicitly provided the UUID
      clientId = payload.clientId;
      console.log(`[create-order] Client from payload (POS sale): ${clientId}`);
    } else if (!isPOS) {
      // Online sale — resolve client from JWT (caller IS the client)
      clientId = user.id;

      const { data: clientById } = await admin
        .from("clients")
        .select("id")
        .eq("id", user.id)
        .maybeSingle();

      if (!clientById) {
        // Fallback: match by email (client pre-created by sales associate)
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
    } else {
      // Walk-in POS sale — no client profile; client_id will be null
      console.log(`[create-order] Walk-in POS sale — no client linked`);
    }

    // ── 4. Destructure payload ─────────────────────────────────────────────────
    const currency = payload.currency ?? "INR";
    const discountTotal = payload.discountTotal ?? 0;
    const baseNotes = payload.notes?.trim() ?? "";
    const taxNote = payload.taxFreeReason?.trim()
      ? `TAX-FREE: ${payload.taxFreeReason.trim()}`
      : "";
    const combinedNotes = [baseNotes, taxNote].filter((x) => x.length > 0).join(" | ") || null;

    // ── 5. Resolve store ───────────────────────────────────────────────────────
    // Priority:
    //   1. Client-provided storeId (iOS already ran StoreAssignmentService on the shipping address)
    //   2. Server geo-routing: clients.city → region → fallback
    let store: StoreRow;
    if (payload.storeId) {
      const { data: storeById } = await admin
        .from("stores")
        .select("id, name, city, region")
        .eq("id", payload.storeId)
        .eq("is_active", true)
        .maybeSingle();

      if (storeById) {
        store = storeById as StoreRow;
        console.log(`[create-order] ✅ Store from client hint: ${store.name} (${store.id})`);
      } else {
        console.warn(`[create-order] ⚠️ Client storeId ${payload.storeId} not found — falling back to geo-routing`);
        if (clientId) {
          try {
            store = await resolveStore(admin, clientId, payload.deliveryCity, payload.deliveryState);
          } catch (e) { return json({ error: String(e) }, 400); }
        } else {
          const { data: fb } = await admin.from("stores").select("id, name, city, region").eq("is_active", true).order("created_at", { ascending: true });
          if (!fb || fb.length === 0) return json({ error: "No active stores found" }, 400);
          store = (fb as StoreRow[])[0];
        }
      }
    } else if (clientId) {
      try {
        store = await resolveStore(admin, clientId, payload.deliveryCity, payload.deliveryState);
      } catch (e) { return json({ error: String(e) }, 400); }
    } else {
      // Walk-in with no storeId hint — fallback to first active store
      const { data: allStores } = await admin
        .from("stores").select("id, name, city, region").eq("is_active", true).order("created_at", { ascending: true });
      if (!allStores || allStores.length === 0) return json({ error: "No active stores found" }, 400);
      store = (allStores as StoreRow[])[0];
      console.log(`[create-order] Walk-in fallback store: ${store.name}`);
    }

    // ── 6. Insert order header ─────────────────────────────────────────────────
    const { data: order, error: orderError } = await admin
      .from("orders")
      .insert({
        order_number: payload.orderNumber,
        client_id: clientId,
        store_id: store.id,
        associate_id: (isPOS || isSADeliveryOrder) ? user.id : null,
        channel: payload.channel,
        status: isPOS ? "completed" : "pending",
        subtotal: payload.subtotal,
        discount_total: discountTotal,
        tax_total: payload.taxTotal,
        grand_total: payload.grandTotal,
        currency: currency,
        is_tax_free: payload.isTaxFree ?? false,
        notes: combinedNotes,
      })
      .select()
      .single();

    if (orderError || !order) {
      console.error("[create-order] orders insert failed:", orderError);
      return json({ error: "Failed to create order: " + orderError?.message }, 500);
    }

    console.log(`[create-order] Order created: ${order.order_number} (${order.id}) → store: ${store.name} [pending]`);

    // ── 7. Write initial audit event ──────────────────────────────────────────
    const auditNote = isPOS
      ? `In-store POS sale completed${payload.isTaxFree ? " (tax-free)" : ""}`
      : isSADeliveryOrder
        ? `Order placed by sales associate for delivery${payload.isTaxFree ? " (tax-free)" : ""}`
        : `Order placed via ${payload.channel}`;

    await admin.from("order_events").insert({
      order_id:    order.id,
      from_status: null,
      to_status:   isPOS ? "completed" : "pending",
      actor_id:    user.id,
      actor_role:  (isPOS || isSADeliveryOrder) ? "sales_associate" : "customer",
      notes:       auditNote,
    });

    // ── 8. Insert order_items (best-effort) ────────────────────────────────────
    let itemsInserted = 0;
    if (payload.cartItems && payload.cartItems.length > 0) {
      const taxRate = (payload.isTaxFree || payload.subtotal === 0)
        ? 0
        : payload.taxTotal / payload.subtotal;

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
        // Keep order header + items atomic for downstream sync reliability.
        await admin
          .from("orders")
          .delete()
          .eq("id", order.id);
        console.error("[create-order] order_items insert failed, rolled back order:", itemsError.message);
        return json({ error: "Failed to create order items: " + itemsError.message }, 500);
      } else {
        itemsInserted = items.length;
        console.log(`[create-order] ${itemsInserted} order item(s) inserted`);
      }
    }

    // ── 9. Return success ──────────────────────────────────────────────────────
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
