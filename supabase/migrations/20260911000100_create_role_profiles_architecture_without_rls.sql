-- Migration: 20260911000100_create_role_profiles_architecture_without_rls.sql
-- Description: Non-destructive role-based user architecture.
-- Adds operator_profiles, admin_profiles, and admin_audit_logs without dropping or altering existing columns.
-- Keeps public.users completely intact for 100% backward-compatibility with all existing Flutter queries.
-- Disables RLS for development/testing phase per project convention.

-- ============================================================================
-- 1. Create operator_profiles table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.operator_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    is_available BOOLEAN DEFAULT false,
    latitude NUMERIC,
    longitude NUMERIC,
    location TEXT,
    service_hub TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast user_id lookups
CREATE INDEX IF NOT EXISTS idx_operator_profiles_user_id ON public.operator_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_operator_profiles_available ON public.operator_profiles(is_available);

-- ============================================================================
-- 2. Create admin_profiles table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.admin_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    admin_level TEXT DEFAULT 'superadmin',
    can_manage_users BOOLEAN DEFAULT true,
    can_manage_operators BOOLEAN DEFAULT true,
    can_manage_partners BOOLEAN DEFAULT true,
    can_manage_drivers BOOLEAN DEFAULT true,
    can_manage_bookings BOOLEAN DEFAULT true,
    can_manage_payments BOOLEAN DEFAULT true,
    can_manage_settings BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_profiles_user_id ON public.admin_profiles(user_id);

-- ============================================================================
-- 3. Create admin_audit_logs table (Matches AdminService.dart structure)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    entity_id TEXT,
    entity_type TEXT,
    action TEXT NOT NULL,
    notes TEXT,
    booking_id TEXT,
    driver_id TEXT,
    renter_id TEXT,
    vehicle_id TEXT,
    partner_id TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    details JSONB DEFAULT '{}'::jsonb,
    ip_address TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_entity ON public.admin_audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at ON public.admin_audit_logs(created_at DESC);

-- ============================================================================
-- 4. Initial Backfill (Idempotent - safe to run multiple times)
-- ============================================================================
-- Backfill operators
INSERT INTO public.operator_profiles (user_id, is_available, latitude, longitude, location)
SELECT 
    id, 
    COALESCE(is_available, false), 
    latitude, 
    longitude, 
    location
FROM public.users
WHERE role = 'operator'
ON CONFLICT (user_id) DO UPDATE
SET 
    is_available = COALESCE(EXCLUDED.is_available, operator_profiles.is_available),
    latitude = COALESCE(EXCLUDED.latitude, operator_profiles.latitude),
    longitude = COALESCE(EXCLUDED.longitude, operator_profiles.longitude),
    location = COALESCE(EXCLUDED.location, operator_profiles.location),
    updated_at = now();

-- Backfill admins
INSERT INTO public.admin_profiles (user_id, admin_level)
SELECT id, 'superadmin'
FROM public.users
WHERE role = 'admin'
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================================
-- 5. Backward-Compatibility Safety Triggers
-- Ensures that existing Flutter queries reading/writing to users or operator_profiles
-- stay 100% synchronized without breaking any code.
-- ============================================================================

-- A. Auto-provision role profile when users role is set/updated
CREATE OR REPLACE FUNCTION public.sync_user_role_profiles()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.role = 'operator' THEN
        INSERT INTO public.operator_profiles (user_id, is_available, latitude, longitude, location)
        VALUES (NEW.id, COALESCE(NEW.is_available, false), NEW.latitude, NEW.longitude, NEW.location)
        ON CONFLICT (user_id) DO UPDATE
        SET 
            is_available = COALESCE(EXCLUDED.is_available, operator_profiles.is_available),
            latitude = COALESCE(EXCLUDED.latitude, operator_profiles.latitude),
            longitude = COALESCE(EXCLUDED.longitude, operator_profiles.longitude),
            location = COALESCE(EXCLUDED.location, operator_profiles.location),
            updated_at = now();
    ELSIF NEW.role = 'admin' THEN
        INSERT INTO public.admin_profiles (user_id, admin_level)
        VALUES (NEW.id, 'superadmin')
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_user_role_profiles ON public.users;
CREATE TRIGGER trg_sync_user_role_profiles
AFTER INSERT OR UPDATE OF role, is_available, latitude, longitude, location
ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_user_role_profiles();

-- B. When operator_profiles is updated, mirror back to users so old queries still work
CREATE OR REPLACE FUNCTION public.sync_operator_profile_to_users()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.users
    SET 
        is_available = NEW.is_available,
        latitude = NEW.latitude,
        longitude = NEW.longitude,
        location = NEW.location
    WHERE id = NEW.user_id
      AND (
          is_available IS DISTINCT FROM NEW.is_available OR
          latitude IS DISTINCT FROM NEW.latitude OR
          longitude IS DISTINCT FROM NEW.longitude OR
          location IS DISTINCT FROM NEW.location
      );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_operator_profile_to_users ON public.operator_profiles;
CREATE TRIGGER trg_sync_operator_profile_to_users
AFTER UPDATE OF is_available, latitude, longitude, location
ON public.operator_profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_operator_profile_to_users();

-- ============================================================================
-- 6. Operator Profiles View (For convenient joined queries)
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
    u.off_platform_flag_count,
    u.chat_restricted_until,
    u.account_restricted_until,
    u.restriction_level,
    u.restriction_reason,
    op.is_available,
    op.latitude,
    op.longitude,
    op.location,
    op.service_hub,
    op.updated_at AS operator_updated_at
FROM public.users u
JOIN public.operator_profiles op ON u.id = op.user_id;

-- ============================================================================
-- 7. Disable RLS and Grant Permissions (Testing/Dev Phase per project convention)
-- ============================================================================
ALTER TABLE public.operator_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs DISABLE ROW LEVEL SECURITY;

GRANT ALL ON public.operator_profiles TO authenticated, anon, service_role;
GRANT ALL ON public.admin_profiles TO authenticated, anon, service_role;
GRANT ALL ON public.admin_audit_logs TO authenticated, anon, service_role;
GRANT SELECT ON public.operator_profiles_view TO authenticated, anon, service_role;
