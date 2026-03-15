-- ============================================================
-- Migration: fix_clients_rls_select_policy
-- Purpose  : Add missing RLS SELECT (and related) policies on
--            the `clients` table so customers can re-login.
--
-- Root cause: During signup the client profile is returned as
-- the INSERT response — no SELECT RLS check runs.  On every
-- subsequent login AuthService performs a plain SELECT, which
-- requires a SELECT policy.  Without it RLS returns 0 rows,
-- .single() throws, the error is swallowed, and the app shows
-- "Account profile not found".
--
-- How to apply: paste this entire file into the Supabase
-- Dashboard → SQL Editor → Run.
-- ============================================================

-- 1. Make sure RLS is enabled (idempotent)
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- 2. Drop old / conflicting policies so we can recreate cleanly
DROP POLICY IF EXISTS "clients_select_own"          ON public.clients;
DROP POLICY IF EXISTS "clients_insert_own"          ON public.clients;
DROP POLICY IF EXISTS "clients_update_own"          ON public.clients;
DROP POLICY IF EXISTS "staff_select_all_clients"    ON public.clients;
DROP POLICY IF EXISTS "Allow individual read access"   ON public.clients;
DROP POLICY IF EXISTS "Allow individual insert access" ON public.clients;
DROP POLICY IF EXISTS "Allow individual update access" ON public.clients;

-- 3. Customers can SELECT their own profile row
--    (fixes the re-login "profile not found" bug)
CREATE POLICY "clients_select_own"
ON public.clients
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- 4. Customers can INSERT their own profile row (signup)
CREATE POLICY "clients_insert_own"
ON public.clients
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 5. Customers can UPDATE their own profile row
CREATE POLICY "clients_update_own"
ON public.clients
FOR UPDATE
TO authenticated
USING  (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 6. Staff users (anyone with a row in `users`) can SELECT all
--    client profiles — needed for the staff-facing CRM screens.
CREATE POLICY "staff_select_all_clients"
ON public.clients
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
    )
);
