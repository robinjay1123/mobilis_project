-- Migration: Finalize Users and Vehicles Column Normalization
-- Description: Safely prunes isolated bloat columns from public.users and public.vehicles
-- after all data has been unified into canonical columns and role profiles.

-- ============================================================================
-- 1. PRUNE ROLE-SPECIFIC & DUPLICATE COLUMNS FROM public.users
-- ============================================================================

-- Operator desk MPIN columns (already housed in operator_profiles)
ALTER TABLE public.users DROP COLUMN IF EXISTS mpin_hash;
ALTER TABLE public.users DROP COLUMN IF EXISTS mpin_salt;
ALTER TABLE public.users DROP COLUMN IF EXISTS mpin_enabled;
ALTER TABLE public.users DROP COLUMN IF EXISTS mpin_updated_at;

-- Dedicated moderation reason columns (already housed in user_restrictions)
ALTER TABLE public.users DROP COLUMN IF EXISTS archive_reason;
ALTER TABLE public.users DROP COLUMN IF EXISTS archived_at;
ALTER TABLE public.users DROP COLUMN IF EXISTS restriction_reason;
ALTER TABLE public.users DROP COLUMN IF EXISTS suspension_reason;
ALTER TABLE public.users DROP COLUMN IF EXISTS suspended_at;
ALTER TABLE public.users DROP COLUMN IF EXISTS off_platform_flag_count;

-- ============================================================================
-- 2. PRUNE DEPRECATED COLUMNS FROM public.vehicles
-- ============================================================================

-- Prune unused hourly pricing column (rentals are strictly daily per pricing structure)
ALTER TABLE public.vehicles DROP COLUMN IF EXISTS price_per_hour;
