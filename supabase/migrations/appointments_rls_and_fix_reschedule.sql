-- ============================================================
-- Migration: appointments_rls_and_fix_reschedule
-- Purpose  : 1. Add RLS policies on the `appointments` table
--               so staff and customers can read/write correctly.
--            2. Clear stale associate_id values on "requested"
--               appointments so they appear in the SA Requests tab.
--            3. Re-apply the staff_select_all_clients policy on
--               `clients` in case it was dropped.
--
-- How to apply: Supabase Dashboard → SQL Editor → paste → Run
-- ============================================================

-- ── 1. Enable RLS on appointments ───────────────────────────
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- ── 2. Drop old policies so we can recreate cleanly ─────────
DROP POLICY IF EXISTS "Staff can view store appointments"          ON public.appointments;
DROP POLICY IF EXISTS "Customers can view own appointments"        ON public.appointments;
DROP POLICY IF EXISTS "Staff can insert appointments"              ON public.appointments;
DROP POLICY IF EXISTS "Customers can insert own appointments"      ON public.appointments;
DROP POLICY IF EXISTS "Staff can update appointments"              ON public.appointments;
DROP POLICY IF EXISTS "Customers can update own appointments"      ON public.appointments;

-- ── 3. SELECT: staff see all appointments ───────────────────
CREATE POLICY "Staff can view store appointments"
ON public.appointments
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role IN (
              'sales_associate', 'boutique_manager', 'corporate_admin',
              'aftersales_specialist', 'inventory_controller', 'service_technician'
          )
    )
);

-- ── 4. SELECT: customers see their own appointments ──────────
CREATE POLICY "Customers can view own appointments"
ON public.appointments
FOR SELECT TO authenticated
USING (client_id = auth.uid());

-- ── 5. INSERT: staff can create appointments ─────────────────
CREATE POLICY "Staff can insert appointments"
ON public.appointments
FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role IN (
              'sales_associate', 'boutique_manager', 'corporate_admin', 'aftersales_specialist'
          )
    )
);

-- ── 6. INSERT: customers can submit appointment requests ─────
CREATE POLICY "Customers can insert own appointments"
ON public.appointments
FOR INSERT TO authenticated
WITH CHECK (client_id = auth.uid() AND status = 'requested');

-- ── 7. UPDATE: staff can update any appointment ──────────────
CREATE POLICY "Staff can update appointments"
ON public.appointments
FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role IN (
              'sales_associate', 'boutique_manager', 'corporate_admin', 'aftersales_specialist'
          )
    )
);

-- ── 8. UPDATE: customers can cancel / reschedule their own ───
CREATE POLICY "Customers can update own appointments"
ON public.appointments
FOR UPDATE TO authenticated
USING  (client_id = auth.uid())
WITH CHECK (client_id = auth.uid());

-- ── 9. Fix stale data: clear associate_id for "requested" ────
-- When a customer requests a reschedule the iOS app sets
-- associate_id = NULL, but older builds omitted the key so the
-- old value was never cleared. This sets them all to NULL so
-- they appear correctly in the SA Requests tab.
UPDATE public.appointments
SET associate_id = NULL
WHERE status = 'requested'
  AND associate_id IS NOT NULL;

-- ── 10. Re-apply staff_select_all_clients on clients ────────
DROP POLICY IF EXISTS "staff_select_all_clients" ON public.clients;
CREATE POLICY "staff_select_all_clients"
ON public.clients
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
    )
);
