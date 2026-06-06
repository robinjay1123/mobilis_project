-- Repair databases that created user_verifications from the baseline schema.
-- The later CREATE TABLE IF NOT EXISTS migration does not add these columns
-- when the baseline table already exists.

ALTER TABLE public.user_verifications
  ADD COLUMN IF NOT EXISTS id_document_url TEXT,
  ADD COLUMN IF NOT EXISTS full_name TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS id_type TEXT,
  ADD COLUMN IF NOT EXISTS id_number TEXT,
  ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS face_match_percentage NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES public.users(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_verifications'
      AND column_name = 'status'
  ) THEN
    UPDATE public.user_verifications
    SET verification_status = COALESCE(verification_status, status, 'pending')
    WHERE verification_status IS NULL
       OR verification_status = '';
  ELSE
    UPDATE public.user_verifications
    SET verification_status = 'pending'
    WHERE verification_status IS NULL
       OR verification_status = '';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_verifications'
      AND column_name = 'document_url'
  ) THEN
    UPDATE public.user_verifications
    SET id_document_url = COALESCE(id_document_url, document_url)
    WHERE id_document_url IS NULL
      AND document_url IS NOT NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_verifications_user_id_key'
      AND conrelid = 'public.user_verifications'::regclass
  ) THEN
    ALTER TABLE public.user_verifications
      ADD CONSTRAINT user_verifications_user_id_key UNIQUE (user_id);
  END IF;
END $$;

ALTER TABLE public.user_verifications
  ALTER COLUMN verification_status SET DEFAULT 'pending';

CREATE INDEX IF NOT EXISTS idx_user_verifications_status
  ON public.user_verifications(verification_status);

CREATE INDEX IF NOT EXISTS idx_user_verifications_created_at
  ON public.user_verifications(created_at DESC);

NOTIFY pgrst, 'reload schema';
