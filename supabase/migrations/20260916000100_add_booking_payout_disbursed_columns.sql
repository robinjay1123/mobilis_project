-- Add payout disbursement tracking columns to bookings table
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS partner_payout_disbursed BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS partner_payout_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS partner_payout_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS partner_payout_commission NUMERIC,
  ADD COLUMN IF NOT EXISTS partner_payout_deposit_deduction NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS partner_security_deposit_deduction NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS partner_payout_method TEXT,
  ADD COLUMN IF NOT EXISTS partner_payout_ref TEXT,
  ADD COLUMN IF NOT EXISTS partner_payout_receipt_url TEXT,
  ADD COLUMN IF NOT EXISTS partner_payout_disbursed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS partner_payout_disbursed_by UUID REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS driver_payout_disbursed BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS driver_payout_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS driver_payout_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS driver_payout_commission NUMERIC,
  ADD COLUMN IF NOT EXISTS driver_payout_method TEXT,
  ADD COLUMN IF NOT EXISTS driver_payout_ref TEXT,
  ADD COLUMN IF NOT EXISTS driver_payout_receipt_url TEXT,
  ADD COLUMN IF NOT EXISTS driver_payout_disbursed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS driver_payout_disbursed_by UUID REFERENCES public.users(id);

CREATE INDEX IF NOT EXISTS idx_bookings_partner_payout_disbursed ON public.bookings(partner_payout_disbursed);
CREATE INDEX IF NOT EXISTS idx_bookings_driver_payout_disbursed ON public.bookings(driver_payout_disbursed);
