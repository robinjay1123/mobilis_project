-- Migration: Add security deposit workflow and conditional partner deduction tracking columns to public.bookings
-- NOTE: Do NOT push immediately if database is undergoing maintenance.

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS security_deposit_status TEXT DEFAULT 'deposit_held',
  ADD COLUMN IF NOT EXISTS security_deposit_operator_reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS security_deposit_operator_reviewed_by UUID,
  ADD COLUMN IF NOT EXISTS partner_security_deposit_deduction NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS partner_payout_deposit_deduction NUMERIC DEFAULT 0;

-- Optional index to speed up filtering bookings by security deposit status
CREATE INDEX IF NOT EXISTS idx_bookings_security_deposit_status ON public.bookings(security_deposit_status);

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
