-- =============================================================================
-- Migration: 20260324_discrepancy_inventory_rls
-- 2026-03-24
--
-- Adds missing Row Level Security policies for:
--   1. inventory_discrepancies  — store-scoped read/write; manager-only approve
--   2. inventory_discrepancy_logs — store-scoped read; authenticated insert
--   3. inventory               — store-scoped read/write for relevant staff roles
--   4. orders (SELECT)         — replaces the broad "all staff see all orders"
--                                policy with a store-scoped version
--
-- NOTE: store_id is a direct column on the public.users table (no staff_profiles).
--       All policies join only public.users where u.id = auth.uid().
-- =============================================================================


-- ── 1. inventory_discrepancies ────────────────────────────────────────────────

ALTER TABLE public.inventory_discrepancies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff view own store discrepancies"       ON public.inventory_discrepancies;
DROP POLICY IF EXISTS "Staff insert own store discrepancies"     ON public.inventory_discrepancies;
DROP POLICY IF EXISTS "Managers update own store discrepancies"  ON public.inventory_discrepancies;

-- SELECT: staff see only discrepancies from their assigned store; corp admin sees all
CREATE POLICY "Staff view own store discrepancies"
ON public.inventory_discrepancies FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND (
              u.role = 'corporate_admin'
              OR (
                  u.role IN (
                      'boutique_manager','inventory_controller',
                      'sales_associate','service_technician','aftersales_specialist'
                  )
                  AND u.store_id = inventory_discrepancies.store_id
              )
          )
    )
);

-- INSERT: any store staff can submit a discrepancy — only for their own store_id
CREATE POLICY "Staff insert own store discrepancies"
ON public.inventory_discrepancies FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role IN (
              'boutique_manager','inventory_controller',
              'sales_associate','service_technician','aftersales_specialist'
          )
          AND u.store_id = inventory_discrepancies.store_id
    )
);

-- UPDATE: only boutique_manager (for their store) or corporate_admin can approve/reject
CREATE POLICY "Managers update own store discrepancies"
ON public.inventory_discrepancies FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND (
              u.role = 'corporate_admin'
              OR (
                  u.role = 'boutique_manager'
                  AND u.store_id = inventory_discrepancies.store_id
              )
          )
    )
);


-- ── 2. inventory_discrepancy_logs ─────────────────────────────────────────────

ALTER TABLE public.inventory_discrepancy_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff view own store discrepancy logs"  ON public.inventory_discrepancy_logs;
DROP POLICY IF EXISTS "Authenticated insert discrepancy logs"  ON public.inventory_discrepancy_logs;

-- SELECT: staff can read logs for discrepancies that belong to their store
CREATE POLICY "Staff view own store discrepancy logs"
ON public.inventory_discrepancy_logs FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.inventory_discrepancies d
        JOIN public.users u ON u.id = auth.uid()
        WHERE d.id = inventory_discrepancy_logs.discrepancy_id
          AND (
              u.role = 'corporate_admin'
              OR (
                  u.role IN (
                      'boutique_manager','inventory_controller',
                      'sales_associate','service_technician','aftersales_specialist'
                  )
                  AND u.store_id = d.store_id
              )
          )
    )
);

-- INSERT: any authenticated staff can write audit log entries
-- (DiscrepancyService controls who calls this; the function enforces business logic)
CREATE POLICY "Authenticated insert discrepancy logs"
ON public.inventory_discrepancy_logs FOR INSERT TO authenticated
WITH CHECK (true);


-- ── 3. inventory ──────────────────────────────────────────────────────────────

ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff view own store inventory"   ON public.inventory;
DROP POLICY IF EXISTS "Staff upsert own store inventory" ON public.inventory;
DROP POLICY IF EXISTS "Staff update own store inventory" ON public.inventory;

-- SELECT: store staff see only their store's inventory rows; corp admin sees all
CREATE POLICY "Staff view own store inventory"
ON public.inventory FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND (
              u.role = 'corporate_admin'
              OR (
                  u.role IN (
                      'boutique_manager','inventory_controller',
                      'sales_associate','service_technician','aftersales_specialist'
                  )
                  AND u.store_id = inventory.store_id
              )
          )
    )
);

-- INSERT / UPSERT: boutique_manager & inventory_controller only, for their store
CREATE POLICY "Staff upsert own store inventory"
ON public.inventory FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND (
              u.role = 'corporate_admin'
              OR (
                  u.role IN ('boutique_manager','inventory_controller')
                  AND u.store_id = inventory.store_id
              )
          )
    )
);

-- UPDATE: same roles; note that decrement_order_inventory() is SECURITY DEFINER
-- and bypasses RLS entirely — fulfillment is unaffected by this policy
CREATE POLICY "Staff update own store inventory"
ON public.inventory FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND (
              u.role = 'corporate_admin'
              OR (
                  u.role IN ('boutique_manager','inventory_controller')
                  AND u.store_id = inventory.store_id
              )
          )
    )
);


-- ── 4. orders SELECT — replace broad "all staff" policy with store-scoped one ──

DROP POLICY IF EXISTS "Staff can view all orders" ON public.orders;

CREATE POLICY "Staff view own store orders"
ON public.orders FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND (
              u.role = 'corporate_admin'
              OR (
                  u.role IN (
                      'sales_associate','boutique_manager','inventory_controller',
                      'service_technician','aftersales_specialist'
                  )
                  AND u.store_id = orders.store_id
              )
          )
    )
);


-- ── 5. order_items SELECT — align with the narrowed orders policy ──────────────

DROP POLICY IF EXISTS "Staff can view all order items" ON public.order_items;

CREATE POLICY "Staff view own store order items"
ON public.order_items FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.orders o
        JOIN public.users u ON u.id = auth.uid()
        WHERE o.id = order_items.order_id
          AND (
              u.role = 'corporate_admin'
              OR (
                  u.role IN (
                      'sales_associate','boutique_manager','inventory_controller',
                      'service_technician','aftersales_specialist'
                  )
                  AND u.store_id = o.store_id
              )
          )
    )
);
