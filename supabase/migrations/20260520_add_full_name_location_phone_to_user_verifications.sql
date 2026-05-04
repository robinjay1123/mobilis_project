-- Persist the submitted verification details on the verification record itself.

ALTER TABLE public.user_verifications
  ADD COLUMN IF NOT EXISTS full_name TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT;