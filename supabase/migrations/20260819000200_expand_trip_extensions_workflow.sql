-- Migration to expand Trip Extension workflow with payment and destination fields
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS extension_requested_destination TEXT,
  ADD COLUMN IF NOT EXISTS extension_payment_status TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS extension_payment_method TEXT,
  ADD COLUMN IF NOT EXISTS extension_payment_reference TEXT,
  ADD COLUMN IF NOT EXISTS extension_payment_proof_url TEXT,
  ADD COLUMN IF NOT EXISTS extension_payment_submitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS extension_payment_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS extension_payment_verified_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS extension_finalized_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS extension_finalized_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS extension_conversation_id UUID;
