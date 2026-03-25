-- =============================================================================
-- Migration: 20260326_warranty_lookup_rpcs
-- 2026-03-26
--
-- Creates SECURITY DEFINER read-only RPCs for warranty status lookup.
--
-- WHY: The order_items SELECT policy is store-scoped. This means:
--   • A customer can only see their own order items (client_id = auth.uid()).
--   • A staff member can only see order items for their own store.
--   • Cross-store warranty lookups (e.g. SA after-sales on a product sold at
--     another boutique) silently return 0 rows → "Not Found".
--
-- FIX: Two SECURITY DEFINER RPCs run as `postgres` (bypassing RLS) but
-- verify the caller is authenticated via auth.uid() before executing.
-- They are read-only (SELECT only) and return only the data needed for
-- WarrantyLookupResult on the iOS client.
--
-- RPCs:
--   1. lookup_warranty_by_product(p_product_id uuid)
--      → find latest purchase of this product across all stores/orders
--   2. lookup_warranty_by_order(p_order_number text)
--      → find order by number, return first item + product + warranty policy
-- =============================================================================

-- ── 1. lookup_warranty_by_product ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.lookup_warranty_by_product(
    p_product_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_result json;
BEGIN
    -- Require authentication
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT json_build_object(
        'product_id',        oi.product_id,
        'product_name',      p.name,
        'brand',             p.brand,
        'order_id',          o.id,
        'order_number',      o.order_number,
        'client_id',         o.client_id,
        'store_id',          o.store_id,
        'purchased_at',      o.created_at,
        'coverage_months',   COALESCE(wp.coverage_months, NULL),
        'eligible_services', COALESCE(wp.eligible_services, '{}')
    )
    INTO v_result
    FROM public.order_items oi
    JOIN public.orders      o  ON o.id = oi.order_id
    JOIN public.products    p  ON p.id = oi.product_id
    LEFT JOIN public.product_warranty_policies wp ON wp.product_id = oi.product_id
    WHERE oi.product_id = p_product_id
    ORDER BY o.created_at DESC
    LIMIT 1;

    RETURN v_result; -- NULL if no purchase record exists
END;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_warranty_by_product(uuid)
    TO authenticated;

REVOKE EXECUTE ON FUNCTION public.lookup_warranty_by_product(uuid)
    FROM public;

COMMENT ON FUNCTION public.lookup_warranty_by_product IS
    'SECURITY DEFINER: bypasses store-scoped RLS on order_items to find the '
    'most recent purchase of a product for warranty lookup. Requires authentication.';


-- ── 2. lookup_warranty_by_order ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.lookup_warranty_by_order(
    p_order_number text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid    uuid := auth.uid();
    v_result json;
BEGIN
    -- Require authentication
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Find the first order item for the given order number, joined with product
    -- and warranty policy.
    SELECT json_build_object(
        'product_id',        oi.product_id,
        'product_name',      p.name,
        'brand',             p.brand,
        'order_id',          o.id,
        'order_number',      o.order_number,
        'client_id',         o.client_id,
        'store_id',          o.store_id,
        'purchased_at',      o.created_at,
        'coverage_months',   COALESCE(wp.coverage_months, NULL),
        'eligible_services', COALESCE(wp.eligible_services, '{}')
    )
    INTO v_result
    FROM public.orders      o
    JOIN public.order_items oi ON oi.order_id = o.id
    JOIN public.products    p  ON p.id = oi.product_id
    LEFT JOIN public.product_warranty_policies wp ON wp.product_id = oi.product_id
    WHERE o.order_number = p_order_number
    ORDER BY oi.created_at DESC
    LIMIT 1;

    RETURN v_result; -- NULL if order not found or has no items
END;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_warranty_by_order(text)
    TO authenticated;

REVOKE EXECUTE ON FUNCTION public.lookup_warranty_by_order(text)
    FROM public;

COMMENT ON FUNCTION public.lookup_warranty_by_order IS
    'SECURITY DEFINER: bypasses store-scoped RLS on order_items to look up '
    'warranty info by order number. Requires authentication.';
