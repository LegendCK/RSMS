-- =============================================================================
-- Secure Authentication Flow: must_reset_password + dual email for staff
-- =============================================================================

-- Staff: forced password reset flag + corporate/personal email split
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS must_reset_password BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS corporate_email TEXT,
  ADD COLUMN IF NOT EXISTS personal_email TEXT;

-- Clients: forced password reset flag only (no dual email needed)
ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS must_reset_password BOOLEAN NOT NULL DEFAULT false;

-- Backfill: copy existing email into corporate_email for all staff
-- (so existing staff accounts have corporate_email populated)
UPDATE public.users
SET corporate_email = email
WHERE corporate_email IS NULL;

COMMENT ON COLUMN public.users.must_reset_password IS 'When true, user must change password on next login';
COMMENT ON COLUMN public.users.corporate_email IS 'Corporate identity email used for login (e.g. sales1.mumbai@maisonluxe.me)';
COMMENT ON COLUMN public.users.personal_email IS 'Real email where auth notifications are forwarded (e.g. user@gmail.com)';
COMMENT ON COLUMN public.clients.must_reset_password IS 'When true, client must change password on next login';
