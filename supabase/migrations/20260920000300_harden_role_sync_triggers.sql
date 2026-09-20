-- Migration: 20260920000300_harden_role_sync_triggers.sql
-- Description: Hardens bidirectional synchronization triggers between users and operator_profiles.
-- Eliminates redundant double-writes and guards against infinite trigger recursion (pg_trigger_depth).
-- Only performs write operations when relevant state attributes actually change.

-- ============================================================================
-- 1. Hardened sync: users -> operator_profiles / admin_profiles
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sync_user_role_profiles()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Prevent recursive cascading trigger loops
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    -- Optimization: If updating users, only proceed if role or operator-specific fields changed
    IF TG_OP = 'UPDATE' THEN
        IF (NEW.role IS NOT DISTINCT FROM OLD.role)
           AND (NEW.is_available IS NOT DISTINCT FROM OLD.is_available)
           AND (NEW.latitude IS NOT DISTINCT FROM OLD.latitude)
           AND (NEW.longitude IS NOT DISTINCT FROM OLD.longitude)
           AND (NEW.location IS NOT DISTINCT FROM OLD.location) THEN
            RETURN NEW;
        END IF;
    END IF;

    IF NEW.role = 'operator' THEN
        INSERT INTO public.operator_profiles (
            user_id, 
            is_available, 
            latitude, 
            longitude, 
            location,
            updated_at
        )
        VALUES (
            NEW.id, 
            COALESCE(NEW.is_available, false), 
            NEW.latitude, 
            NEW.longitude, 
            NEW.location,
            now()
        )
        ON CONFLICT (user_id) DO UPDATE
        SET 
            is_available = COALESCE(EXCLUDED.is_available, operator_profiles.is_available),
            latitude = COALESCE(EXCLUDED.latitude, operator_profiles.latitude),
            longitude = COALESCE(EXCLUDED.longitude, operator_profiles.longitude),
            location = COALESCE(EXCLUDED.location, operator_profiles.location),
            updated_at = now()
        WHERE operator_profiles.is_available IS DISTINCT FROM EXCLUDED.is_available
           OR operator_profiles.latitude IS DISTINCT FROM EXCLUDED.latitude
           OR operator_profiles.longitude IS DISTINCT FROM EXCLUDED.longitude
           OR operator_profiles.location IS DISTINCT FROM EXCLUDED.location;

    ELSIF NEW.role = 'admin' THEN
        INSERT INTO public.admin_profiles (user_id, admin_level)
        VALUES (NEW.id, 'superadmin')
        ON CONFLICT (user_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$;

-- Ensure trigger is bound to only the relevant columns on users
DROP TRIGGER IF EXISTS trg_sync_user_role_profiles ON public.users;
CREATE TRIGGER trg_sync_user_role_profiles
AFTER INSERT OR UPDATE OF role, is_available, latitude, longitude, location
ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_user_role_profiles();

-- ============================================================================
-- 2. Hardened sync: operator_profiles -> users
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sync_operator_profile_to_users()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Prevent recursive cascading trigger loops
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    -- Optimization: Only update users if values actually differ
    IF TG_OP = 'UPDATE' THEN
        IF (NEW.is_available IS NOT DISTINCT FROM OLD.is_available)
           AND (NEW.latitude IS NOT DISTINCT FROM OLD.latitude)
           AND (NEW.longitude IS NOT DISTINCT FROM OLD.longitude)
           AND (NEW.location IS NOT DISTINCT FROM OLD.location) THEN
            RETURN NEW;
        END IF;
    END IF;

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
