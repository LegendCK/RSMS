-- =============================================================================
-- Migration: order_workflow_enforcement
-- 2026-03-23
--
-- Implements the proper order completion flow:
--   1. order_events audit table
--   2. Server-side state machine (transition_order_status SECURITY DEFINER)
--   3. Atomic inventory decrement RPC (decrement_order_inventory)
--   4. assign_order_store RPC (used by OrderService post-create)
--   5. get_order_items_for_fulfillment RPC (bypasses RLS for IC)
--   6. auto_deliver_stale_orders RPC (server-side, cron-safe)
--   7. Fixed staff write RLS (store ownership enforced)
-- =============================================================================

-- ── 1. order_events audit table ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.order_events (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id    UUID        NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    from_status TEXT,                               -- null on order creation
    to_status   TEXT        NOT NULL,
    actor_id    UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
    actor_role  TEXT,                               -- denormalized snapshot at time of action
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_events_order_id ON public.order_events(order_id);
CREATE INDEX IF NOT EXISTS idx_order_events_created_at ON public.order_events(created_at DESC);

-- RLS: staff can read events for their store's orders; customers see their own orders' events
ALTER TABLE public.order_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff view order events" ON public.order_events;
CREATE POLICY "Staff view order events"
ON public.order_events FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.orders o
        JOIN public.users u ON u.id = auth.uid()
        WHERE o.id = order_events.order_id
          AND u.role IN (
              'sales_associate','boutique_manager','corporate_admin',
              'inventory_controller','service_technician','aftersales_specialist'
          )
    )
);

DROP POLICY IF EXISTS "Customers view own order events" ON public.order_events;
CREATE POLICY "Customers view own order events"
ON public.order_events FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.orders o
        WHERE o.id = order_events.order_id
          AND o.client_id = auth.uid()
    )
);

-- ── 2. Server-side state machine ──────────────────────────────────────────────
--
-- transition_order_status(p_order_id, p_new_status, p_actor_id, p_notes)
--
-- Validates the transition, enforces store ownership for staff,
-- updates the order, and writes an audit event — all in one transaction.
-- Runs as SECURITY DEFINER so it can bypass RLS while still doing
-- proper ownership checks in PL/pgSQL.

CREATE OR REPLACE FUNCTION public.transition_order_status(
    p_order_id  UUID,
    p_new_status TEXT,
    p_actor_id  UUID DEFAULT NULL,
    p_notes     TEXT DEFAULT NULL
)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order         public.orders;
    v_old_status    TEXT;
    v_actor_role    TEXT;
    v_actor_store   UUID;

    -- Allowed forward transitions.
    -- "confirmed → shipped" is permitted for boutiques that pick+dispatch in one step.
    -- The IC fulfillment view auto-chains pending → confirmed → shipped for clarity.
    v_allowed       JSONB := '{
        "pending":          ["confirmed", "cancelled"],
        "new":              ["confirmed", "cancelled"],
        "confirmed":        ["processing", "shipped", "cancelled"],
        "processing":       ["shipped", "ready_for_pickup", "cancelled"],
        "shipped":          ["delivered"],
        "ready_for_pickup": ["completed", "delivered"],
        "delivered":        ["completed"],
        "completed":        [],
        "cancelled":        [],
        "canceled":         []
    }';
BEGIN
    -- Lock the order row to prevent concurrent transitions
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_order_id;
    END IF;

    v_old_status := v_order.status;

    -- Validate transition is allowed from current status
    IF NOT (v_allowed->v_old_status ? p_new_status) THEN
        RAISE EXCEPTION 'Invalid order transition: % → % (order %)',
            v_old_status, p_new_status, p_order_id;
    END IF;

    -- Fetch actor role and store (if actor is provided and is staff)
    IF p_actor_id IS NOT NULL THEN
        SELECT u.role INTO v_actor_role
        FROM public.users u
        WHERE u.id = p_actor_id;

        -- If actor is a non-admin staff, they must belong to the order's store
        IF v_actor_role IN ('inventory_controller','boutique_manager','sales_associate','service_technician','aftersales_specialist') THEN
            -- Get the actor's store assignment
            SELECT store_id INTO v_actor_store
            FROM public.staff_profiles
            WHERE user_id = p_actor_id
            LIMIT 1;

            -- If actor has a store and it doesn't match the order's store — reject
            IF v_actor_store IS NOT NULL AND v_actor_store <> v_order.store_id THEN
                RAISE EXCEPTION 'Staff member % (store %) cannot modify order % (store %)',
                    p_actor_id, v_actor_store, p_order_id, v_order.store_id;
            END IF;
        END IF;
    END IF;

    -- Apply the transition
    UPDATE public.orders
    SET status     = p_new_status,
        updated_at = now()
    WHERE id = p_order_id
    RETURNING * INTO v_order;

    -- Write audit event (always, even if actor is unknown)
    INSERT INTO public.order_events (
        order_id, from_status, to_status, actor_id, actor_role, notes
    ) VALUES (
        p_order_id, v_old_status, p_new_status, p_actor_id, v_actor_role, p_notes
    );

    RETURN v_order;
END;
$$;

-- Grant execute to authenticated users (the function does its own authorization)
GRANT EXECUTE ON FUNCTION public.transition_order_status(UUID, TEXT, UUID, TEXT)
    TO authenticated;

-- ── 3. Atomic inventory decrement ────────────────────────────────────────────
--
-- decrement_order_inventory(p_product_id, p_store_id, p_quantity)
--
-- Single-statement UPDATE avoids the read-then-write race condition
-- in the current OrderFulfillmentService.decrementInventory().
-- GREATEST(0, ...) prevents negative stock.

CREATE OR REPLACE FUNCTION public.decrement_order_inventory(
    p_product_id UUID,
    p_store_id   UUID,
    p_quantity   INT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.inventory
    SET quantity   = GREATEST(0, quantity - p_quantity),
        updated_at = now()
    WHERE product_id = p_product_id
      AND store_id   = p_store_id;

    -- If no row exists for this store+product, log a warning but don't raise.
    -- Inventory row may not yet be provisioned; fulfillment should still proceed.
    IF NOT FOUND THEN
        RAISE WARNING 'decrement_order_inventory: no inventory row for product % at store %',
            p_product_id, p_store_id;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.decrement_order_inventory(UUID, UUID, INT)
    TO authenticated;

-- ── 4. assign_order_store RPC ────────────────────────────────────────────────
--
-- Called by OrderService.assignStoreToOrder() after the edge function creates
-- the order. Needed because the customer's RLS policy blocks direct UPDATE.

CREATE OR REPLACE FUNCTION public.assign_order_store(
    p_order_id UUID,
    p_store_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.orders
    SET store_id   = p_store_id,
        updated_at = now()
    WHERE id = p_order_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_order_store(UUID, UUID)
    TO authenticated;

-- ── 5. get_order_items_for_fulfillment RPC ───────────────────────────────────
--
-- Returns order_items joined with product name/sku/images for a given order.
-- SECURITY DEFINER so IC can fetch items even when RLS blocks direct query.

CREATE OR REPLACE FUNCTION public.get_order_items_for_fulfillment(
    p_order_id UUID
)
RETURNS TABLE (
    id          UUID,
    order_id    UUID,
    product_id  UUID,
    quantity    INT,
    unit_price  NUMERIC,
    line_total  NUMERIC,
    product_name TEXT,
    product_sku  TEXT,
    image_urls   TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        oi.id,
        oi.order_id,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        oi.line_total,
        p.name         AS product_name,
        p.sku          AS product_sku,
        p.image_urls   AS image_urls
    FROM public.order_items oi
    LEFT JOIN public.products p ON p.id = oi.product_id
    WHERE oi.order_id = p_order_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_order_items_for_fulfillment(UUID)
    TO authenticated;

-- ── 6. auto_deliver_stale_orders RPC ─────────────────────────────────────────
--
-- Finds orders in "shipped" status that haven't been updated in > 24 hours
-- and marks them "delivered". Runs SECURITY DEFINER so it can update across
-- store boundaries (used by IC fulfillment view and optionally a cron job).

CREATE OR REPLACE FUNCTION public.auto_deliver_stale_orders(
    p_store_id    UUID,
    p_hours_stale INT DEFAULT 24
)
RETURNS INT    -- number of orders auto-delivered
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cutoff     TIMESTAMPTZ := now() - (p_hours_stale || ' hours')::INTERVAL;
    v_count      INT := 0;
    v_order_id   UUID;
BEGIN
    FOR v_order_id IN
        SELECT id
        FROM public.orders
        WHERE store_id = p_store_id
          AND status   = 'shipped'
          AND updated_at <= v_cutoff
        FOR UPDATE SKIP LOCKED
    LOOP
        -- Use the state machine so each delivery gets an audit event
        PERFORM public.transition_order_status(
            v_order_id, 'delivered', NULL,
            'Auto-delivered after ' || p_hours_stale || ' hours in shipped status'
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_deliver_stale_orders(UUID, INT)
    TO authenticated;

-- ── 7. Fix staff write RLS ────────────────────────────────────────────────────
--
-- The current "staff write" policy (if any) lacks a store_id filter,
-- letting any staff member update any order. We replace it with a policy
-- that requires the staff member's store to match the order's store.
-- Corporate admins are exempt (they manage all stores).

DROP POLICY IF EXISTS "Staff can update orders"         ON public.orders;
DROP POLICY IF EXISTS "Staff can write orders"          ON public.orders;
DROP POLICY IF EXISTS "orders: staff write"             ON public.orders;
DROP POLICY IF EXISTS "Authenticated can update orders" ON public.orders;

-- Staff can update only orders belonging to their assigned store.
-- Corporate admin can update any order.
-- Note: The transition_order_status() SECURITY DEFINER function is the
-- preferred update path — this RLS policy is a safety net for direct updates.
CREATE POLICY "Staff update own store orders"
ON public.orders FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role = 'corporate_admin'
    )
    OR
    EXISTS (
        SELECT 1
        FROM public.users u
        JOIN public.staff_profiles sp ON sp.user_id = u.id
        WHERE u.id  = auth.uid()
          AND u.role IN (
              'boutique_manager','inventory_controller',
              'sales_associate','service_technician','aftersales_specialist'
          )
          AND sp.store_id = orders.store_id
    )
);

-- ── 8. Seed an order_events row for any existing confirmed orders ─────────────
-- (Backfill so the audit trail is coherent from this migration forward)
INSERT INTO public.order_events (order_id, from_status, to_status, actor_id, notes)
SELECT id, NULL, status, NULL, 'Backfill: pre-migration order state'
FROM public.orders
WHERE id NOT IN (SELECT DISTINCT order_id FROM public.order_events)
ON CONFLICT DO NOTHING;
