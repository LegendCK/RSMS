-- =============================================================================
-- Migration: fix_orders_status_constraint
-- Expands the orders_status_check constraint to include all statuses used
-- by the RSMS fulfillment flow.
--
-- The original constraint only allowed: pending, confirmed, processing,
-- shipped, delivered, completed, cancelled
-- Missing: ready_for_pickup, new, canceled (alternate spelling)
-- =============================================================================

-- Drop the existing constraint
ALTER TABLE public.orders
    DROP CONSTRAINT IF EXISTS orders_status_check;

-- Re-add it with the full set of valid statuses
ALTER TABLE public.orders
    ADD CONSTRAINT orders_status_check
    CHECK (status IN (
        'pending',
        'new',
        'confirmed',
        'processing',
        'ready_for_pickup',
        'shipped',
        'delivered',
        'completed',
        'cancelled',
        'canceled'
    ));
