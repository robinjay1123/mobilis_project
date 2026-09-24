-- ==============================================================================
-- Migration: 20260924000600_harden_auth_user_creation_and_oauth.sql
-- Description:
--   Hardens public.handle_new_auth_user() to support both Google OAuth and
--   email/password signup seamlessly:
--   1. Populates both name and full_name safely without null errors.
--   2. Extracts and saves avatar_url / picture from Google OAuth metadata.
--   3. Preserves existing user roles on conflict (prevents downgrading admin/operator/partner).
--   4. Ensures matching row in public.profiles for renter/driver/partner roles.
--   5. Sets status = 'active' and is_active = true by default.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
  v_role text;
  v_avatar text;
BEGIN
  -- Safe name resolution
  v_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data ->> 'full_name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data ->> 'name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data ->> 'display_name'), ''),
    NULLIF(split_part(NEW.email, '@', 1), ''),
    'User'
  );

  -- Safe role resolution (default to renter)
  v_role := COALESCE(
    NULLIF(LOWER(TRIM(NEW.raw_user_meta_data ->> 'role')), ''),
    'renter'
  );

  -- Safe avatar resolution (especially for Google OAuth)
  v_avatar := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data ->> 'avatar_url'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data ->> 'picture'), '')
  );

  -- Insert or update public.users
  INSERT INTO public.users (
    id,
    name,
    full_name,
    email,
    phone,
    avatar_url,
    role,
    status,
    is_active,
    created_at
  )
  VALUES (
    NEW.id,
    v_name,
    v_name,
    NEW.email,
    NEW.raw_user_meta_data ->> 'phone',
    v_avatar,
    v_role,
    'active',
    true,
    now()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = COALESCE(EXCLUDED.email, public.users.email),
    full_name = COALESCE(public.users.full_name, EXCLUDED.full_name),
    name = COALESCE(public.users.name, EXCLUDED.name),
    avatar_url = COALESCE(public.users.avatar_url, EXCLUDED.avatar_url),
    phone = COALESCE(public.users.phone, EXCLUDED.phone),
    -- Preserve existing role if already set, otherwise accept new role
    role = COALESCE(public.users.role, EXCLUDED.role, 'renter'),
    status = COALESCE(public.users.status, 'active'),
    is_active = COALESCE(public.users.is_active, true);

  -- Also ensure public.profiles has a corresponding row if role is renter, driver, or partner
  IF v_role IN ('renter', 'driver', 'partner') THEN
    INSERT INTO public.profiles (id, role, full_name, avatar_url, created_at)
    VALUES (NEW.id, v_role, v_name, v_avatar, now())
    ON CONFLICT (id) DO UPDATE
    SET
      full_name = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
      avatar_url = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url);
  END IF;

  RETURN NEW;
END;
$$;

-- Ensure trigger is active on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_auth_user();
