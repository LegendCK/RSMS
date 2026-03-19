-- =============================================================================
-- RSMS Scan System – Production Hardening Migration
-- Applies on top of 20260318_create_product_items_bulk.sql
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 1. ENUM CREATION & SAFE CASTING
-- ----------------------------------------------------------------------------

-- Create Types
CREATE TYPE item_status_enum AS ENUM ('IN_STOCK', 'SOLD', 'RESERVED', 'DAMAGED', 'RETURNED');
CREATE TYPE scan_type_enum AS ENUM ('IN', 'OUT', 'AUDIT');
CREATE TYPE session_status_enum AS ENUM ('ACTIVE', 'COMPLETED', 'CANCELLED', 'EXPIRED');

-- Safely cleanse invalid data before casting to prevent migration crashes
UPDATE product_items SET status = 'IN_STOCK' 
WHERE status IS NULL OR status NOT IN ('IN_STOCK', 'SOLD', 'RESERVED', 'DAMAGED', 'RETURNED');

UPDATE scan_sessions SET type = 'AUDIT' 
WHERE type IS NULL OR type NOT IN ('IN', 'OUT', 'AUDIT');

UPDATE scan_sessions SET status = 'COMPLETED' 
WHERE status IS NULL OR status NOT IN ('ACTIVE', 'COMPLETED', 'CANCELLED', 'EXPIRED');

UPDATE scan_logs SET type = 'AUDIT' 
WHERE type IS NULL OR type NOT IN ('IN', 'OUT', 'AUDIT');

-- Drop old constraints and alter column boundaries
ALTER TABLE product_items 
    DROP CONSTRAINT IF EXISTS product_items_status_check,
    ALTER COLUMN status TYPE item_status_enum USING status::item_status_enum,
    ALTER COLUMN status SET DEFAULT 'IN_STOCK'::item_status_enum;

ALTER TABLE scan_sessions 
    DROP CONSTRAINT IF EXISTS scan_sessions_type_check,
    ALTER COLUMN type TYPE scan_type_enum USING type::scan_type_enum,
    DROP CONSTRAINT IF EXISTS scan_sessions_status_check,
    ALTER COLUMN status TYPE session_status_enum USING status::session_status_enum,
    ALTER COLUMN status SET DEFAULT 'ACTIVE'::session_status_enum;

ALTER TABLE scan_logs
    DROP CONSTRAINT IF EXISTS scan_logs_type_check,
    ALTER COLUMN type TYPE scan_type_enum USING type::scan_type_enum,
    ALTER COLUMN type SET DEFAULT 'AUDIT'::scan_type_enum;


-- ----------------------------------------------------------------------------
-- 2. CASCADE DELETE CORRECTIONS (AUDIT & ORPHAN PROTECTION)
-- ----------------------------------------------------------------------------

-- A: Protect physical inventory history if a catalog product is deleted
ALTER TABLE product_items DROP CONSTRAINT IF EXISTS product_items_product_id_fkey;
ALTER TABLE product_items 
    ADD CONSTRAINT product_items_product_id_fkey 
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT;

-- B: Protect scan logs from being wiped if a session is deleted
ALTER TABLE scan_logs DROP CONSTRAINT IF EXISTS scan_logs_session_id_fkey;
ALTER TABLE scan_logs 
    ADD CONSTRAINT scan_logs_session_id_fkey 
    FOREIGN KEY (session_id) REFERENCES scan_sessions(id) ON DELETE RESTRICT;

-- C: Add soft delete markers for catalog items safely
ALTER TABLE products ADD COLUMN IF NOT EXISTS deleted_at timestamptz DEFAULT NULL;
ALTER TABLE product_items ADD COLUMN IF NOT EXISTS deleted_at timestamptz DEFAULT NULL;


-- ----------------------------------------------------------------------------
-- 3. CHRONOLOGICAL PERFORMANCE INDEXES
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_scan_logs_scanned_at ON scan_logs(scanned_at DESC);
CREATE INDEX IF NOT EXISTS idx_scan_sessions_started_at ON scan_sessions(started_at DESC);


-- ----------------------------------------------------------------------------
-- 4. RLS TIGHTENING ( inventory_controller ONLY )
-- ----------------------------------------------------------------------------

-- Remove insecure public policies
DROP POLICY IF EXISTS "Allow authenticated users to insert product_items" ON product_items;
DROP POLICY IF EXISTS "Allow authenticated users to update product_items" ON product_items;
DROP POLICY IF EXISTS "Allow authenticated users to manage scan_sessions" ON scan_sessions;
DROP POLICY IF EXISTS "Allow authenticated users to manage scan_logs" ON scan_logs;

-- Rebuild Product Items Policies
CREATE POLICY "Inventory Controller Insert Stock" ON product_items FOR INSERT 
WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'inventory_controller'));

CREATE POLICY "Inventory Controller Update Stock" ON product_items FOR UPDATE 
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'inventory_controller'));

-- Rebuild Sessions Policies (Admins can READ, only Controllers can MANAGE)
CREATE POLICY "Admins Read Sessions" ON scan_sessions FOR SELECT 
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('corporate_admin', 'boutique_manager', 'inventory_controller')));

CREATE POLICY "Controllers Manage Sessions" ON scan_sessions FOR ALL 
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'inventory_controller'));

-- Rebuild Logs Policies (Admins can READ, only Controllers can MANAGE)
CREATE POLICY "Admins Read Logs" ON scan_logs FOR SELECT 
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('corporate_admin', 'boutique_manager', 'inventory_controller')));

CREATE POLICY "Controllers Manage Logs" ON scan_logs FOR ALL 
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'inventory_controller'));


-- ----------------------------------------------------------------------------
-- 5. STATE & TRANSITION SAFETY (TRIGGERS)
-- ----------------------------------------------------------------------------

-- Prevent Double Selling & Validate Transitions
CREATE OR REPLACE FUNCTION validate_product_item_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Prevent selling an already sold item
    IF OLD.status = 'SOLD'::item_status_enum AND NEW.status = 'SOLD'::item_status_enum THEN
        RAISE EXCEPTION 'Item % is already sold. Cannot transition from SOLD to SOLD.', OLD.barcode;
    END IF;

    -- Standard allowed transition rules (prevent returning an IN_STOCK item)
    IF OLD.status = 'IN_STOCK'::item_status_enum AND NEW.status = 'RETURNED'::item_status_enum THEN
        RAISE EXCEPTION 'Cannot return an item that is currently in stock.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_product_item_transition ON product_items;
CREATE TRIGGER trg_validate_product_item_transition
    BEFORE UPDATE ON product_items
    FOR EACH ROW
    EXECUTE FUNCTION validate_product_item_transition();

-- Ensure Session is Active when Scanning
CREATE OR REPLACE FUNCTION validate_active_session_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM scan_sessions 
        WHERE id = NEW.session_id AND status = 'ACTIVE'::session_status_enum
    ) THEN
        RAISE EXCEPTION 'Cannot log scan: Session % is not ACTIVE', NEW.session_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_active_session_insert ON scan_logs;
CREATE TRIGGER trg_validate_active_session_insert
    BEFORE INSERT ON scan_logs
    FOR EACH ROW
    EXECUTE FUNCTION validate_active_session_insert();


-- ----------------------------------------------------------------------------
-- 6. ATOMIC TRANSACTION (RPC PIPELINE)
-- ----------------------------------------------------------------------------
-- Safely handle a complete scanning lifecycle in a single generic database transaction
-- preventing network dropouts from causing orphaned log events.

CREATE OR REPLACE FUNCTION process_scan_event(
    p_barcode text,
    p_session_id uuid,
    p_target_status item_status_enum,
    p_scan_type scan_type_enum
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- 1. Validate permissions
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'inventory_controller') THEN
        RAISE EXCEPTION 'Unauthorized: Only Inventory Controllers can process scan events.';
    END IF;

    -- 2. Validate Session 
    IF NOT EXISTS (SELECT 1 FROM scan_sessions WHERE id = p_session_id AND status = 'ACTIVE'::session_status_enum) THEN
        RAISE EXCEPTION 'Cannot process scan: Session is not ACTIVE';
    END IF;

    -- 3. Log the scan event
    INSERT INTO scan_logs (barcode, session_id, type)
    VALUES (p_barcode, p_session_id, p_scan_type);

    -- 4. Update the physical item status (Trigger guards double-sells intrinsically)
    UPDATE product_items 
    SET status = p_target_status 
    WHERE barcode = p_barcode;

    -- 5. Exception if barcode not found in physical inventory
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Barcode % not found in product_items', p_barcode;
    END IF;
    
END;
$$;

GRANT EXECUTE ON FUNCTION process_scan_event(text, uuid, item_status_enum, scan_type_enum) TO authenticated;
