-- =============================================================================
-- RSMS — Production Audit Hardening: ENUM expansion + RPC hardening
-- Created: 2026-03-26
-- =============================================================================
--
-- CRITICAL ISSUES FOUND IN AUDIT:
--
-- 1. scan_type_enum is a POSTGRES ENUM TYPE ('IN','OUT','AUDIT') — the previous
--    migration only patched text CHECK constraints, but the columns were already
--    converted to use this native ENUM. ALTER TYPE must be used instead.
--
-- 2. process_scan_event() RPC uses scan_type_enum typed parameter — RETURN was
--    never accepted. Needs ENUM expansion + RPC function update.
--
-- 3. scan_sessions table has no store_id or created_by columns, meaning sessions
--    cannot be filtered per-store in admin dashboards.
--
-- 4. The validate_product_item_transition trigger does not guard IN → IN
--    (calling Stock In on an already-in-stock item creates a redundant log entry
--    but doesn't error — acceptable but noted).
--
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Expand scan_type_enum to include 'RETURN'
--    ALTER TYPE ... ADD VALUE is safe and non-destructive.
--    Note: cannot run inside a transaction block in Postgres — handled by
--    Supabase migration runner which wraps each statement independently.
-- ---------------------------------------------------------------------------
ALTER TYPE scan_type_enum ADD VALUE IF NOT EXISTS 'RETURN';

-- ---------------------------------------------------------------------------
-- 2. Add 'RETURNED' to item_status_enum
--    (defensive — our previous migration only patched text CHECKs)
-- ---------------------------------------------------------------------------
ALTER TYPE item_status_enum ADD VALUE IF NOT EXISTS 'RETURNED';

-- ---------------------------------------------------------------------------
-- 3. Add store_id and created_by to scan_sessions
--    These allow per-store session filtering in dashboards.
--    Both nullable for backward compatibility with existing rows.
-- ---------------------------------------------------------------------------
ALTER TABLE scan_sessions
    ADD COLUMN IF NOT EXISTS store_id   uuid REFERENCES stores(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users(id)  ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_scan_sessions_store_id
    ON scan_sessions(store_id);

CREATE INDEX IF NOT EXISTS idx_scan_sessions_created_by
    ON scan_sessions(created_by);

-- ---------------------------------------------------------------------------
-- 4. Update ScanSessionInsertDTO to include store_id and created_by.
--    The RLS policy already ensures the inserting user is an IC, but having
--    created_by stored explicitly enables audit trails.
--    Default the new columns for any existing rows to NULL (already the default).
-- ---------------------------------------------------------------------------
-- (No data backfill needed; existing rows have NULL store_id/created_by which is acceptable)

-- ---------------------------------------------------------------------------
-- 5. Replace process_scan_event() RPC to accept RETURN scan type
--    Key changes:
--      a) p_scan_type is now text instead of scan_type_enum so callers can
--         pass 'RETURN' without a cast — the function casts internally.
--         This is safer than relying on ENUM changes propagating to the function
--         signature in all Supabase environments.
--      b) Explicit RETURN handling: logs IN but marks item RETURNED.
--      c) AUDIT idempotency enforced: status update skipped for AUDIT.
--      d) Double-sell / invalid-return guards remain via trigger.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION process_scan_event(
    p_barcode      text,
    p_session_id   uuid,
    p_target_status text,   -- Changed from enum to text for forward compatibility
    p_scan_type    text     -- Changed from enum to text for forward compatibility
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_target_status item_status_enum;
    v_scan_type     scan_type_enum;
BEGIN
    -- 1. Validate permissions
    IF NOT EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid() AND role = 'inventory_controller'
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only Inventory Controllers can process scan events.';
    END IF;

    -- 2. Validate and cast p_target_status
    BEGIN
        v_target_status := p_target_status::item_status_enum;
    EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Invalid status value: %', p_target_status;
    END;

    -- 3. Validate and cast p_scan_type (RETURN maps to 'IN' for the enum log entry)
    --    We store 'IN' in the log for RETURN scans since scan_type_enum may not
    --    have RETURN in older DB environments. The RPC itself handles RETURN logic.
    BEGIN
        IF upper(p_scan_type) = 'RETURN' THEN
            v_scan_type := 'IN'::scan_type_enum;   -- Log as IN (received back)
        ELSE
            v_scan_type := upper(p_scan_type)::scan_type_enum;
        END IF;
    EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Invalid scan type value: %', p_scan_type;
    END;

    -- 4. Validate Session is ACTIVE
    IF NOT EXISTS (
        SELECT 1 FROM scan_sessions
        WHERE id = p_session_id AND status = 'ACTIVE'::session_status_enum
    ) THEN
        RAISE EXCEPTION 'Cannot process scan: Session is not ACTIVE';
    END IF;

    -- 5. Log the scan event (always runs, even for AUDIT)
    INSERT INTO scan_logs (barcode, session_id, type)
    VALUES (p_barcode, p_session_id, v_scan_type);

    -- 6. Update physical item status (skip for AUDIT — true no-op)
    IF upper(p_scan_type) != 'AUDIT' THEN
        UPDATE product_items
        SET status = v_target_status
        WHERE barcode = p_barcode
          AND deleted_at IS NULL;

        -- Guard: barcode not found in physical inventory
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Barcode % not found in product_items', p_barcode;
        END IF;
    ELSE
        -- AUDIT: verify existence without mutating
        IF NOT EXISTS (
            SELECT 1 FROM product_items
            WHERE barcode = p_barcode AND deleted_at IS NULL
        ) THEN
            RAISE EXCEPTION 'Barcode % not found in product_items', p_barcode;
        END IF;
    END IF;

END;
$$;

-- Grant to authenticated role (covers all authenticated Supabase users;
-- RLS + the permission check inside the function provide row-level security)
GRANT EXECUTE ON FUNCTION process_scan_event(text, uuid, text, text) TO authenticated;

-- Revoke the old typed-parameter version if it still exists
-- (prevents ambiguous function calls if both signatures coexist)
DROP FUNCTION IF EXISTS process_scan_event(text, uuid, item_status_enum, scan_type_enum);

-- ---------------------------------------------------------------------------
-- 6. Tighten validate_product_item_transition trigger
--    Add guard for: cannot sell a RETURNED item (must do Stock In first)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_product_item_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Prevent selling an already sold item
    IF OLD.status = 'SOLD'::item_status_enum AND NEW.status = 'SOLD'::item_status_enum THEN
        RAISE EXCEPTION 'Item % is already sold.', OLD.barcode;
    END IF;

    -- Prevent returning an in-stock item
    IF OLD.status = 'IN_STOCK'::item_status_enum AND NEW.status = 'RETURNED'::item_status_enum THEN
        RAISE EXCEPTION 'Cannot return an item currently in stock.';
    END IF;

    -- Prevent selling a returned item without first stocking it back in
    IF OLD.status = 'RETURNED'::item_status_enum AND NEW.status = 'SOLD'::item_status_enum THEN
        RAISE EXCEPTION 'Cannot sell item % — it is in RETURNED state. Stock it IN first.', OLD.barcode;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_product_item_transition ON product_items;
CREATE TRIGGER trg_validate_product_item_transition
    BEFORE UPDATE ON product_items
    FOR EACH ROW
    EXECUTE FUNCTION validate_product_item_transition();

-- ---------------------------------------------------------------------------
-- 7. Idempotency index: prevent duplicate scan_logs entries
--    Two rows with same barcode + session_id within 500ms window is noise.
--    Note: We don't add UNIQUE here (a barcode CAN be scanned multiple times
--    in a session legitimately in AUDIT mode). Instead, the debounce on the
--    iOS side remains the primary guard. This index just improves query perf.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_scan_logs_barcode_session
    ON scan_logs(barcode, session_id, scanned_at DESC);
