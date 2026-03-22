-- Backfill customer ownership on historical service tickets
-- so My Exchange Requests can read them under RLS:
--   allow_customers_select_own USING (client_id = auth.uid())

UPDATE public.service_tickets st
SET client_id = o.client_id
FROM public.orders o
WHERE st.client_id IS NULL
  AND st.order_id = o.id
  AND o.client_id IS NOT NULL;

