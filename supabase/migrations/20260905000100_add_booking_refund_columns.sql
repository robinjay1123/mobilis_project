-- Migration: Add booking refund tracking columns to public.bookings
-- This ensures operator/partner refund records and disbursements are safely stored.

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS refund_status TEXT,
  ADD COLUMN IF NOT EXISTS refund_amount NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS refund_completed BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS refund_ref TEXT,
  ADD COLUMN IF NOT EXISTS refund_reference TEXT,
  ADD COLUMN IF NOT EXISTS refund_notes TEXT,
  ADD COLUMN IF NOT EXISTS refund_method TEXT,
  ADD COLUMN IF NOT EXISTS refund_receipt_url TEXT,
  ADD COLUMN IF NOT EXISTS refund_reason TEXT,
  ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS refunded_by UUID,
  ADD COLUMN IF NOT EXISTS refund_operator_id UUID,
  ADD COLUMN IF NOT EXISTS refund_processed_at TIMESTAMPTZ;

-- Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
