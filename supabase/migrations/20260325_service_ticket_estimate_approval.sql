-- Migration: Service ticket estimate approval workflow
-- Adds estimate breakdown + client approval tracking fields used by After-Sales specialists.

ALTER TABLE public.service_tickets
    ADD COLUMN IF NOT EXISTS estimate_breakdown JSONB,
    ADD COLUMN IF NOT EXISTS estimate_subtotal NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS estimate_tax NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS estimate_total NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS estimate_sent_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS client_approval_status TEXT,
    ADD COLUMN IF NOT EXISTS client_approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS client_rejected_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS approved_estimate_snapshot JSONB;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'service_tickets_client_approval_status_chk'
    ) THEN
        ALTER TABLE public.service_tickets
            ADD CONSTRAINT service_tickets_client_approval_status_chk
            CHECK (
                client_approval_status IS NULL
                OR client_approval_status IN ('pending', 'approved', 'rejected')
            );
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_service_tickets_client_approval_status
ON public.service_tickets (client_approval_status)
WHERE client_approval_status IS NOT NULL;
