-- Migration: Add booking reschedule tracking, deposit forfeiture flag, desk payment support, and payment sender phone
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS rescheduled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reschedule_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS original_start_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS original_end_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reschedule_reason TEXT,
  ADD COLUMN IF NOT EXISTS deposit_forfeited BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS cancellation_fee_retained NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS refund_phone TEXT,
  ADD COLUMN IF NOT EXISTS reservation_payment_sender_phone TEXT,
  ADD COLUMN IF NOT EXISTS reservation_payment_type TEXT,
  ADD COLUMN IF NOT EXISTS reservation_payment_covers_total BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS reservation_payment_reference TEXT,
  ADD COLUMN IF NOT EXISTS reservation_payment_proof_url TEXT,
  ADD COLUMN IF NOT EXISTS reservation_payment_method TEXT,
  ADD COLUMN IF NOT EXISTS reservation_payment_status TEXT,
  ADD COLUMN IF NOT EXISTS reservation_payment_submitted_at TIMESTAMPTZ;
