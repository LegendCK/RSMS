-- ============================================================================
-- Allocation System Patch — IN_TRANSIT lifecycle + hardening
-- 20260326_allocation_system_patch.sql
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- 1.  dispatch_allocation RPC
--     PENDING → IN_TRANSIT  (does NOT move stock — that happens on completion)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION dispatch_allocation(
    p_allocation_id uuid,
    p_performed_by  uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_alloc allocations%ROWTYPE;
BEGIN
    -- Lock row to prevent concurrent dispatch
    SELECT * INTO v_alloc
    FROM allocations
    WHERE id = p_allocation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Allocation not found');
    END IF;

    -- Idempotency: already in transit
    IF v_alloc.status = 'IN_TRANSIT' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Already in transit');
    END IF;

    -- Only PENDING can be dispatched
    IF v_alloc.status <> 'PENDING' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Cannot dispatch allocation with status: %s', v_alloc.status)
        );
    END IF;

    -- Update status
    UPDATE allocations
    SET status     = 'IN_TRANSIT',
        updated_at = now()
    WHERE id = p_allocation_id;

    -- Audit log
    INSERT INTO allocation_logs (allocation_id, action, performed_by)
    VALUES (p_allocation_id, 'DISPATCHED', p_performed_by);

    RETURN jsonb_build_object('success', true, 'message', 'Allocation dispatched');
END;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- 2.  Harden create_allocation — explicit guard on same-location
--     (belt-and-suspenders: DB constraint already exists, but the RPC
--      returns a user-friendly message rather than a raw SQL error)
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_allocation(
    p_product_id       uuid,
    p_from_location_id uuid,
    p_to_location_id   uuid,
    p_quantity          int,
    p_created_by       uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_available   int;
    v_alloc_id    uuid;
    v_inv_row     inventory%ROWTYPE;
BEGIN
    -- Validate inputs
    IF p_quantity <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Quantity must be greater than 0');
    END IF;

    IF p_from_location_id = p_to_location_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Source and destination must be different locations');
    END IF;

    -- Lock source inventory row
    SELECT * INTO v_inv_row
    FROM inventory
    WHERE product_id = p_product_id AND location_id = p_from_location_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'No inventory record found at source location');
    END IF;

    v_available := v_inv_row.quantity - v_inv_row.reserved_quantity;

    IF p_quantity > v_available THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Insufficient stock. Available: %s, Requested: %s', v_available, p_quantity)
        );
    END IF;

    -- Reserve stock at source
    UPDATE inventory
    SET reserved_quantity = reserved_quantity + p_quantity,
        updated_at        = now()
    WHERE product_id = p_product_id AND location_id = p_from_location_id;

    -- Create allocation record
    INSERT INTO allocations (product_id, from_location_id, to_location_id, quantity, status, created_by)
    VALUES (p_product_id, p_from_location_id, p_to_location_id, p_quantity, 'PENDING', p_created_by)
    RETURNING id INTO v_alloc_id;

    -- Audit log
    INSERT INTO allocation_logs (allocation_id, action, performed_by)
    VALUES (v_alloc_id, 'CREATED', p_created_by);

    RETURN jsonb_build_object(
        'success',       true,
        'allocation_id', v_alloc_id,
        'reserved',      p_quantity
    );
END;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- 3.  Harden complete_allocation — guaranteed destination UPSERT
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION complete_allocation(
    p_allocation_id uuid,
    p_performed_by  uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_alloc allocations%ROWTYPE;
BEGIN
    -- Lock allocation row
    SELECT * INTO v_alloc
    FROM allocations
    WHERE id = p_allocation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Allocation not found');
    END IF;

    -- Idempotency
    IF v_alloc.status = 'COMPLETED' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Already completed');
    END IF;

    -- Guard: only PENDING or IN_TRANSIT
    IF v_alloc.status NOT IN ('PENDING', 'IN_TRANSIT') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Cannot complete allocation with status: %s', v_alloc.status)
        );
    END IF;

    -- 1. Reduce reserved + actual quantity at source (with lock)
    UPDATE inventory
    SET reserved_quantity = GREATEST(reserved_quantity - v_alloc.quantity, 0),
        quantity          = GREATEST(quantity          - v_alloc.quantity, 0),
        updated_at        = now()
    WHERE product_id = v_alloc.product_id AND location_id = v_alloc.from_location_id;

    -- 2. Upsert quantity at destination (creates row if missing)
    INSERT INTO inventory (product_id, location_id, quantity, reserved_quantity)
    VALUES (v_alloc.product_id, v_alloc.to_location_id, v_alloc.quantity, 0)
    ON CONFLICT (product_id, location_id)
    DO UPDATE SET
        quantity   = inventory.quantity + EXCLUDED.quantity,
        updated_at = now();

    -- 3. Update allocation status
    UPDATE allocations
    SET status     = 'COMPLETED',
        updated_at = now()
    WHERE id = p_allocation_id;

    -- 4. Audit log
    INSERT INTO allocation_logs (allocation_id, action, performed_by)
    VALUES (p_allocation_id, 'COMPLETED', p_performed_by);

    RETURN jsonb_build_object('success', true, 'message', 'Allocation completed');
END;
$$;
