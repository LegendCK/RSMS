-- =============================================================================
-- Migration: 20260324_notifications_and_invitations
-- 2026-03-24
--
-- Creates:
--   1. public.notifications         — in-app notification bell rows per client
--   2. public.event_invitations     — tracks which clients were invited to events
--   3. boutique_events.invited_segment column (gold | vip)
-- =============================================================================


-- ── 1. notifications ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.notifications (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_client_id UUID        NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    store_id            UUID        REFERENCES public.stores(id) ON DELETE SET NULL,
    title               TEXT        NOT NULL,
    message             TEXT        NOT NULL,
    category            TEXT        NOT NULL DEFAULT 'system',
    is_read             BOOLEAN     NOT NULL DEFAULT false,
    deep_link           TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient
    ON public.notifications(recipient_client_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_unread
    ON public.notifications(recipient_client_id)
    WHERE is_read = false;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Clients read & mark their own notifications
DROP POLICY IF EXISTS "Clients read own notifications"   ON public.notifications;
DROP POLICY IF EXISTS "Clients update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Staff insert notifications"       ON public.notifications;

CREATE POLICY "Clients read own notifications"
ON public.notifications FOR SELECT TO authenticated
USING (recipient_client_id = auth.uid());

CREATE POLICY "Clients update own notifications"
ON public.notifications FOR UPDATE TO authenticated
USING   (recipient_client_id = auth.uid())
WITH CHECK (recipient_client_id = auth.uid());

-- Store staff can send notifications (INSERT only)
CREATE POLICY "Staff insert notifications"
ON public.notifications FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role IN (
              'boutique_manager','corporate_admin','sales_associate',
              'inventory_controller','service_technician','aftersales_specialist'
          )
    )
);

-- Enable Realtime so the iOS app receives new rows instantly
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;


-- ── 2. event_invitations ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.event_invitations (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id   UUID        NOT NULL REFERENCES public.boutique_events(id) ON DELETE CASCADE,
    client_id  UUID        NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    status     TEXT        NOT NULL DEFAULT 'sent'
                           CHECK (status IN ('pending','sent','rsvp_yes','rsvp_no')),
    invited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    rsvp_at    TIMESTAMPTZ,
    UNIQUE (event_id, client_id)
);

CREATE INDEX IF NOT EXISTS idx_event_invitations_event
    ON public.event_invitations(event_id);

CREATE INDEX IF NOT EXISTS idx_event_invitations_client
    ON public.event_invitations(client_id);

ALTER TABLE public.event_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Managers read event invitations"   ON public.event_invitations;
DROP POLICY IF EXISTS "Managers insert event invitations" ON public.event_invitations;
DROP POLICY IF EXISTS "Clients read own invitations"      ON public.event_invitations;
DROP POLICY IF EXISTS "Clients update own RSVP"           ON public.event_invitations;

-- Managers can read invitations for their store's events
CREATE POLICY "Managers read event invitations"
ON public.event_invitations FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.boutique_events e
        JOIN public.users u ON u.id = auth.uid()
        WHERE e.id = event_invitations.event_id
          AND (
              u.role = 'corporate_admin'
              OR (u.role = 'boutique_manager' AND u.store_id = e.store_id)
          )
    )
);

-- Managers can send invitations for their store's events
CREATE POLICY "Managers insert event invitations"
ON public.event_invitations FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.boutique_events e
        JOIN public.users u ON u.id = auth.uid()
        WHERE e.id = event_invitations.event_id
          AND (
              u.role = 'corporate_admin'
              OR (u.role = 'boutique_manager' AND u.store_id = e.store_id)
          )
    )
);

-- Clients read their own invitations
CREATE POLICY "Clients read own invitations"
ON public.event_invitations FOR SELECT TO authenticated
USING (client_id = auth.uid());

-- Clients update only their own RSVP status
CREATE POLICY "Clients update own RSVP"
ON public.event_invitations FOR UPDATE TO authenticated
USING   (client_id = auth.uid())
WITH CHECK (client_id = auth.uid());


-- ── 3. boutique_events — add invited_segment column ───────────────────────────

ALTER TABLE public.boutique_events
    ADD COLUMN IF NOT EXISTS invited_segment TEXT
        CHECK (invited_segment IN ('gold', 'vip'));

-- ── 4. Helper RPC: get RSVP counts for an event ───────────────────────────────
-- Returns (rsvp_yes, rsvp_no, pending) counts in one round-trip.

CREATE OR REPLACE FUNCTION public.get_event_rsvp_counts(p_event_id UUID)
RETURNS TABLE (rsvp_yes INT, rsvp_no INT, pending INT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        COUNT(*) FILTER (WHERE status = 'rsvp_yes')::INT AS rsvp_yes,
        COUNT(*) FILTER (WHERE status = 'rsvp_no')::INT  AS rsvp_no,
        COUNT(*) FILTER (WHERE status IN ('pending','sent'))::INT AS pending
    FROM public.event_invitations
    WHERE event_id = p_event_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_event_rsvp_counts(UUID) TO authenticated;
