--  ============================================================================
--  RSMS Scan System – Patch Migration
--  Applies on top of 20260317_scan_system.sql
--  ============================================================================
--  Changes:
--    1. Upgrade generate_rsms_barcode() to plpgsql (required by some Supabase versions)
--    2. Add `type` column to scan_logs  (IN / OUT / AUDIT)
--    3. Confirm performance indexes exist (idempotent)
--    4. Add stale-session cleanup function
--  ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Barcode generator — replace sql function with plpgsql for compatibility
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_rsms_barcode()
RETURNS text AS $$
BEGIN
    RETURN 'RSMS-' || upper(substr(md5(gen_random_uuid()::text), 1, 10));
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 2. Add `type` column to scan_logs
--    Tracks whether each log entry was from an IN, OUT, or AUDIT scan.
--    Existing rows default to 'AUDIT' (safest / no-mutation assumption).
-- ----------------------------------------------------------------------------
ALTER TABLE scan_logs
    ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'AUDIT'
    CHECK (type IN ('IN', 'OUT', 'AUDIT'));

-- ----------------------------------------------------------------------------
-- 3. Indexes (idempotent – safe to re-run)
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_product_items_barcode
    ON product_items(barcode);

CREATE INDEX IF NOT EXISTS idx_scan_logs_session_id
    ON scan_logs(session_id);

CREATE INDEX IF NOT EXISTS idx_scan_logs_barcode
    ON scan_logs(barcode);

-- Composite for dashboard queries: "all logs for session ordered by time"
CREATE INDEX IF NOT EXISTS idx_scan_logs_session_time
    ON scan_logs(session_id, scanned_at DESC);

-- ----------------------------------------------------------------------------
-- 4. Stale session cleanup helper
--    Called by the iOS app on launch via RPC to mark orphaned ACTIVE sessions.
--    Uses a 24-hour threshold: any ACTIVE session older than 24 h is expired.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION close_stale_scan_sessions()
RETURNS void AS $$
BEGIN
    UPDATE scan_sessions
    SET
        ended_at = now(),
        status   = 'EXPIRED'
    WHERE
        status   = 'ACTIVE'
        AND started_at < now() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

-- Ensure AUDIT status value exists in the check constraint
ALTER TABLE scan_sessions
    DROP CONSTRAINT IF EXISTS scan_sessions_status_check;

ALTER TABLE scan_sessions
    ADD CONSTRAINT scan_sessions_status_check
    CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED', 'EXPIRED'));
