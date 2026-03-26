-- =============================================================================
-- RSMS — Scanner + Repair Flow: Constraint Expansion Migration
-- Created: 2026-03-26
-- =============================================================================
--
-- Problem:
--   scan_sessions.type     CHECK only allows ('IN','OUT','AUDIT')
--   product_items.status   CHECK only allows ('IN_STOCK','SOLD','RESERVED','DAMAGED')
--
--   Starting a RETURN scan session fails with:
--     "new row violates check constraint scan_sessions"
--
--   Setting product status to RETURNED fails because RETURNED is not in the
--   product_items.status constraint.
--
-- Fix:
--   Expand both constraints to include the new valid values.
--   All existing data is unaffected — no rows use the new values yet.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. scan_sessions.type — add 'RETURN'
--
--    Old: ('IN','OUT','AUDIT')
--    New: ('IN','OUT','AUDIT','RETURN')
-- ---------------------------------------------------------------------------

-- Step 1a: Find and drop the old constraint
-- (name may vary across environments; use pg_constraint for safety)
DO $$
DECLARE
    v_constraint_name text;
BEGIN
    SELECT conname
    INTO   v_constraint_name
    FROM   pg_constraint
    WHERE  conrelid = 'scan_sessions'::regclass
      AND  contype  = 'c'
      AND  pg_get_constraintdef(oid) LIKE '%type in%';

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE scan_sessions DROP CONSTRAINT %I', v_constraint_name);
        RAISE NOTICE 'Dropped constraint: %', v_constraint_name;
    ELSE
        RAISE NOTICE 'No existing type constraint found on scan_sessions — skipping drop.';
    END IF;
END $$;

-- Step 1b: Add the expanded constraint
ALTER TABLE scan_sessions
    ADD CONSTRAINT scan_sessions_type_check
    CHECK (type IN ('IN', 'OUT', 'AUDIT', 'RETURN'));

-- ---------------------------------------------------------------------------
-- 2. product_items.status — add 'RETURNED'
--
--    Old: ('IN_STOCK','SOLD','RESERVED','DAMAGED')
--    New: ('IN_STOCK','SOLD','RESERVED','DAMAGED','RETURNED')
-- ---------------------------------------------------------------------------

-- Step 2a: Drop the old status constraint
DO $$
DECLARE
    v_constraint_name text;
BEGIN
    SELECT conname
    INTO   v_constraint_name
    FROM   pg_constraint
    WHERE  conrelid = 'product_items'::regclass
      AND  contype  = 'c'
      AND  pg_get_constraintdef(oid) LIKE '%status in%';

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE product_items DROP CONSTRAINT %I', v_constraint_name);
        RAISE NOTICE 'Dropped constraint: %', v_constraint_name;
    ELSE
        RAISE NOTICE 'No existing status constraint found on product_items — skipping drop.';
    END IF;
END $$;

-- Step 2b: Add the expanded constraint
ALTER TABLE product_items
    ADD CONSTRAINT product_items_status_check
    CHECK (status IN ('IN_STOCK', 'SOLD', 'RESERVED', 'DAMAGED', 'RETURNED'));

-- ---------------------------------------------------------------------------
-- 3. scan_logs.type — add 'RETURN'
--
--    The scan_logs table has a separate type CHECK added in 20260317_scan_system_patch.sql
--    Old: ('IN','OUT','AUDIT')
--    New: ('IN','OUT','AUDIT','RETURN')
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    v_constraint_name text;
BEGIN
    SELECT conname
    INTO   v_constraint_name
    FROM   pg_constraint
    WHERE  conrelid = 'scan_logs'::regclass
      AND  contype  = 'c'
      AND  pg_get_constraintdef(oid) LIKE '%type in%';

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE scan_logs DROP CONSTRAINT %I', v_constraint_name);
        RAISE NOTICE 'Dropped scan_logs type constraint: %', v_constraint_name;
    ELSE
        RAISE NOTICE 'No existing type constraint found on scan_logs — skipping drop.';
    END IF;
END $$;

ALTER TABLE scan_logs
    ADD CONSTRAINT scan_logs_type_check
    CHECK (type IN ('IN', 'OUT', 'AUDIT', 'RETURN'));

-- Also update the DEFAULT for existing/future rows if needed
ALTER TABLE scan_logs
    ALTER COLUMN type SET DEFAULT 'AUDIT';

-- ---------------------------------------------------------------------------
-- 4. Verify (informational — runs at migration time)
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    r record;
BEGIN
    SELECT pg_get_constraintdef(oid) AS def
    INTO   r
    FROM   pg_constraint
    WHERE  conrelid = 'scan_sessions'::regclass
      AND  conname  = 'scan_sessions_type_check';
    RAISE NOTICE 'scan_sessions.type constraint: %', r.def;

    SELECT pg_get_constraintdef(oid) AS def
    INTO   r
    FROM   pg_constraint
    WHERE  conrelid = 'product_items'::regclass
      AND  conname  = 'product_items_status_check';
    RAISE NOTICE 'product_items.status constraint: %', r.def;

    SELECT pg_get_constraintdef(oid) AS def
    INTO   r
    FROM   pg_constraint
    WHERE  conrelid = 'scan_logs'::regclass
      AND  conname  = 'scan_logs_type_check';
    RAISE NOTICE 'scan_logs.type constraint: %', r.def;
END $$;

