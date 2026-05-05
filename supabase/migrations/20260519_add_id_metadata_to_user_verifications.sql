-- Store ID metadata so admin review cards can show the submitted ID type and number.

ALTER TABLE public.user_verifications
  ADD COLUMN IF NOT EXISTS id_type TEXT,
  ADD COLUMN IF NOT EXISTS id_number TEXT;