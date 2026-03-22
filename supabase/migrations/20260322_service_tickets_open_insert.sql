-- =============================================================================
-- DEFINITIVE FIX: service_tickets RLS for customer exchange requests
-- This script:
--   1. Dynamically drops EVERY existing policy on service_tickets
--   2. Adds exactly the two policies needed
-- Run in: Supabase Dashboard → SQL Editor → New Query
-- =============================================================================

-- Step 1: Drop ALL existing policies on service_tickets (dynamic, handles any name)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE tablename = 'service_tickets'
      AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.service_tickets', r.policyname);
    RAISE NOTICE 'Dropped policy: %', r.policyname;
  END LOOP;
END $$;

-- Step 2: Make sure RLS is enabled
ALTER TABLE public.service_tickets ENABLE ROW LEVEL SECURITY;

-- Step 3: Allow ALL authenticated users to INSERT (customers submitting requests)
CREATE POLICY "allow_authenticated_insert"
  ON public.service_tickets
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Step 4: Staff roles can do everything else (SELECT, UPDATE, DELETE)
CREATE POLICY "allow_staff_all"
  ON public.service_tickets
  FOR ALL
  TO authenticated
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

-- Step 5: Customers can SELECT their own tickets
CREATE POLICY "allow_customers_select_own"
  ON public.service_tickets
  FOR SELECT
  TO authenticated
  USING (client_id = auth.uid());

-- Verify policies were created
SELECT policyname, cmd, roles, qual::text, with_check::text
FROM pg_policies
WHERE tablename = 'service_tickets' AND schemaname = 'public';
