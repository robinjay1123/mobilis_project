-- ============================================================================
-- Migration: 20260923000500_shrink_user_verifications_bridge.sql
-- Description: Zero-downtime bridge migration for public.user_verifications.
-- Normalizes user_verifications schema to 14 canonical columns while providing
-- bidirectional compatibility triggers for legacy pipe-separated id_document_url,
-- phone/location auto-sync from users, and driver details sync.
-- ============================================================================

-- 1. Ensure all 14 canonical columns exist on public.user_verifications
ALTER TABLE public.user_verifications
  ADD COLUMN IF NOT EXISTS id_front_url text,
  ADD COLUMN IF NOT EXISTS id_back_url text,
  ADD COLUMN IF NOT EXISTS face_selfie_url text,
  ADD COLUMN IF NOT EXISTS selfie_with_id_url text,
  ADD COLUMN IF NOT EXISTS full_name text,
  ADD COLUMN IF NOT EXISTS id_type text,
  ADD COLUMN IF NOT EXISTS id_number text,
  ADD COLUMN IF NOT EXISTS verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS verified_by uuid,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- 2. Backfill id_front_url and id_back_url from id_document_url if present
UPDATE public.user_verifications
SET
  id_front_url = COALESCE(id_front_url, NULLIF(SPLIT_PART(id_document_url::text, '|', 1), '')),
  id_back_url = COALESCE(id_back_url, NULLIF(SPLIT_PART(id_document_url::text, '|', 2), ''))
WHERE id_document_url IS NOT NULL
  AND (id_front_url IS NULL OR id_back_url IS NULL);

-- 3. Backfill full_name from public.users where missing
UPDATE public.user_verifications uv
SET full_name = u.full_name
FROM public.users u
WHERE uv.user_id = u.id
  AND (uv.full_name IS NULL OR TRIM(uv.full_name) = '')
  AND u.full_name IS NOT NULL;

-- 4. Bidirectional Sync Trigger for user_verifications
CREATE OR REPLACE FUNCTION public.sync_user_verifications_normalized_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- A. Populate updated_at
  NEW.updated_at := COALESCE(NEW.updated_at, now());

  -- B. Auto-populate legal full_name from users if not provided
  IF (NEW.full_name IS NULL OR TRIM(NEW.full_name) = '') AND NEW.user_id IS NOT NULL THEN
    SELECT u.full_name INTO NEW.full_name
    FROM public.users u
    WHERE u.id = NEW.user_id;
  END IF;

  -- C. Bidirectional sync between id_document_url <-> id_front_url / id_back_url
  -- Case 1: Client wrote clean id_front_url / id_back_url -> sync to legacy id_document_url
  IF NEW.id_front_url IS NOT NULL AND NEW.id_front_url <> '' THEN
    NEW.id_document_url := NEW.id_front_url ||
      CASE
        WHEN NEW.id_back_url IS NOT NULL AND NEW.id_back_url <> '' THEN '|' || NEW.id_back_url
        ELSE ''
      END;
  -- Case 2: Legacy client wrote id_document_url -> split into id_front_url / id_back_url
  ELSIF NEW.id_document_url IS NOT NULL AND NEW.id_document_url <> '' THEN
    IF NEW.id_front_url IS NULL OR NEW.id_front_url = '' THEN
      NEW.id_front_url := NULLIF(SPLIT_PART(NEW.id_document_url::text, '|', 1), '');
    END IF;
    IF NEW.id_back_url IS NULL OR NEW.id_back_url = '' THEN
      NEW.id_back_url := NULLIF(SPLIT_PART(NEW.id_document_url::text, '|', 2), '');
    END IF;
  END IF;

  -- D. Ensure face_selfie_url fallback from selfie_with_id_url if missing
  IF (NEW.face_selfie_url IS NULL OR NEW.face_selfie_url = '') AND NEW.selfie_with_id_url IS NOT NULL THEN
    NEW.face_selfie_url := NEW.selfie_with_id_url;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_user_verifications_normalized_columns ON public.user_verifications;
CREATE TRIGGER trg_sync_user_verifications_normalized_columns
BEFORE INSERT OR UPDATE ON public.user_verifications
FOR EACH ROW
EXECUTE FUNCTION public.sync_user_verifications_normalized_columns();

-- Ensure permissions
GRANT SELECT, INSERT, UPDATE ON public.user_verifications TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_verifications TO service_role;
