-- =============================================================================
-- Migration: service_tickets_submit_exchange_rpc
-- Creates a SECURITY DEFINER function so customers can submit exchange
-- requests without needing direct INSERT on service_tickets (which is
-- blocked by RLS for non-staff roles).
--
-- Run in: Supabase Dashboard → SQL Editor → New Query
-- =============================================================================

-- Drop old function if it exists (idempotent)
DROP FUNCTION IF EXISTS public.submit_customer_exchange_request(
  text, uuid, text, int, text, text, uuid
);

-- Creates the RPC
CREATE OR REPLACE FUNCTION public.submit_customer_exchange_request(
  p_order_number    text,
  p_product_id      uuid       DEFAULT NULL,
  p_item_name       text       DEFAULT '',
  p_quantity        int        DEFAULT 1,
  p_reason          text       DEFAULT '',
  p_customer_email  text       DEFAULT NULL,
  p_store_id        uuid       DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id   uuid;
  v_order_id   uuid;
  v_client_id  uuid;
  v_ticket_id  uuid;
  v_ticket_num text;
  v_notes      text;
BEGIN
  -- 1. Must be authenticated
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('error', 'Unauthorized');
  END IF;

  -- 2. Resolve store_id: use provided value, else look up from orders, else first active store
  IF p_store_id IS NOT NULL THEN
    v_store_id := p_store_id;
  ELSE
    SELECT o.store_id, o.id, o.client_id
    INTO v_store_id, v_order_id, v_client_id
    FROM orders o
    WHERE o.order_number = p_order_number
    ORDER BY o.created_at DESC
    LIMIT 1;
  END IF;

  -- Fallback: first active store
  IF v_store_id IS NULL THEN
    SELECT id INTO v_store_id FROM stores WHERE is_active = true ORDER BY created_at ASC LIMIT 1;
  END IF;

  IF v_store_id IS NULL THEN
    RETURN jsonb_build_object('error', 'No active store found. Please contact support.');
  END IF;

  -- 3. Resolve order_id and client_id if not yet fetched
  IF v_order_id IS NULL THEN
    SELECT o.store_id, o.id, o.client_id
    INTO v_store_id, v_order_id, v_client_id
    FROM orders o
    WHERE o.order_number = p_order_number
    ORDER BY o.created_at DESC
    LIMIT 1;
  END IF;

  -- 4. Build notes
  v_notes := 'Customer Exchange Request' || chr(10)
    || 'Order: ' || p_order_number || chr(10)
    || 'Item: ' || p_item_name || ' • Qty ' || p_quantity;
  IF p_customer_email IS NOT NULL AND p_customer_email <> '' THEN
    v_notes := v_notes || chr(10) || 'Customer: ' || p_customer_email;
  END IF;
  IF trim(p_reason) <> '' THEN
    v_notes := v_notes || chr(10) || 'Reason: ' || trim(p_reason);
  END IF;

  -- 5. Insert the ticket (SECURITY DEFINER bypasses RLS)
  INSERT INTO service_tickets (
    client_id,
    store_id,
    assigned_to,
    product_id,
    order_id,
    type,
    status,
    condition_notes,
    currency,
    notes
  ) VALUES (
    v_client_id,
    v_store_id,
    NULL,
    p_product_id,
    v_order_id,
    'warranty_claim',
    'intake',
    'Customer exchange request – ' || p_item_name || ' (Qty ' || p_quantity || ')',
    'INR',
    v_notes
  )
  RETURNING id, ticket_number INTO v_ticket_id, v_ticket_num;

  -- 6. Return ticket info
  RETURN jsonb_build_object(
    'success',       true,
    'ticket_id',     v_ticket_id::text,
    'ticket_number', COALESCE(v_ticket_num, 'TKT-' || upper(left(v_ticket_id::text, 8)))
  );
END;
$$;

-- Allow all authenticated users to call this function
GRANT EXECUTE ON FUNCTION public.submit_customer_exchange_request(
  text, uuid, text, int, text, text, uuid
) TO authenticated;
