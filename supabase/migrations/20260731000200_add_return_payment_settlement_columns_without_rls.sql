-- Migration to add return payment settlement columns to bookings table
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS final_payment_method TEXT,
  ADD COLUMN IF NOT EXISTS final_payment_reference TEXT,
  ADD COLUMN IF NOT EXISTS final_payment_proof_url TEXT,
  ADD COLUMN IF NOT EXISTS renter_return_payment_submitted BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS renter_return_payment_amount NUMERIC DEFAULT 0;
