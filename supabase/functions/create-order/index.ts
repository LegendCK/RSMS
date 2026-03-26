// create-order/index.ts
// Edge Function — creates an order + order_items using the service role key.
// Runs server-side so RLS policies on `orders`/`order_items` are bypassed.
// The caller's JWT is still validated inside the function via auth.getUser().
//
// Store routing priority:
//   1. Client city  → store city  (case-insensitive, exact match)
//   2. Client state → store region (case-insensitive, exact match)
//   3. Fallback     → first active store

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface CartItemPayload {
  productId: string;
  productName: string;
  quantity: number;
  unitPrice: number;
}

interface PaymentSplitPayload {
  method: string;
  amount: number;
  paymentReference?: string | null;
  status?: string;
}

interface CreateOrderPayload {
  clientId?: string;
  orderNumber: string;
  cartItems: CartItemPayload[];
  subtotal: number;
  discountTotal?: number;
  taxTotal: number;
  grandTotal: number;
  channel: string;        // "online" | "bopis" | "in_store" | "ship_from_store"
  currency?: string;
  storeId?: string;
  isTaxFree?: boolean;
  taxFreeReason?: string;
  notes?: string;
  deliveryCity?: string;
  deliveryState?: string;
  paymentSplits?: PaymentSplitPayload[];
}

interface StoreRow {
  id: string;
  name: string;
  city: string | null;
  region: string | null;
}

interface InventoryRow {
  product_id: string;
  quantity: number;
}

interface ClientAddressRow {
  city: string | null;
  state: string | null;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function roundMoney(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

async function rollbackCreatedOrder(admin: ReturnType<typeof createClient>, orderId: string): Promise<void> {
  await admin.from("order_events").delete().eq("order_id", orderId);
  await admin.from("payments").delete().eq("order_id", orderId);
  await admin.from("order_items").delete().eq("order_id", orderId);
  await admin.from("orders").delete().eq("id", orderId);
}

async function createReplenishmentRequestsIfNeeded(
  admin: ReturnType<typeof createClient>,
  order: { id: string; order_number: string },
  storeId: string,
  cartItems: CartItemPayload[]
): Promise<number> {
  if (cartItems.length === 0) return 0;

  const requiredByProduct = new Map<string, number>();
  for (const item of cartItems) {
    const pid = item.productId.toLowerCase();
    requiredByProduct.set(pid, (requiredByProduct.get(pid) ?? 0) + Math.max(0, item.quantity));
  }
  const productIds = Array.from(requiredByProduct.keys());
  if (productIds.length === 0) return 0;

  const { data: invRows, error: invError } = await admin
    .from("inventory")
    .select("product_id, quantity")
    .eq("location_id", storeId)
    .in("product_id", productIds);

  if (invError) {
    console.warn("[create-order] Inventory check failed for replenishment:", invError.message);
    return 0;
  }

  const availableByProduct = new Map<string, number>();
  for (const row of (invRows as InventoryRow[]) ?? []) {
    availableByProduct.set(row.product_id.toLowerCase(), Number(row.quantity ?? 0));
  }

  const rows: Array<Record<string, unknown>> = [];
  for (const [productId, requiredQty] of requiredByProduct.entries()) {
    const availableQty = availableByProduct.get(productId) ?? 0;
    const shortage = Math.max(0, requiredQty - availableQty);
    if (shortage <= 0) continue;

    rows.push({
      transfer_number: `REP-${order.order_number}-${productId.slice(0, 4).toUpperCase()}`,
      product_id: productId,
      quantity: shortage,
      from_boutique_id: storeId,
      to_boutique_id: storeId,
      status: "pending_admin_approval",
      requested_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      notes: `Auto-created for order ${order.order_number}`,
    });
  }

  if (rows.length === 0) return 0;

  const { error: transferError } = await admin
    .from("transfers")
    .upsert(rows, { onConflict: "transfer_number" });

  if (transferError) {
    console.warn("[create-order] Replenishment upsert failed:", transferError.message);
    return 0;
  }

  console.log(`[create-order] Replenishment requests created: ${rows.length}`);
  return rows.length;
}

// ── Smart Store Resolution ──────────────────────────────────────────────────
async function resolveStore(
  admin: ReturnType<typeof createClient>,
  clientId: string,
  deliveryCityHint?: string,
  deliveryStateHint?: string
): Promise<StoreRow> {
  const { data: allStores, error: storesError } = await admin
    .from("stores")
    .select("id, name, city, region")
    .eq("is_active", true)
    .order("created_at", { ascending: true });

  if (storesError || !allStores || allStores.length === 0) {
    throw new Error("No active stores found");
  }

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

  if (clientCity) {
    const cityMatch = (allStores as StoreRow[]).find(
      (s) => (s.city ?? "").trim().toLowerCase() === clientCity
    );
    if (cityMatch) return cityMatch;
  }

  if (clientState) {
    const regionMatch = (allStores as StoreRow[]).find(
      (s) => (s.region ?? "").trim().toLowerCase() === clientState
    );
    if (regionMatch) return regionMatch;
  }

  return (allStores as StoreRow[])[0];
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Validate JWT (function-level) ───────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401);
    }

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

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ── 3. Resolve client_id ───────────────────────────────────────────────────
    const payload: CreateOrderPayload = await req.json();
    const isPOS = payload.channel === "in_store";
    const isSADeliveryOrder = payload.channel === "ship_from_store";

    let clientId: string | null = null;

    if (payload.clientId) {
      clientId = payload.clientId;
      console.log(`[create-order] Client from payload (POS sale): ${clientId}`);
    } else if (!isPOS) {
      clientId = user.id;

      const { data: clientById } = await admin
        .from("clients")
        .select("id")
        .eq("id", user.id)
        .maybeSingle();

      if (!clientById) {
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

    // Only include splits that have a valid method and positive amount
    const normalizedPaymentSplits: PaymentSplitPayload[] = (payload.paymentSplits ?? [])
      .map((split) => ({
        method: split.method?.trim().toLowerCase() ?? "",
        amount: roundMoney(Number(split.amount ?? 0)),
        paymentReference: split.paymentReference?.trim() || null,
        status: split.status?.trim().toLowerCase() || "completed",
      }))
      .filter((split) => split.method.length > 0 && split.amount > 0);

    // Validate split totals with float tolerance (INR amounts can be large)
    if (normalizedPaymentSplits.length > 0) {
      const paidTotal = roundMoney(normalizedPaymentSplits.reduce((sum, split) => sum + split.amount, 0));
      const orderTotal = roundMoney(payload.grandTotal);
      if (Math.abs(paidTotal - orderTotal) > 0.01) {
        return json({
          error: `Split payments total (${paidTotal.toFixed(2)}) must equal order grand total (${orderTotal.toFixed(2)}).`,
        }, 400);
      }
    }

    // ── 5. Resolve store ───────────────────────────────────────────────────────
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
      } else if (clientId) {
        try {
          store = await resolveStore(admin, clientId, payload.deliveryCity, payload.deliveryState);
        } catch (e) { return json({ error: String(e) }, 400); }
      } else {
        const { data: fb } = await admin.from("stores").select("id, name, city, region").eq("is_active", true).order("created_at", { ascending: true });
        if (!fb || fb.length === 0) return json({ error: "No active stores found" }, 400);
        store = (fb as StoreRow[])[0];
      }
    } else if (clientId) {
      try {
        store = await resolveStore(admin, clientId, payload.deliveryCity, payload.deliveryState);
      } catch (e) { return json({ error: String(e) }, 400); }
    } else {
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

    console.log(`[create-order] Order created: ${order.order_number} (${order.id}) → store: ${store.name}`);

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

    // ── 8. Insert order_items ──────────────────────────────────────────────────
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
        await rollbackCreatedOrder(admin, order.id);
        console.error("[create-order] order_items insert failed, rolled back order:", itemsError.message);
        return json({ error: "Failed to create order items: " + itemsError.message }, 500);
      }
      itemsInserted = items.length;
      console.log(`[create-order] ${itemsInserted} order item(s) inserted`);
    }

    // ── 9. Insert payments (non-fatal — order is already committed) ───────────
    let paymentsInserted = 0;
    if (normalizedPaymentSplits.length > 0) {
      const paymentRows = normalizedPaymentSplits.map((split) => ({
        order_id: order.id,
        method: split.method,
        amount: split.amount,
        currency,
        status: split.status ?? "completed",
        payment_reference: split.paymentReference ?? null,
        processed_by: (isPOS || isSADeliveryOrder) ? user.id : null,
      }));

      const { error: paymentError } = await admin
        .from("payments")
        .insert(paymentRows);

      if (paymentError) {
        // Non-fatal: order header + items already committed; log and continue.
        console.warn("[create-order] payments insert failed (non-fatal):", paymentError.message);
      } else {
        paymentsInserted = paymentRows.length;
        console.log(`[create-order] ${paymentsInserted} payment row(s) inserted`);
      }
    }

    // ── 9b. Replenishment requests (SA delivery orders only) ──────────────────
    let replenishmentsRequested = 0;
    if (isSADeliveryOrder) {
      replenishmentsRequested = await createReplenishmentRequestsIfNeeded(
        admin,
        { id: order.id, order_number: order.order_number },
        store.id,
        payload.cartItems ?? []
      );
    }

    // ── 10. Return success ─────────────────────────────────────────────────────
    return json({
      success: true,
      orderId: order.id,
      orderNumber: order.order_number,
      storeId: store.id,
      storeName: store.name,
      itemsInserted,
      paymentsInserted,
      replenishmentsRequested,
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
