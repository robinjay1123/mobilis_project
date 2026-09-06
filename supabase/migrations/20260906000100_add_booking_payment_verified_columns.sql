-- Migration: Add payment verification audit columns to public.bookings

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS payment_verified BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS payment_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_verified_by UUID,
  ADD COLUMN IF NOT EXISTS payment_verification_notes TEXT;

-- Mark existing verified bookings
UPDATE public.bookings
SET payment_verified = TRUE
WHERE lower(coalesce(reservation_payment_status, '')) IN ('verified', 'paid')
  AND (payment_verified IS NULL OR payment_verified = FALSE);

CREATE INDEX IF NOT EXISTS idx_bookings_payment_verified ON public.bookings(payment_verified);

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
