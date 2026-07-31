-- Migration to support Trip Extension and Vehicle Return workflows
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS returned_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS return_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS return_confirmed_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS extension_requested_end_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS extension_status TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS extension_days INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS extension_additional_price NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS extension_requested_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS extension_approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS extension_rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS principal_total_price NUMERIC;

-- Backfill principal_total_price for existing rows
UPDATE public.bookings
SET principal_total_price = total_price
WHERE principal_total_price IS NULL AND total_price IS NOT NULL;
