-- =============================================================================
-- Fix RPC Enum Casting
-- =============================================================================

-- Drop the old function signature first in case we are altering parameter types
DROP FUNCTION IF EXISTS process_scan_event(text, uuid, item_status_enum, scan_type_enum);
DROP FUNCTION IF EXISTS process_scan_event(text, uuid, text, text);

CREATE OR REPLACE FUNCTION process_scan_event(
    p_barcode text,
    p_session_id uuid,
    p_target_status text,
    p_scan_type text
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
    -- Explicitly cast status to avoid text = session_status_enum error
    IF NOT EXISTS (
        SELECT 1 FROM scan_sessions 
        WHERE id = p_session_id 
        AND status = 'ACTIVE'::session_status_enum
    ) THEN
        RAISE EXCEPTION 'Cannot process scan: Session is not ACTIVE';
    END IF;

    -- 3. Log the scan event (Always executes even on AUDIT)
    INSERT INTO scan_logs (barcode, session_id, type)
    VALUES (p_barcode, p_session_id, p_scan_type::scan_type_enum);

    -- 4. Update the physical item status (Only if NOT auditing)
    IF p_scan_type::scan_type_enum != 'AUDIT'::scan_type_enum THEN
        UPDATE product_items 
        SET status = p_target_status::item_status_enum 
        WHERE barcode = p_barcode
        AND deleted_at IS NULL;

        -- 5. Exception if barcode not found in physical inventory (or is soft-deleted)
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Barcode % not found in product_items', p_barcode;
        END IF;
    ELSE
        -- Verify existence for AUDIT scans without mutating
        IF NOT EXISTS (
            SELECT 1 FROM product_items 
            WHERE barcode = p_barcode 
            AND deleted_at IS NULL
        ) THEN
            RAISE EXCEPTION 'Barcode % not found in product_items', p_barcode;
        END IF;
    END IF;
    
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION process_scan_event(text, uuid, text, text) TO authenticated;
