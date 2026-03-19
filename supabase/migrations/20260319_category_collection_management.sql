-- =============================================================================
-- RSMS Category + Brand Collection Management
-- =============================================================================

CREATE TABLE IF NOT EXISTS brand_collections (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    brand text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT brand_collections_name_unique UNIQUE (name)
);

ALTER TABLE brand_collections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins manage brand collections" ON brand_collections;
CREATE POLICY "Admins manage brand collections" ON brand_collections
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid()
          AND role = 'corporate_admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid()
          AND role = 'corporate_admin'
    )
);

DROP POLICY IF EXISTS "Authenticated read active brand collections" ON brand_collections;
CREATE POLICY "Authenticated read active brand collections" ON brand_collections
FOR SELECT
USING (is_active = true);

CREATE INDEX IF NOT EXISTS idx_brand_collections_active
ON brand_collections (is_active, name);

CREATE OR REPLACE FUNCTION set_brand_collections_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = timezone('utc', now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_brand_collections_updated_at ON brand_collections;
CREATE TRIGGER trg_brand_collections_updated_at
    BEFORE UPDATE ON brand_collections
    FOR EACH ROW
    EXECUTE FUNCTION set_brand_collections_updated_at();

ALTER TABLE products
    ADD COLUMN IF NOT EXISTS collection_id uuid REFERENCES brand_collections(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_products_collection_id
ON products (collection_id);
