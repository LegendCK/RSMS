-- =============================================================================
-- Migration: 20260326_admin_audit_logs
--
-- Creates the `admin_audit_logs` table to immutably track administrative
-- actions across the system. 
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id   UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    action     TEXT        NOT NULL,
    details    JSONB       NOT NULL DEFAULT '{}'::jsonb,
    ip_address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for descending chronological fetch
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at
    ON public.admin_audit_logs(created_at DESC);

-- Enable RLS
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- 1. Everyone is forbidden from UPDATING or DELETING audit logs to preserve integrity.
-- (Supabase default is deny if no policy exists, but this makes it explicit)

-- 2. Corporate Admins can SELECT (view) the logs
DROP POLICY IF EXISTS "Corporate Admins can view audit logs" ON public.admin_audit_logs;
CREATE POLICY "Corporate Admins can view audit logs"
ON public.admin_audit_logs FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role = 'corporate_admin'
    )
);

-- 3. We do NOT allow direct INSERT policies from the client. 
-- Instead, we use a SECURITY DEFINER RPC to force `auth.uid()` as the `admin_id`.

-- =============================================================================
-- RPC: log_admin_activity
-- 
-- Callable by authenticated users (who must be valid staff/admins in the app).
-- The function securely reads `auth.uid()` and inserts the record.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.log_admin_activity(
    p_action TEXT,
    p_details JSONB DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    INSERT INTO public.admin_audit_logs (admin_id, action, details)
    VALUES (auth.uid(), p_action, p_details);
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_admin_activity(TEXT, JSONB) TO authenticated;
