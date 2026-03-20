-- =============================================================================
-- RSMS Stock Creation Function (Production-Ready v2)
-- Upgrades create_product_items_bulk to plpgsql with input validation.
-- =============================================================================

CREATE OR REPLACE FUNCTION create_product_items_bulk(
    p_product_id uuid,
    p_quantity    int
)
RETURNS SETOF product_items
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Quantity validation
    IF p_quantity < 1 OR p_quantity > 500 THEN
        RAISE EXCEPTION 'Quantity must be between 1 and 500';
    END IF;

    -- 2. Product existence check
    IF NOT EXISTS (SELECT 1 FROM products WHERE id = p_product_id) THEN
        RAISE EXCEPTION 'Invalid product_id';
    END IF;

    -- 3. Bulk insert with retry logic for unique barcodes
    FOR i IN 1..p_quantity LOOP
        FOR attempt IN 1..5 LOOP
            BEGIN
                RETURN QUERY
                INSERT INTO product_items (product_id, barcode, status)
                VALUES (p_product_id, generate_rsms_barcode(), 'IN_STOCK')
                RETURNING *;
                
                EXIT; -- Success, break out of attempt loop and move to next item
            EXCEPTION WHEN unique_violation THEN
                IF attempt = 5 THEN
                    RAISE EXCEPTION 'Barcode collision: failed to generate unique barcode after 5 attempts';
                END IF;
                -- Otherwise, loop naturally retries
            END;
        END LOOP;
    END LOOP;
END;
$$;

-- Grant execute to authenticated users (aligns with existing RLS)
GRANT EXECUTE ON FUNCTION create_product_items_bulk(uuid, int) TO authenticated;
