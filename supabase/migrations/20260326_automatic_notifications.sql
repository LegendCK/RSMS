-- =============================================================================
-- Migration: 20260326_automatic_notifications
-- Automatically generate client notifications on order and ticket status changes.
-- =============================================================================

-- ── 1. Orders Trigger ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trg_notify_order_status()
RETURNS TRIGGER AS $$
DECLARE
    v_title TEXT;
    v_message TEXT;
    v_order_num TEXT;
BEGIN
    v_order_num := COALESCE(NEW.order_number, substr(NEW.id::text, 1, 8));

    IF (TG_OP = 'INSERT') THEN
        IF NEW.status IN ('pending', 'confirmed') THEN
            v_title := 'Order Received';
            v_message := 'We have received your order (#' || v_order_num || ').';
        END IF;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            v_title := 'Order Update';
            v_message := 'Your order (#' || v_order_num || ') status is now: ' || INITCAP(REPLACE(NEW.status, '_', ' '));
        END IF;
    END IF;

    IF v_title IS NOT NULL AND NEW.client_id IS NOT NULL THEN
        INSERT INTO public.notifications (recipient_client_id, store_id, title, message, category, deep_link)
        VALUES (NEW.client_id, NEW.store_id, v_title, v_message, 'orders', 'rsms://orders/' || NEW.id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_order_status_change ON public.orders;
CREATE TRIGGER on_order_status_change
    AFTER INSERT OR UPDATE OF status ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_notify_order_status();


-- ── 2. Service Tickets Trigger ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trg_notify_ticket_status()
RETURNS TRIGGER AS $$
DECLARE
    v_title TEXT;
    v_message TEXT;
    v_ticket_num TEXT;
BEGIN
    v_ticket_num := COALESCE(NEW.ticket_number, 'TKT-' || UPPER(substr(NEW.id::text, 1, 8)));

    IF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
        IF NEW.status = 'estimate_approved' THEN
            v_title := 'Estimate Approved';
            v_message := 'Your repair estimate for ticket ' || v_ticket_num || ' has been approved.';
        ELSIF NEW.status IN ('in_progress', 'completed', 'cancelled') THEN
            v_title := 'Repair Update';
            v_message := 'Repair ticket ' || v_ticket_num || ' status is now: ' || INITCAP(REPLACE(NEW.status, '_', ' '));
        ELSE
            v_title := 'Service Update';
            v_message := 'Service ticket ' || v_ticket_num || ' status changed to: ' || INITCAP(REPLACE(NEW.status, '_', ' '));
        END IF;

        IF NEW.client_id IS NOT NULL THEN
            INSERT INTO public.notifications (recipient_client_id, store_id, title, message, category, deep_link)
            VALUES (NEW.client_id, NEW.store_id, v_title, v_message, 'repairs', 'rsms://repairs/' || NEW.id);
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_ticket_status_change ON public.service_tickets;
CREATE TRIGGER on_ticket_status_change
    AFTER UPDATE OF status ON public.service_tickets
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_notify_ticket_status();
