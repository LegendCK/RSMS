-- =============================================================================
-- Migration: 20260327_sales_looks
-- 2026-03-27
--
-- Creates:
--   1. public.sales_looks      — curated lookbooks created by store sales staff
--   2. RLS policies            — creator-owned write, store-scoped shared read
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.sales_looks (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id     UUID        NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    creator_id   UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    creator_name TEXT        NOT NULL DEFAULT '',
    name         TEXT        NOT NULL CHECK (char_length(btrim(name)) > 0),
    product_ids  UUID[]      NOT NULL DEFAULT '{}',
    is_shared    BOOLEAN     NOT NULL DEFAULT true,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_looks_store_created
    ON public.sales_looks(store_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sales_looks_creator_created
    ON public.sales_looks(creator_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sales_looks_shared_by_store
    ON public.sales_looks(store_id)
    WHERE is_shared = true;

CREATE OR REPLACE FUNCTION public.set_sales_looks_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sales_looks_updated_at ON public.sales_looks;
CREATE TRIGGER trg_sales_looks_updated_at
BEFORE UPDATE ON public.sales_looks
FOR EACH ROW
EXECUTE FUNCTION public.set_sales_looks_updated_at();

ALTER TABLE public.sales_looks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Sales looks select" ON public.sales_looks;
DROP POLICY IF EXISTS "Sales looks insert" ON public.sales_looks;
DROP POLICY IF EXISTS "Sales looks update" ON public.sales_looks;
DROP POLICY IF EXISTS "Sales looks delete" ON public.sales_looks;

-- View policy:
-- - creator can always view own looks
-- - same-store staff can view shared looks
-- - corporate admins can view all looks
CREATE POLICY "Sales looks select"
ON public.sales_looks
FOR SELECT TO authenticated
USING (
    creator_id = auth.uid()
    OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = auth.uid()
          AND (
              u.role = 'corporate_admin'
              OR (
                  sales_looks.is_shared = true
                  AND u.store_id = sales_looks.store_id
                  AND u.role IN (
                      'boutique_manager',
                      'sales_associate',
                      'inventory_controller',
                      'service_technician',
                      'aftersales_specialist'
                  )
              )
          )
    )
);

-- Insert policy:
-- - creator_id must be current auth user
-- - user can insert for own store (or corporate admin)
CREATE POLICY "Sales looks insert"
ON public.sales_looks
FOR INSERT TO authenticated
WITH CHECK (
    creator_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = auth.uid()
          AND (
              u.role = 'corporate_admin'
              OR (
                  u.store_id = sales_looks.store_id
                  AND u.role IN (
                      'boutique_manager',
                      'sales_associate',
                      'inventory_controller',
                      'service_technician',
                      'aftersales_specialist'
                  )
              )
          )
    )
);

-- Update/delete policy:
-- - creator can modify own row
-- - corporate admin can modify any row
CREATE POLICY "Sales looks update"
ON public.sales_looks
FOR UPDATE TO authenticated
USING (
    creator_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'corporate_admin'
    )
)
WITH CHECK (
    creator_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'corporate_admin'
    )
);

CREATE POLICY "Sales looks delete"
ON public.sales_looks
FOR DELETE TO authenticated
USING (
    creator_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'corporate_admin'
    )
);

-- Realtime support for collaborative visibility in-app.
ALTER PUBLICATION supabase_realtime ADD TABLE public.sales_looks;
