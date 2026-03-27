-- =============================================================================
-- Migration: omnichannel_system (FINAL PRODUCTION BUILD)
-- 2026-03-26
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. SCHEMA CHANGES
-- ═══════════════════════════════════════════════════════════════════════════════

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'inventory' AND column_name = 'available_qty'
    ) THEN
        ALTER TABLE public.inventory
            ADD COLUMN available_qty int GENERATED ALWAYS AS (quantity - reserved_quantity) STORED;
    END IF;
END $$;

ALTER TABLE public.inventory DROP CONSTRAINT IF EXISTS inventory_reserved_lte_quantity;
ALTER TABLE public.inventory ADD CONSTRAINT inventory_reserved_lte_quantity CHECK (reserved_quantity <= quantity);

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'fulfillment_type'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN fulfillment_type text NOT NULL DEFAULT 'in_store';
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'fulfillment_location_id'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN fulfillment_location_id uuid REFERENCES public.stores(id);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'refund_total'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN refund_total numeric(12,2) NOT NULL DEFAULT 0;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'idempotency_key'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN idempotency_key text;
        CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_idempotency
            ON public.orders(idempotency_key) WHERE idempotency_key IS NOT NULL;
    END IF;
END $$;

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check CHECK (status IN (
    'pending','new','confirmed','processing',
    'ready_for_pickup','shipped','delivered',
    'completed','cancelled','canceled',
    'returned','partially_returned'
));

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'order_events' AND column_name = 'event_type'
    ) THEN
        ALTER TABLE public.order_events ADD COLUMN event_type text;
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. RETURNS + RETURN_ITEMS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.returns (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    store_id        uuid NOT NULL REFERENCES public.stores(id),
    type            text NOT NULL CHECK (type IN ('return','exchange')),
    status          text NOT NULL DEFAULT 'completed'
                        CHECK (status IN ('pending','approved','completed','rejected')),
    refund_amount   numeric(12,2) NOT NULL DEFAULT 0,
    processed_by    uuid REFERENCES auth.users(id),
    idempotency_key text,
    notes           text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_returns_idempotency
    ON public.returns(idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_returns_order ON public.returns(order_id);

CREATE TABLE IF NOT EXISTS public.return_items (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    return_id            uuid NOT NULL REFERENCES public.returns(id) ON DELETE CASCADE,
    order_item_id        uuid NOT NULL REFERENCES public.order_items(id),
    product_id           uuid NOT NULL REFERENCES public.products(id),
    quantity             int  NOT NULL CHECK (quantity > 0),
    reason               text NOT NULL DEFAULT 'customer_request',
    exchange_product_id  uuid REFERENCES public.products(id),
    exchange_location_id uuid REFERENCES public.stores(id),
    created_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_return_items_return    ON public.return_items(return_id);
CREATE INDEX IF NOT EXISTS idx_return_items_order_item ON public.return_items(order_item_id);

ALTER TABLE public.returns      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.return_items ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "returns_select"      ON public.returns      FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
    CREATE POLICY "return_items_select" ON public.return_items FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
    CREATE POLICY "returns_insert"      ON public.returns      FOR INSERT TO authenticated WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
    CREATE POLICY "return_items_insert" ON public.return_items FOR INSERT TO authenticated WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
    CREATE POLICY "returns_update"      ON public.returns      FOR UPDATE TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. RPC: place_omnichannel_order
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.place_omnichannel_order(
    p_client_id               uuid,
    p_store_id                uuid,
    p_associate_id            uuid    DEFAULT NULL,
    p_channel                 text    DEFAULT 'in_store',
    p_fulfillment_type        text    DEFAULT 'in_store',
    p_fulfillment_location_id uuid    DEFAULT NULL,
    p_items                   jsonb   DEFAULT '[]',
    p_subtotal                numeric DEFAULT 0,
    p_tax_total               numeric DEFAULT 0,
    p_discount_total          numeric DEFAULT 0,
    p_grand_total             numeric DEFAULT 0,
    p_currency                text    DEFAULT 'INR',
    p_is_tax_free             boolean DEFAULT false,
    p_notes                   text    DEFAULT NULL,
    p_order_number            text    DEFAULT NULL,
    p_idempotency_key         text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_fulfill_loc    uuid;
    v_order_id       uuid;
    v_inv            inventory%ROWTYPE;
    v_items_inserted int := 0;
    v_existing_id    uuid;
    v_order_num      text;
    v_record         record;
BEGIN
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_existing_id FROM orders WHERE idempotency_key = p_idempotency_key;
        IF FOUND THEN
            RETURN jsonb_build_object('success', true, 'order_id', v_existing_id, 'idempotent', true);
        END IF;
    END IF;

    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION USING MESSAGE = 'INVALID_INPUT';
    END IF;

    IF p_fulfillment_type NOT IN ('in_store','bopis','ship_from_store','endless_aisle') THEN
        RAISE EXCEPTION USING MESSAGE = 'INVALID_INPUT';
    END IF;

    v_fulfill_loc := COALESCE(p_fulfillment_location_id, p_store_id);

    -- Aggregate items
    CREATE TEMP TABLE tmp_req_items ON COMMIT DROP AS
    SELECT (value->>'product_id')::uuid AS product_id,
           SUM((value->>'quantity')::int)::int AS qty,
           MAX((value->>'unit_price')::numeric) AS unit_price
    FROM jsonb_array_elements(p_items)
    GROUP BY 1;

    IF EXISTS (SELECT 1 FROM tmp_req_items WHERE qty <= 0) THEN
        RAISE EXCEPTION USING MESSAGE = 'INVALID_INPUT';
    END IF;

    -- Lock ALL rows at once
    PERFORM 1
    FROM inventory i
    JOIN tmp_req_items r ON i.product_id = r.product_id
    WHERE i.location_id = v_fulfill_loc
    ORDER BY i.product_id
    FOR UPDATE;

    -- Validate + reserve
    FOR v_record IN SELECT * FROM tmp_req_items ORDER BY product_id
    LOOP
        SELECT * INTO v_inv
        FROM inventory
        WHERE product_id = v_record.product_id AND location_id = v_fulfill_loc
        FOR UPDATE;

        IF NOT FOUND OR (v_inv.quantity - v_inv.reserved_quantity) < v_record.qty THEN
            RAISE EXCEPTION USING MESSAGE = 'INSUFFICIENT_STOCK';
        END IF;

        UPDATE inventory
        SET reserved_quantity = reserved_quantity + v_record.qty,
            updated_at = now()
        WHERE product_id = v_record.product_id AND location_id = v_fulfill_loc;
    END LOOP;

    v_order_num := COALESCE(p_order_number, 'OMN-' || to_char(now(), 'YYYYMMDD') || '-' || substr(gen_random_uuid()::text, 1, 4));

    INSERT INTO orders (
        order_number, client_id, store_id, associate_id,
        channel, status, subtotal, tax_total, grand_total,
        currency, is_tax_free, notes,
        fulfillment_type, fulfillment_location_id, idempotency_key
    ) VALUES (
        v_order_num, p_client_id, p_store_id, p_associate_id,
        p_channel, 'confirmed', p_subtotal, p_tax_total, p_grand_total,
        p_currency, p_is_tax_free, p_notes,
        p_fulfillment_type, v_fulfill_loc, p_idempotency_key
    )
    RETURNING id INTO v_order_id;

    FOR v_record IN SELECT * FROM tmp_req_items
    LOOP
        INSERT INTO order_items (order_id, product_id, quantity, unit_price, tax_amount, line_total)
        VALUES (v_order_id, v_record.product_id, v_record.qty, v_record.unit_price, 0, v_record.unit_price * v_record.qty);
        v_items_inserted := v_items_inserted + 1;
    END LOOP;

    INSERT INTO order_events (order_id, event_type, to_status, actor_id, notes)
    VALUES (v_order_id, 'order_created', 'confirmed', p_associate_id, 'Order created');
    
    INSERT INTO order_events (order_id, event_type, to_status, actor_id, notes)
    VALUES (v_order_id, 'inventory_reserved', 'confirmed', p_associate_id, 'Inventory reserved at ' || v_fulfill_loc);

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_number', v_order_num,
        'items_inserted', v_items_inserted,
        'fulfillment_location_id', v_fulfill_loc
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.place_omnichannel_order(uuid, uuid, uuid, text, text, uuid, jsonb, numeric, numeric, numeric, numeric, text, boolean, text, text, text) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. RPC: fulfill_order_item
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fulfill_order_item(
    p_product_id   uuid,
    p_location_id  uuid,
    p_quantity     int,
    p_order_id     uuid DEFAULT NULL,
    p_actor_id     uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inv inventory%ROWTYPE;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION USING MESSAGE = 'INVALID_FULFILLMENT';
    END IF;

    SELECT * INTO v_inv
    FROM inventory
    WHERE product_id = p_product_id AND location_id = p_location_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING MESSAGE = 'INVALID_FULFILLMENT';
    END IF;

    IF v_inv.reserved_quantity < p_quantity THEN
        RAISE EXCEPTION USING MESSAGE = 'INVALID_FULFILLMENT';
    END IF;

    IF v_inv.quantity < p_quantity THEN
        RAISE EXCEPTION USING MESSAGE = 'INSUFFICIENT_STOCK';
    END IF;

    UPDATE inventory
    SET quantity          = quantity - p_quantity,
        reserved_quantity = reserved_quantity - p_quantity,
        updated_at        = now()
    WHERE product_id = p_product_id AND location_id = p_location_id;

    IF p_order_id IS NOT NULL THEN
        INSERT INTO order_events (order_id, event_type, actor_id, notes)
        VALUES (p_order_id, 'fulfilled', p_actor_id, p_product_id || ' x' || p_quantity);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'new_quantity', v_inv.quantity - p_quantity,
        'new_reserved', v_inv.reserved_quantity - p_quantity
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fulfill_order_item(uuid, uuid, int, uuid, uuid) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. RPC: process_return
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.process_return(
    p_order_id        uuid,
    p_store_id        uuid,
    p_type            text,
    p_items           jsonb,
    p_refund_amount   numeric DEFAULT 0,
    p_processed_by    uuid    DEFAULT NULL,
    p_notes           text    DEFAULT NULL,
    p_idempotency_key text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order            orders%ROWTYPE;
    v_return_id        uuid;
    v_purchased_qty    int;
    v_already_returned int;
    v_inv              inventory%ROWTYPE;
    v_oi               order_items%ROWTYPE;
    v_existing_id      uuid;
    v_all_returned     boolean;
    v_new_status       text;
    v_record           record;
BEGIN
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_existing_id FROM returns WHERE idempotency_key = p_idempotency_key;
        IF FOUND THEN
            RETURN jsonb_build_object('success', true, 'return_id', v_existing_id, 'idempotent', true);
        END IF;
    END IF;

    SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING MESSAGE = 'INVALID_RETURN';
    END IF;

    IF v_order.status NOT IN ('completed', 'delivered', 'partially_returned') THEN
        RAISE EXCEPTION USING MESSAGE = 'INVALID_RETURN_STATE';
    END IF;

    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION USING MESSAGE = 'INVALID_RETURN';
    END IF;

    CREATE TEMP TABLE tmp_ret_items ON COMMIT DROP AS
    SELECT (value->>'order_item_id')::uuid AS order_item_id,
           (value->>'product_id')::uuid AS product_id,
           SUM((value->>'quantity')::int)::int AS qty,
           MAX(value->>'reason') AS reason,
           (value->>'exchange_product_id')::uuid AS exchange_pid,
           COALESCE((value->>'exchange_location_id')::uuid, p_store_id) AS exchange_loc
    FROM jsonb_array_elements(p_items)
    GROUP BY 1, 2, 5, 6;

    IF EXISTS (SELECT 1 FROM tmp_ret_items WHERE qty <= 0) THEN
        RAISE EXCEPTION USING MESSAGE = 'INVALID_RETURN';
    END IF;

    -- Lock ALL return order_items
    PERFORM 1 FROM order_items
    WHERE id IN (SELECT order_item_id FROM tmp_ret_items)
    AND order_id = p_order_id
    ORDER BY id
    FOR UPDATE;

    -- STEP 1: Process Exchange Allocation
    IF p_type = 'exchange' THEN
        -- Lock ALL exchange inventory
        PERFORM 1 FROM inventory i
        JOIN tmp_ret_items r ON i.product_id = r.exchange_pid AND i.location_id = r.exchange_loc
        WHERE r.exchange_pid IS NOT NULL
        ORDER BY i.location_id, i.product_id
        FOR UPDATE;

        FOR v_record IN SELECT * FROM tmp_ret_items WHERE exchange_pid IS NOT NULL ORDER BY exchange_loc, exchange_pid
        LOOP
            SELECT * INTO v_inv
            FROM inventory
            WHERE product_id = v_record.exchange_pid 
            AND location_id = v_record.exchange_loc
            FOR UPDATE;

            IF NOT FOUND OR (v_inv.quantity - v_inv.reserved_quantity) < v_record.qty THEN
                RAISE EXCEPTION USING MESSAGE = 'EXCHANGE_NOT_AVAILABLE';
            END IF;

            UPDATE inventory
            SET reserved_quantity = reserved_quantity + v_record.qty,
                updated_at = now()
            WHERE product_id = v_record.exchange_pid AND location_id = v_record.exchange_loc;
        END LOOP;
    END IF;

    IF EXISTS (
      SELECT 1 FROM tmp_ret_items r
      WHERE NOT EXISTS (
        SELECT 1 FROM inventory i
        WHERE i.product_id = r.product_id
        AND i.location_id = p_store_id
      )
    ) THEN
      RAISE EXCEPTION USING MESSAGE = 'INVALID_RETURN';
    END IF;

    -- Lock ALL return inventory (destination)
    PERFORM 1 FROM inventory i
    JOIN tmp_ret_items r ON i.product_id = r.product_id
    WHERE i.location_id = p_store_id
    ORDER BY i.product_id
    FOR UPDATE;

    -- STEP 2: Process Returns + Validate
    FOR v_record IN SELECT * FROM tmp_ret_items ORDER BY order_item_id
    LOOP
        SELECT * INTO v_oi FROM order_items WHERE id = v_record.order_item_id AND order_id = p_order_id;
        IF NOT FOUND OR v_oi.product_id != v_record.product_id THEN
            RAISE EXCEPTION USING MESSAGE = 'INVALID_RETURN';
        END IF;

        v_purchased_qty := v_oi.quantity;

        SELECT COALESCE(SUM(ri.quantity), 0) INTO v_already_returned
        FROM return_items ri
        JOIN returns r ON r.id = ri.return_id
        WHERE ri.order_item_id = v_record.order_item_id
          AND r.status IN ('approved', 'completed');

        IF (v_already_returned + v_record.qty) > v_purchased_qty THEN
            RAISE EXCEPTION USING MESSAGE = 'INVALID_RETURN';
        END IF;
        
        UPDATE inventory
        SET quantity = quantity + v_record.qty,
            updated_at = now()
        WHERE product_id = v_record.product_id AND location_id = p_store_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING MESSAGE = 'INVALID_RETURN';
        END IF;
    END LOOP;

    INSERT INTO returns (order_id, store_id, type, status, refund_amount, processed_by, idempotency_key, notes)
    VALUES (p_order_id, p_store_id, p_type, 'completed', p_refund_amount, p_processed_by, p_idempotency_key, p_notes)
    RETURNING id INTO v_return_id;

    FOR v_record IN SELECT * FROM tmp_ret_items
    LOOP
        INSERT INTO return_items (return_id, order_item_id, product_id, quantity, reason, exchange_product_id, exchange_location_id)
        VALUES (v_return_id, v_record.order_item_id, v_record.product_id, v_record.qty, COALESCE(v_record.reason, 'customer_request'), v_record.exchange_pid, v_record.exchange_loc);
    END LOOP;

    UPDATE orders
    SET refund_total = refund_total + p_refund_amount,
        updated_at  = now()
    WHERE id = p_order_id;

    SELECT bool_and(COALESCE(rs.returned_sum, 0) >= oi.quantity)
    INTO v_all_returned
    FROM order_items oi
    LEFT JOIN (
        SELECT ri.order_item_id, SUM(ri.quantity) AS returned_sum
        FROM return_items ri
        JOIN returns r ON r.id = ri.return_id
        WHERE r.order_id = p_order_id AND r.status IN ('approved','completed')
        GROUP BY ri.order_item_id
    ) rs ON rs.order_item_id = oi.id
    WHERE oi.order_id = p_order_id;

    v_new_status := CASE WHEN v_all_returned THEN 'returned' ELSE 'partially_returned' END;

    UPDATE orders SET status = v_new_status, updated_at = now() WHERE id = p_order_id;

    INSERT INTO order_events (order_id, event_type, from_status, to_status, actor_id, notes)
    VALUES (p_order_id, 'returned', v_order.status, v_new_status, p_processed_by, 'refund=' || p_refund_amount);

    RETURN jsonb_build_object(
        'success', true,
        'return_id', v_return_id,
        'new_order_status', v_new_status,
        'refund_amount', p_refund_amount
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_return(uuid, uuid, text, jsonb, numeric, uuid, text, text) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. RPC: find_available_locations
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.find_available_locations(
    p_product_id       uuid,
    p_exclude_location uuid DEFAULT NULL,
    p_min_quantity     int  DEFAULT 1,
    p_requesting_city  text DEFAULT NULL
)
RETURNS TABLE (
    location_id   uuid,
    store_name    text,
    store_type    text,
    city          text,
    region        text,
    available_qty int,
    priority      int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        i.location_id,
        s.name    AS store_name,
        s.type    AS store_type,
        s.city,
        s.region,
        (i.quantity - i.reserved_quantity) AS available_qty,
        CASE
            WHEN p_requesting_city IS NOT NULL AND s.city = p_requesting_city THEN 1
            WHEN s.type = 'distribution_center' THEN 2
            ELSE 3
        END AS priority
    FROM inventory i
    JOIN stores s ON s.id = i.location_id
    WHERE i.product_id = p_product_id
      AND (i.quantity - i.reserved_quantity) >= p_min_quantity
      AND (p_exclude_location IS NULL OR i.location_id <> p_exclude_location)
    ORDER BY priority, (i.quantity - i.reserved_quantity) DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.find_available_locations(uuid, uuid, int, text) TO authenticated;
