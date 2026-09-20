-- Migration: 20260921000100_create_booking_renter_documents_and_optimize_fks.sql
-- Goal: 1. Create booking_renter_documents satellite table for digital signatures & IDs.
--       2. Backfill historical documents from public.bookings.
--       3. Contract document and rating columns from public.bookings.
--       4. Add performance indexes on referencing foreign keys.

-- ============================================================================
-- 1. CREATE SATELLITE TABLE: booking_renter_documents
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.booking_renter_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  renter_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  renter_signature_url TEXT,
  renter_signature_text TEXT,
  renter_valid_id_url TEXT,
  renter_selfie_url TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_booking_renter_documents_booking_id UNIQUE (booking_id)
);

-- ============================================================================
-- 2. BACKFILL HISTORICAL DOCUMENTS FROM public.bookings
-- ============================================================================

INSERT INTO public.booking_renter_documents (
  booking_id,
  renter_id,
  renter_signature_url,
  renter_signature_text,
  renter_valid_id_url,
  renter_selfie_url,
  created_at,
  updated_at
)
SELECT
  b.id,
  b.renter_id,
  b.renter_signature_url,
  b.renter_signature_text,
  b.renter_valid_id_url,
  b.renter_selfie_url,
  COALESCE(b.created_at::timestamptz, now()),
  COALESCE(b.updated_at::timestamptz, now())
FROM public.bookings b
WHERE (
  b.renter_signature_url IS NOT NULL OR
  b.renter_signature_text IS NOT NULL OR
  b.renter_valid_id_url IS NOT NULL OR
  b.renter_selfie_url IS NOT NULL
)
ON CONFLICT (booking_id) DO UPDATE SET
  renter_signature_url = EXCLUDED.renter_signature_url,
  renter_signature_text = EXCLUDED.renter_signature_text,
  renter_valid_id_url = EXCLUDED.renter_valid_id_url,
  renter_selfie_url = EXCLUDED.renter_selfie_url,
  updated_at = now();

-- ============================================================================
-- 3. MIGRATE SYNC TRIGGER TO booking_renter_documents
-- ============================================================================

DROP TRIGGER IF EXISTS trg_sync_booking_to_inspection ON public.bookings;
DROP FUNCTION IF EXISTS public.sync_booking_to_inspection();

CREATE OR REPLACE FUNCTION public.sync_booking_document_to_inspection()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (NEW.renter_signature_url IS NOT NULL OR NEW.renter_selfie_url IS NOT NULL) THEN
    INSERT INTO public.booking_vehicle_inspections (
      booking_id,
      inspection_type,
      inspector_id,
      remarks,
      evidence_urls,
      created_at,
      updated_at
    )
    VALUES (
      NEW.booking_id,
      'before',
      COALESCE(NEW.renter_id, auth.uid()),
      COALESCE(NEW.renter_signature_text, 'Digital pickup signature'),
      jsonb_build_array(
        COALESCE(NEW.renter_signature_url, ''),
        COALESCE(NEW.renter_selfie_url, ''),
        COALESCE(NEW.renter_valid_id_url, '')
      ),
      NOW(),
      NOW()
    )
    ON CONFLICT (booking_id, inspection_type, inspector_id)
    DO UPDATE SET
      evidence_urls = EXCLUDED.evidence_urls,
      updated_at = NOW();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_doc_to_inspection ON public.booking_renter_documents;
CREATE TRIGGER trg_sync_doc_to_inspection
AFTER INSERT OR UPDATE ON public.booking_renter_documents
FOR EACH ROW
EXECUTE FUNCTION public.sync_booking_document_to_inspection();

-- ============================================================================
-- 4. CONTRACT DOCUMENT & RATING COLUMNS FROM public.bookings
-- ============================================================================

ALTER TABLE public.bookings
  DROP COLUMN IF EXISTS renter_signature_url,
  DROP COLUMN IF EXISTS renter_signature_text,
  DROP COLUMN IF EXISTS renter_valid_id_url,
  DROP COLUMN IF EXISTS renter_selfie_url,
  DROP COLUMN IF EXISTS completion_rating_average,
  DROP COLUMN IF EXISTS completion_rating_count;

-- ============================================================================
-- 5. PERFORMANCE INDEXES ON FOREIGN KEYS & QUERY PATHS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_booking_renter_documents_booking_id ON public.booking_renter_documents(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_renter_documents_renter_id ON public.booking_renter_documents(renter_id);

CREATE INDEX IF NOT EXISTS idx_bookings_partner_vehicle_id ON public.bookings(partner_vehicle_id);
CREATE INDEX IF NOT EXISTS idx_bookings_last_payment_id ON public.bookings(last_payment_id);

CREATE INDEX IF NOT EXISTS idx_trip_ratings_reviewer_user_id ON public.trip_ratings(reviewer_user_id);
CREATE INDEX IF NOT EXISTS idx_trip_ratings_target_user_id ON public.trip_ratings(target_user_id);
CREATE INDEX IF NOT EXISTS idx_trip_ratings_booking_id ON public.trip_ratings(booking_id);

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
