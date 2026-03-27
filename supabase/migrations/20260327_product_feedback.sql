-- =============================================================================
-- Migration: 20260327_product_feedback
-- 2026-03-27
--
-- Customer product reviews + store/admin visibility.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.product_feedback (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id    UUID        NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    store_id      UUID        REFERENCES public.stores(id) ON DELETE SET NULL,
    customer_id   UUID        NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    customer_name TEXT        NOT NULL DEFAULT '',
    rating        INT         NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title         TEXT        NOT NULL DEFAULT '',
    comment       TEXT        NOT NULL DEFAULT '',
    status        TEXT        NOT NULL DEFAULT 'published' CHECK (status IN ('published', 'hidden', 'flagged')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (product_id, customer_id)
);

CREATE INDEX IF NOT EXISTS idx_product_feedback_product_created
    ON public.product_feedback(product_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_product_feedback_store_created
    ON public.product_feedback(store_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_product_feedback_customer
    ON public.product_feedback(customer_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.set_product_feedback_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_product_feedback_updated_at ON public.product_feedback;
CREATE TRIGGER trg_product_feedback_updated_at
BEFORE UPDATE ON public.product_feedback
FOR EACH ROW
EXECUTE FUNCTION public.set_product_feedback_updated_at();

ALTER TABLE public.product_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Product feedback read published" ON public.product_feedback;
DROP POLICY IF EXISTS "Product feedback insert own" ON public.product_feedback;
DROP POLICY IF EXISTS "Product feedback update own" ON public.product_feedback;
DROP POLICY IF EXISTS "Product feedback staff read store" ON public.product_feedback;
DROP POLICY IF EXISTS "Product feedback admin moderate" ON public.product_feedback;

-- Published reviews are visible to all authenticated users.
CREATE POLICY "Product feedback read published"
ON public.product_feedback
FOR SELECT TO authenticated
USING (status = 'published');

-- Customers can insert their own review rows only.
CREATE POLICY "Product feedback insert own"
ON public.product_feedback
FOR INSERT TO authenticated
WITH CHECK (customer_id = auth.uid());

-- Customers can edit only their own reviews.
CREATE POLICY "Product feedback update own"
ON public.product_feedback
FOR UPDATE TO authenticated
USING (customer_id = auth.uid())
WITH CHECK (customer_id = auth.uid());

-- Staff can view feedback for their own store (including non-published rows).
CREATE POLICY "Product feedback staff read store"
ON public.product_feedback
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = auth.uid()
          AND (
              u.role = 'corporate_admin'
              OR (
                  u.store_id = product_feedback.store_id
                  AND u.role IN ('boutique_manager', 'sales_associate', 'inventory_controller', 'service_technician', 'aftersales_specialist')
              )
          )
    )
);

-- Corporate admin can moderate/patch status if needed.
CREATE POLICY "Product feedback admin moderate"
ON public.product_feedback
FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'corporate_admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'corporate_admin'
    )
);

ALTER PUBLICATION supabase_realtime ADD TABLE public.product_feedback;
