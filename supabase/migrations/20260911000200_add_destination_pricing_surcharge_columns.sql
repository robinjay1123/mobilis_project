-- Migration: Add daily destination surcharge and total destination fee columns to public.bookings

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS daily_destination_surcharge NUMERIC(10,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS destination_fee NUMERIC(10,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS destination_fee_notes TEXT;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
