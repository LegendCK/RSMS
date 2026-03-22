import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface CreateExchangeRequestPayload {
  orderNumber: string;
  productId?: string | null;
  itemName: string;
  quantity: number;
  reason: string;
  customerEmail?: string | null;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabaseUser.auth.getUser();
    if (userError || !user) {
      return json({ error: "Unauthorized: " + (userError?.message ?? "no user") }, 401);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const payload: CreateExchangeRequestPayload = await req.json();
    const orderNumber = (payload.orderNumber ?? "").trim();
    if (!orderNumber) return json({ error: "orderNumber is required" }, 400);

    const reason = (payload.reason ?? "").trim();
    if (!reason) return json({ error: "reason is required" }, 400);

    // Resolve client from auth user
    let clientId: string | null = null;
    const { data: clientById } = await admin
      .from("clients")
      .select("id, email")
      .eq("id", user.id)
      .maybeSingle();

    if (clientById) {
      clientId = clientById.id;
    } else {
      const email = (user.email ?? "").toLowerCase();
      if (!email) return json({ error: "Cannot resolve client from authenticated user" }, 400);
      const { data: clientByEmail } = await admin
        .from("clients")
        .select("id, email")
        .eq("email", email)
        .maybeSingle();
      if (!clientByEmail) return json({ error: "No client profile found for this user" }, 400);
      clientId = clientByEmail.id;
    }

    const { data: orderRows, error: orderError } = await admin
      .from("orders")
      .select("id, order_number, store_id, client_id")
      .eq("order_number", orderNumber)
      .limit(1);

    if (orderError || !orderRows || orderRows.length === 0) {
      return json({ error: "Order not found for exchange request" }, 404);
    }

    const order = orderRows[0] as { id: string; order_number: string; store_id: string; client_id?: string | null };
    if (!order.store_id) return json({ error: "Order has no store context" }, 400);
    if (order.client_id && clientId && order.client_id !== clientId) {
      return json({ error: "Order does not belong to authenticated customer" }, 403);
    }

    const now = new Date().toISOString();
    const notes = [
      "Customer Exchange Request",
      "Source: Customer Order Detail",
      `Order Number: ${order.order_number}`,
      payload.customerEmail ? `Customer Email: ${payload.customerEmail}` : null,
      `Item: ${payload.itemName}`,
      `Quantity: ${payload.quantity ?? 1}`,
      `Reason: ${reason}`,
      `Requested At: ${now}`
    ].filter(Boolean).join("\n");

    const insertPayload = {
      client_id: clientId,
      store_id: order.store_id,
      assigned_to: null,
      product_id: payload.productId ?? null,
      order_id: order.id,
      type: "warranty_claim",
      status: "intake",
      condition_notes: "Customer requested exchange from order detail.",
      estimated_cost: null,
      currency: "INR",
      notes,
    };

    const { data: ticket, error: ticketError } = await admin
      .from("service_tickets")
      .insert(insertPayload)
      .select()
      .single();

    if (ticketError || !ticket) {
      return json({ error: "Failed to create exchange request: " + (ticketError?.message ?? "unknown") }, 500);
    }

    return json({
      success: true,
      ticketId: ticket.id,
      ticketNumber: ticket.ticket_number ?? null,
      status: ticket.status,
    });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

