-- RSMS Products Table RLS Policies
-- Multi-store architecture security design with B-Tree Indexing

-- Prerequisites: Ensure the `products` table has a `store_id` column
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS store_id UUID;

-- 1. Enable RLS on the products table
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 2. Prevent accidental destructive actions by dropping any existing permissive policies
DROP POLICY IF EXISTS "products_select_policy" ON public.products;
DROP POLICY IF EXISTS "products_insert_policy" ON public.products;
DROP POLICY IF EXISTS "products_update_policy" ON public.products;
DROP POLICY IF EXISTS "products_delete_policy" ON public.products;

-- ─────────────────────────────────────────────────────────────────────────────
-- OPTIMIZED JWT CLAIMS FUNCTION
-- Casting auth.jwt()->>'store_id' row-by-row drops B-Tree indexes.
-- We use a STABLE function so the query planner can cache and use indexes.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_user_store_id() RETURNS uuid STABLE AS $$
  SELECT (current_setting('request.jwt.claims', true)::jsonb ->> 'store_id')::uuid;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_user_role() RETURNS text STABLE AS $$
  SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'role';
$$ LANGUAGE sql;

-- Create B-Tree index for performance
CREATE INDEX IF NOT EXISTS idx_products_store_id ON public.products(store_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- ACTIVE POLICIES
-- ─────────────────────────────────────────────────────────────────────────────

-- SELECT Policy
CREATE POLICY "products_select_policy"
    ON public.products
    FOR SELECT
    USING (
        store_id = get_user_store_id()
        OR get_user_role() = 'corporateAdmin'
    );

-- INSERT Policy
CREATE POLICY "products_insert_policy"
    ON public.products
    FOR INSERT
    WITH CHECK (
        store_id = get_user_store_id()
        OR get_user_role() = 'corporateAdmin'
    );

-- UPDATE Policy
CREATE POLICY "products_update_policy"
    ON public.products
    FOR UPDATE
    USING (
        store_id = get_user_store_id()
        OR get_user_role() = 'corporateAdmin'
    )
    WITH CHECK (
        store_id = get_user_store_id()
        OR get_user_role() = 'corporateAdmin'
    );

-- DELETE Policy
CREATE POLICY "products_delete_policy"
    ON public.products
    FOR DELETE
    USING (
        get_user_role() = 'corporateAdmin'
    );
