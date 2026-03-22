-- =============================================================================
-- Migration: service_tickets_customer_rls
-- Allows authenticated customers to INSERT their own exchange/service requests
-- into service_tickets. Staff roles retain full access.
-- Run in: Supabase Dashboard → SQL Editor → New Query
-- =============================================================================

-- ── 1. Enable RLS if not already enabled ─────────────────────────────────────
ALTER TABLE public.service_tickets ENABLE ROW LEVEL SECURITY;

-- ── 2. Drop old open policies if any ────────────────────────────────────────
DROP POLICY IF EXISTS "Customers can insert own exchange requests" ON public.service_tickets;
DROP POLICY IF EXISTS "Staff can manage service tickets"           ON public.service_tickets;
DROP POLICY IF EXISTS "Customers can view own tickets"            ON public.service_tickets;

-- ── 3. Staff full access (all authenticated staff roles) ────────────────────
CREATE POLICY "Staff can manage service tickets"
ON public.service_tickets FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
    AND u.role IN (
      'sales_associate', 'boutique_manager', 'corporate_admin',
      'inventory_controller', 'service_technician', 'aftersales_specialist'
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
    AND u.role IN (
      'sales_associate', 'boutique_manager', 'corporate_admin',
      'inventory_controller', 'service_technician', 'aftersales_specialist'
    )
  )
);

-- ── 4. Customers: INSERT only (no client_id required to match — exchange
--       requests link via order/store, not always by client UUID) ────────────
CREATE POLICY "Customers can insert own exchange requests"
ON public.service_tickets FOR INSERT TO authenticated
WITH CHECK (
  -- Allow authenticated users with role = 'customer' (or no staff role)
  NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
    AND u.role IN (
      'sales_associate', 'boutique_manager', 'corporate_admin',
      'inventory_controller', 'service_technician', 'aftersales_specialist'
    )
  )
);

-- ── 5. Customers: SELECT their own tickets ───────────────────────────────────
CREATE POLICY "Customers can view own tickets"
ON public.service_tickets FOR SELECT TO authenticated
USING (
  -- If client_id matches the customer's UUID they can see the ticket
  client_id = auth.uid()
  OR
  -- Staff can see all (covered by policy above, but guard here too)
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
    AND u.role IN (
      'sales_associate', 'boutique_manager', 'corporate_admin',
      'inventory_controller', 'service_technician', 'aftersales_specialist'
    )
  )
);
