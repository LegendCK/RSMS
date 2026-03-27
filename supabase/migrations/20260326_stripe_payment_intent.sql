-- 20260326_stripe_payment_intent.sql
-- Adds stripe_payment_intent_id column to payments table
-- so each payment row can reference its Stripe PaymentIntent.

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT;

-- Optional index for fast lookups by Stripe PI id (e.g. webhooks)
CREATE INDEX IF NOT EXISTS idx_payments_stripe_pi
  ON payments (stripe_payment_intent_id)
  WHERE stripe_payment_intent_id IS NOT NULL;

COMMENT ON COLUMN payments.stripe_payment_intent_id
  IS 'Stripe PaymentIntent ID (pi_...) — set when payment is processed via Stripe gateway';
