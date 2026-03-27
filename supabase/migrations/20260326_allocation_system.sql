-- ============================================================================
-- Centralized Inventory Allocation System
-- Tables: inventory, allocations, allocation_logs
-- RPCs:   create_allocation, complete_allocation
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- 1. INVENTORY — per-product, per-location stock tracking
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS inventory (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id      uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    location_id     uuid NOT NULL REFERENCES stores(id)   ON DELETE CASCADE,
    quantity         int  NOT NULL DEFAULT 0,
    reserved_quantity int NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT inventory_product_location_uq UNIQUE (product_id, location_id),
    CONSTRAINT inventory_quantity_non_negative CHECK (quantity >= 0),
    CONSTRAINT inventory_reserved_non_negative CHECK (reserved_quantity >= 0),
    CONSTRAINT inventory_reserved_lte_quantity CHECK (reserved_quantity <= quantity)
);

CREATE INDEX IF NOT EXISTS idx_inventory_location ON inventory(location_id);
CREATE INDEX IF NOT EXISTS idx_inventory_product  ON inventory(product_id);

-- ────────────────────────────────────────────────────────────────────────────
-- 2. ALLOCATIONS — stock movement records
-- ────────────────────────────────────────────────────────────────────────────

CREATE TYPE allocation_status AS ENUM ('PENDING', 'IN_TRANSIT', 'COMPLETED', 'CANCELLED');

CREATE TABLE IF NOT EXISTS allocations (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id        uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    from_location_id  uuid NOT NULL REFERENCES stores(id)   ON DELETE CASCADE,
    to_location_id    uuid NOT NULL REFERENCES stores(id)   ON DELETE CASCADE,
    quantity          int  NOT NULL CHECK (quantity > 0),
    status            allocation_status NOT NULL DEFAULT 'PENDING',
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    created_by        uuid REFERENCES auth.users(id),

    CONSTRAINT allocations_different_locations CHECK (from_location_id <> to_location_id)
);

CREATE INDEX IF NOT EXISTS idx_allocations_status  ON allocations(status);
CREATE INDEX IF NOT EXISTS idx_allocations_product ON allocations(product_id);

-- ────────────────────────────────────────────────────────────────────────────
-- 3. ALLOCATION LOGS — immutable audit trail
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS allocation_logs (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    allocation_id   uuid NOT NULL REFERENCES allocations(id) ON DELETE CASCADE,
    action          text NOT NULL,
    performed_by    uuid REFERENCES auth.users(id),
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_allocation_logs_alloc ON allocation_logs(allocation_id);

-- ────────────────────────────────────────────────────────────────────────────
-- 4. RPC: create_allocation
--    Atomically validates stock, reserves, and creates the allocation.
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
        RETURN jsonb_build_object('success', false, 'error', 'Source and destination must differ');
    END IF;

    -- Lock the source inventory row for update (prevents concurrent over-allocation)
    SELECT * INTO v_inv_row
    FROM inventory
    WHERE product_id = p_product_id AND location_id = p_from_location_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'No inventory record at source location');
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
        updated_at = now()
    WHERE product_id = p_product_id AND location_id = p_from_location_id;

    -- Create allocation record
    INSERT INTO allocations (product_id, from_location_id, to_location_id, quantity, status, created_by)
    VALUES (p_product_id, p_from_location_id, p_to_location_id, p_quantity, 'PENDING', p_created_by)
    RETURNING id INTO v_alloc_id;

    -- Audit log
    INSERT INTO allocation_logs (allocation_id, action, performed_by)
    VALUES (v_alloc_id, 'CREATED', p_created_by);

    RETURN jsonb_build_object(
        'success', true,
        'allocation_id', v_alloc_id,
        'reserved', p_quantity
    );
END;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- 5. RPC: complete_allocation
--    Atomically transfers reserved stock from source to destination.
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

    -- Idempotency: already completed
    IF v_alloc.status = 'COMPLETED' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Already completed');
    END IF;

    -- Only PENDING or IN_TRANSIT can be completed
    IF v_alloc.status NOT IN ('PENDING', 'IN_TRANSIT') THEN
        RETURN jsonb_build_object('success', false, 'error', format('Cannot complete allocation with status: %s', v_alloc.status));
    END IF;

    -- 1. Reduce reserved_quantity at source
    UPDATE inventory
    SET reserved_quantity = reserved_quantity - v_alloc.quantity,
        quantity = quantity - v_alloc.quantity,
        updated_at = now()
    WHERE product_id = v_alloc.product_id AND location_id = v_alloc.from_location_id;

    -- 2. Increase quantity at destination (upsert)
    INSERT INTO inventory (product_id, location_id, quantity, reserved_quantity)
    VALUES (v_alloc.product_id, v_alloc.to_location_id, v_alloc.quantity, 0)
    ON CONFLICT (product_id, location_id)
    DO UPDATE SET quantity = inventory.quantity + EXCLUDED.quantity,
                  updated_at = now();

    -- 3. Update allocation status
    UPDATE allocations
    SET status = 'COMPLETED', updated_at = now()
    WHERE id = p_allocation_id;

    -- 4. Audit log
    INSERT INTO allocation_logs (allocation_id, action, performed_by)
    VALUES (p_allocation_id, 'COMPLETED', p_performed_by);

    RETURN jsonb_build_object('success', true, 'message', 'Allocation completed');
END;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- 6. RLS Policies
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE inventory       ENABLE ROW LEVEL SECURITY;
ALTER TABLE allocations     ENABLE ROW LEVEL SECURITY;
ALTER TABLE allocation_logs ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read all inventory/allocations/logs
CREATE POLICY "inventory_select"       ON inventory       FOR SELECT TO authenticated USING (true);
CREATE POLICY "allocations_select"     ON allocations     FOR SELECT TO authenticated USING (true);
CREATE POLICY "allocation_logs_select" ON allocation_logs FOR SELECT TO authenticated USING (true);

-- Inserts/updates handled by SECURITY DEFINER RPCs, but allow direct insert for seeding
CREATE POLICY "inventory_insert"       ON inventory       FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "inventory_update"       ON inventory       FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allocations_insert"     ON allocations     FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allocation_logs_insert" ON allocation_logs FOR INSERT TO authenticated WITH CHECK (true);
