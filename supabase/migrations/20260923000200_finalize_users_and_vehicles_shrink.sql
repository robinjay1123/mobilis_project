-- Migration: Finalize Users and Vehicles Column Normalization
-- Description: Safely prunes isolated bloat columns from public.users and public.vehicles
-- after all data has been unified into canonical columns and role profiles.

-- ============================================================================
-- 0. DROP DEPENDENT VIEWS BEFORE PRUNING
-- ============================================================================
DROP VIEW IF EXISTS public.operator_profiles_view CASCADE;

-- ============================================================================
-- 1. PRUNE ROLE-SPECIFIC & DUPLICATE COLUMNS FROM public.users
-- ============================================================================

-- Operator desk MPIN columns (already housed in operator_profiles)
ALTER TABLE public.users DROP COLUMN IF EXISTS mpin_hash CASCADE;
ALTER TABLE public.users DROP COLUMN IF EXISTS mpin_salt CASCADE;
ALTER TABLE public.users DROP COLUMN IF EXISTS mpin_enabled CASCADE;
ALTER TABLE public.users DROP COLUMN IF EXISTS mpin_updated_at CASCADE;

-- Dedicated moderation reason columns (already housed in user_restrictions)
ALTER TABLE public.users DROP COLUMN IF EXISTS archive_reason CASCADE;
ALTER TABLE public.users DROP COLUMN IF EXISTS archived_at CASCADE;
ALTER TABLE public.users DROP COLUMN IF EXISTS restriction_reason CASCADE;
ALTER TABLE public.users DROP COLUMN IF EXISTS suspension_reason CASCADE;
ALTER TABLE public.users DROP COLUMN IF EXISTS suspended_at CASCADE;
ALTER TABLE public.users DROP COLUMN IF EXISTS off_platform_flag_count CASCADE;

-- ============================================================================
-- 2. PRUNE DEPRECATED COLUMNS FROM public.vehicles
-- ============================================================================

-- Prune unused hourly pricing column (rentals are strictly daily per pricing structure)
ALTER TABLE public.vehicles DROP COLUMN IF EXISTS price_per_hour CASCADE;

-- ============================================================================
-- 3. RECREATE OPERATOR PROFILES VIEW (WITHOUT DROPPED COLUMNS)
-- ============================================================================
CREATE OR REPLACE VIEW public.operator_profiles_view AS
SELECT 
    u.id,
    u.name,
    u.full_name,
    u.email,
    u.phone,
    u.avatar_url,
    u.profile_picture_url,
    u.is_active,
    u.is_blocked,
    u.chat_restricted_until,
    u.account_restricted_until,
    u.restriction_level,
    op.is_available,
    op.latitude,
    op.longitude,
    op.location,
    op.service_hub,
    op.updated_at AS operator_updated_at
FROM public.users u
JOIN public.operator_profiles op ON u.id = op.user_id;

GRANT SELECT ON public.operator_profiles_view TO authenticated, anon, service_role;
