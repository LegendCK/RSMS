-- ==========================================================================
-- RSMS Delivery Flow — Complete Supabase Setup
-- ==========================================================================
-- Run this ENTIRE script in: Supabase Dashboard → SQL Editor
-- Project: ebodhqmtiyhouezpoibl
-- ==========================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- 1. CREATE `transfers` TABLE (for replenishment requests)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS transfers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_number TEXT NOT NULL,
    product_id      UUID REFERENCES products(id) ON DELETE SET NULL,
    quantity        INT NOT NULL DEFAULT 0,
    from_boutique_id UUID REFERENCES stores(id) ON DELETE SET NULL,
    to_boutique_id  UUID REFERENCES stores(id) ON DELETE SET NULL,
    status          TEXT NOT NULL DEFAULT 'pending',
    requested_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE transfers ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. RLS POLICIES for `transfers`
-- ─────────────────────────────────────────────────────────────────────────

-- Staff (IC / Manager) can create transfer requests for their store
CREATE POLICY "Staff can create transfers" ON transfers
    FOR INSERT WITH CHECK (
        auth.uid() IN (
            SELECT id FROM users
            WHERE role IN ('inventory_controller', 'boutique_manager')
        )
    );

-- Staff can read transfers for their store; Admin can read all
CREATE POLICY "Staff and admin can read transfers" ON transfers
    FOR SELECT USING (
        to_boutique_id IN (
            SELECT store_id FROM users WHERE id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid() AND role = 'corporate_admin'
        )
    );

-- Admin can update transfers (approve, reject, etc.)
CREATE POLICY "Admin can update transfers" ON transfers
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid() AND role = 'corporate_admin'
        )
    );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. RLS POLICY for `order_items` (so IC can read order items)
-- ─────────────────────────────────────────────────────────────────────────

-- Drop existing policy if it conflicts
DROP POLICY IF EXISTS "Store staff read order_items" ON order_items;

CREATE POLICY "Store staff read order_items" ON order_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM orders o
            JOIN users u ON u.store_id = o.store_id
            WHERE o.id = order_items.order_id
              AND u.id = auth.uid()
              AND u.role IN (
                  'inventory_controller',
                  'boutique_manager',
                  'sales_associate',
                  'corporate_admin',
                  'aftersales_specialist'
              )
        )
    );

-- ─────────────────────────────────────────────────────────────────────────
-- 4. RLS POLICY for `inventory` (so admin can insert/update inventory)
-- ─────────────────────────────────────────────────────────────────────────

-- Allow admin and IC to update inventory (for replenishment)
DROP POLICY IF EXISTS "Staff can update inventory" ON inventory;
CREATE POLICY "Staff can update inventory" ON inventory
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid()
              AND role IN ('inventory_controller', 'boutique_manager', 'corporate_admin')
        )
    );

-- Allow admin to insert inventory rows (for new product-store combos)
DROP POLICY IF EXISTS "Admin can insert inventory" ON inventory;
CREATE POLICY "Admin can insert inventory" ON inventory
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid()
              AND role IN ('inventory_controller', 'boutique_manager', 'corporate_admin')
        )
    );

-- Allow staff to read inventory at their store; admin reads all
DROP POLICY IF EXISTS "Staff can read inventory" ON inventory;
CREATE POLICY "Staff can read inventory" ON inventory
    FOR SELECT USING (
        store_id IN (
            SELECT store_id FROM users WHERE id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid() AND role = 'corporate_admin'
        )
    );

-- ─────────────────────────────────────────────────────────────────────────
-- 5. SECURITY DEFINER RPC: get_order_items_for_fulfillment
--    (bypasses RLS so IC can always load order items)
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_order_items_for_fulfillment(p_order_id UUID)
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
        p.name AS product_name,
        p.sku AS product_sku,
        p.image_urls
    FROM order_items oi
    LEFT JOIN products p ON p.id = oi.product_id
    WHERE oi.order_id = p_order_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 6. SECURITY DEFINER RPC: assign_order_store
--    (allows customer's JWT to patch store_id on their order)
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION assign_order_store(p_order_id UUID, p_store_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE orders
    SET store_id = p_store_id,
        updated_at = NOW()
    WHERE id = p_order_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 7. Done! Verify
-- ─────────────────────────────────────────────────────────────────────────

-- Check transfers table exists
SELECT 'transfers table' AS check_item,
       EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'transfers') AS ok;

-- Check RPC exists
SELECT 'get_order_items_for_fulfillment RPC' AS check_item,
       EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_order_items_for_fulfillment') AS ok;

SELECT 'assign_order_store RPC' AS check_item,
       EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'assign_order_store') AS ok;
