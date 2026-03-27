-- 20260327_update_process_scan_logic.sql
-- Overrides the RPC to completely decouple and inject specific RETURN/IN/OUT transition states
-- based on explicit business rules (bypassing any global blocks).

CREATE OR REPLACE FUNCTION process_scan_event(
    p_barcode      text,
    p_session_id   uuid,
    p_scan_type    text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_scan_type      scan_type_enum;
    v_item_id        uuid;
    v_current_status item_status_enum;
BEGIN
    -- 1. Validate permissions
    IF NOT EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid() AND role = 'inventory_controller'
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only Inventory Controllers can process scan events.';
    END IF;

    -- 2. Validate and cast scan type
    BEGIN
        v_scan_type := upper(p_scan_type)::scan_type_enum;
    EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Invalid scan type value: %', p_scan_type;
    END;

    -- 3. Validate Session is ACTIVE
    IF NOT EXISTS (
        SELECT 1 FROM scan_sessions
        WHERE id = p_session_id AND status = 'ACTIVE'::session_status_enum
    ) THEN
        RAISE EXCEPTION 'Cannot process scan: Session is not ACTIVE';
    END IF;

    -- 4. Get current item status
    SELECT id, status INTO v_item_id, v_current_status
    FROM product_items
    WHERE barcode = p_barcode AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Barcode % not found in product_items', p_barcode;
    END IF;

    -- 5. Apply business logic
    IF upper(p_scan_type) = 'RETURN' THEN
        IF v_current_status = 'SOLD' THEN
            UPDATE product_items
            SET status = 'IN_STOCK'::item_status_enum,
                updated_at = NOW()
            WHERE id = v_item_id;
        ELSIF v_current_status = 'IN_STOCK' THEN
            RAISE EXCEPTION 'Item already in stock — no return needed';
        ELSE
            RAISE EXCEPTION 'Invalid return state';
        END IF;

    ELSIF upper(p_scan_type) = 'IN' THEN
        IF v_current_status = 'IN_STOCK' THEN
            RAISE EXCEPTION 'Already in stock';
        ELSE
            UPDATE product_items
            SET status = 'IN_STOCK'::item_status_enum,
                updated_at = NOW()
            WHERE id = v_item_id;
        END IF;

    ELSIF upper(p_scan_type) = 'OUT' THEN
        IF v_current_status = 'SOLD' THEN
            RAISE EXCEPTION 'Already sold';
        ELSE
            UPDATE product_items
            SET status = 'SOLD'::item_status_enum,
                updated_at = NOW()
            WHERE id = v_item_id;
        END IF;

    ELSIF upper(p_scan_type) = 'AUDIT' THEN
        -- No-op for AUDIT
    END IF;

    -- 6. Log the scan event (Only on success/valid state)
    INSERT INTO scan_logs (barcode, session_id, type)
    VALUES (p_barcode, p_session_id, v_scan_type);

END;
$$;
