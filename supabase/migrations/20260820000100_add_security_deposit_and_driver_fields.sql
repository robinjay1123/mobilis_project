-- Migration to add security deposit return eligibility, refund tracking, and driver fee to bookings table
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS security_deposit_return_eligible BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS security_deposit_ineligibility_reason TEXT,
  ADD COLUMN IF NOT EXISTS security_deposit_refunded BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS security_deposit_refund_amount NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS security_deposit_refund_deduction NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS security_deposit_refund_notes TEXT,
  ADD COLUMN IF NOT EXISTS security_deposit_refund_method TEXT,
  ADD COLUMN IF NOT EXISTS security_deposit_refund_ref TEXT,
  ADD COLUMN IF NOT EXISTS security_deposit_refund_receipt_url TEXT,
  ADD COLUMN IF NOT EXISTS security_deposit_refunded_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS security_deposit_refunded_by UUID,
  ADD COLUMN IF NOT EXISTS driver_fee NUMERIC DEFAULT 0;
