-- Migration: Add booking reschedule tracking, deposit forfeiture flag, desk payment support, and refund_phone compatibility
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS rescheduled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reschedule_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS original_start_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS original_end_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reschedule_reason TEXT,
  ADD COLUMN IF NOT EXISTS deposit_forfeited BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS cancellation_fee_retained NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS refund_phone TEXT;
