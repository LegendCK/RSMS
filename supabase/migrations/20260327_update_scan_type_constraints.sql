-- 20260327_update_scan_type_constraints.sql
-- Safely drop existing enum checks for IN/OUT/AUDIT and recreate them to include RETURN

-- 1. SCAN SESSIONS
DO $$
DECLARE
    v_name text;
BEGIN
    SELECT conname INTO v_name
    FROM pg_constraint
    WHERE conrelid = 'scan_sessions'::regclass
      AND contype = 'c';

    IF v_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE scan_sessions DROP CONSTRAINT %I', v_name);
    END IF;
END $$;

ALTER TABLE scan_sessions
ADD CONSTRAINT scan_sessions_type_check
CHECK (type IN ('IN','OUT','AUDIT','RETURN'));

-- 2. SCAN LOGS
DO $$
DECLARE
    v_name text;
BEGIN
    SELECT conname INTO v_name
    FROM pg_constraint
    WHERE conrelid = 'scan_logs'::regclass
      AND contype = 'c';

    IF v_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE scan_logs DROP CONSTRAINT %I', v_name);
    END IF;
END $$;

ALTER TABLE scan_logs
ADD CONSTRAINT scan_logs_type_check
CHECK (type IN ('IN','OUT','AUDIT','RETURN'));
