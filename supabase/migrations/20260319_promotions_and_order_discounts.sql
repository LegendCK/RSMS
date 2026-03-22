-- =============================================================================
-- RSMS Promotions and Order Discount Support
-- =============================================================================

CREATE TABLE IF NOT EXISTS promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    details text,
    scope text NOT NULL CHECK (scope IN ('product', 'category')),
    target_product_id uuid REFERENCES products(id) ON DELETE CASCADE,
    target_category_id uuid REFERENCES categories(id) ON DELETE CASCADE,
    discount_type text NOT NULL CHECK (discount_type IN ('percentage', 'fixed_amount')),
    discount_value numeric(12,2) NOT NULL CHECK (discount_value > 0),
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_by uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT promotions_target_scope_check CHECK (
        (scope = 'product' AND target_product_id IS NOT NULL AND target_category_id IS NULL) OR
        (scope = 'category' AND target_category_id IS NOT NULL AND target_product_id IS NULL)
    ),
    CONSTRAINT promotions_date_window_check CHECK (ends_at >= starts_at)
);

ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins manage promotions" ON promotions;
CREATE POLICY "Admins manage promotions" ON promotions
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM users
        WHERE id = auth.uid()
          AND role = 'corporate_admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM users
        WHERE id = auth.uid()
          AND role = 'corporate_admin'
    )
);

DROP POLICY IF EXISTS "Authenticated users read active promotions" ON promotions;
CREATE POLICY "Authenticated users read active promotions" ON promotions
FOR SELECT
USING (is_active = true);

CREATE INDEX IF NOT EXISTS idx_promotions_active_window
ON promotions (is_active, starts_at, ends_at);

CREATE INDEX IF NOT EXISTS idx_promotions_product
ON promotions (target_product_id)
WHERE target_product_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_promotions_category
ON promotions (target_category_id)
WHERE target_category_id IS NOT NULL;

CREATE OR REPLACE FUNCTION set_promotions_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = timezone('utc', now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_promotions_updated_at ON promotions;
CREATE TRIGGER trg_promotions_updated_at
    BEFORE UPDATE ON promotions
    FOR EACH ROW
    EXECUTE FUNCTION set_promotions_updated_at();

ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS discount_total numeric(12,2) NOT NULL DEFAULT 0;
