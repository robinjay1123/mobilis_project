-- ============================================================================
-- Migration: 20260923000600_finalize_user_verifications_shrink.sql
-- Description: Prunes obsolete dead columns on public.user_verifications.
-- ============================================================================

-- 1. Drop unused artificial intelligence column that was never implemented
ALTER TABLE public.user_verifications
  DROP COLUMN IF EXISTS face_match_percentage;

COMMENT ON TABLE public.user_verifications IS 'Normalized government identity verifications for user profiles.';
