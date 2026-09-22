-- Migration: Bridge and Normalization for public.users and public.vehicles
-- Description: Establishes bidirectional sync triggers and data backfills to safely
-- normalize public.users and public.vehicles without breaking existing queries or PostgREST endpoints.

-- ============================================================================
-- 1. USERS TABLE NORMALIZATION & BIDIRECTIONAL COMPATIBILITY
-- ============================================================================

-- Ensure canonical columns exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS full_name text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS verification_status text DEFAULT 'unverified';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone DEFAULT now();

-- Ensure legacy / bridge columns exist so queries selecting them never throw 42703
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS name text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS profile_picture_url text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS id_verified boolean DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS raw_user_meta_data jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS user_metadata jsonb DEFAULT '{}'::jsonb;

-- Drop NOT NULL on name if it exists, allowing inserts with only full_name
ALTER TABLE public.users ALTER COLUMN name DROP NOT NULL;

-- One-time data backfill
UPDATE public.users
SET 
  full_name = COALESCE(full_name, name),
  name = COALESCE(name, full_name),
  avatar_url = COALESCE(avatar_url, profile_picture_url),
  profile_picture_url = COALESCE(profile_picture_url, avatar_url),
  verification_status = CASE 
    WHEN verification_status IS NOT NULL THEN verification_status
    WHEN id_verified IS TRUE THEN 'verified'
    ELSE 'unverified'
  END,
  id_verified = CASE
    WHEN verification_status = 'verified' THEN TRUE
    WHEN id_verified IS TRUE THEN TRUE
    ELSE FALSE
  END,
  metadata = COALESCE(metadata, user_metadata, raw_user_meta_data, '{}'::jsonb),
  user_metadata = COALESCE(user_metadata, metadata, '{}'::jsonb),
  raw_user_meta_data = COALESCE(raw_user_meta_data, metadata, '{}'::jsonb);

-- Normalization Trigger for public.users
CREATE OR REPLACE FUNCTION public.sync_users_normalized_columns()
RETURNS trigger AS $$
BEGIN
  -- Sync full_name <-> name
  IF NEW.full_name IS NULL AND NEW.name IS NOT NULL THEN
    NEW.full_name := NEW.name;
  ELSIF NEW.full_name IS NOT NULL THEN
    NEW.name := NEW.full_name;
  END IF;

  -- Sync avatar_url <-> profile_picture_url
  IF NEW.avatar_url IS NULL AND NEW.profile_picture_url IS NOT NULL THEN
    NEW.avatar_url := NEW.profile_picture_url;
  ELSIF NEW.avatar_url IS NOT NULL THEN
    NEW.profile_picture_url := NEW.avatar_url;
  END IF;

  -- Sync verification_status <-> id_verified
  IF NEW.verification_status IS NULL AND NEW.id_verified IS TRUE THEN
    NEW.verification_status := 'verified';
  ELSIF NEW.verification_status = 'verified' THEN
    NEW.id_verified := TRUE;
  ELSIF NEW.verification_status IS NOT NULL AND NEW.verification_status != 'verified' THEN
    NEW.id_verified := FALSE;
  ELSIF NEW.id_verified IS TRUE THEN
    NEW.verification_status := 'verified';
  END IF;

  -- Sync metadata <-> user_metadata <-> raw_user_meta_data
  IF NEW.metadata IS NOT NULL AND (NEW.metadata != '{}'::jsonb) THEN
    NEW.user_metadata := NEW.metadata;
    NEW.raw_user_meta_data := NEW.metadata;
  ELSIF NEW.user_metadata IS NOT NULL AND (NEW.user_metadata != '{}'::jsonb) THEN
    NEW.metadata := NEW.user_metadata;
    NEW.raw_user_meta_data := NEW.user_metadata;
  ELSIF NEW.raw_user_meta_data IS NOT NULL AND (NEW.raw_user_meta_data != '{}'::jsonb) THEN
    NEW.metadata := NEW.raw_user_meta_data;
    NEW.user_metadata := NEW.raw_user_meta_data;
  END IF;

  -- Sync status <-> is_blocked / is_active
  IF NEW.status = 'banned' OR NEW.status = 'blocked' THEN
    NEW.is_blocked := TRUE;
    NEW.is_active := FALSE;
  ELSIF NEW.status = 'suspended' THEN
    NEW.is_active := FALSE;
  ELSIF NEW.status = 'active' THEN
    NEW.is_active := TRUE;
    NEW.is_blocked := FALSE;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_users_normalized_columns ON public.users;
CREATE TRIGGER trg_sync_users_normalized_columns
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.sync_users_normalized_columns();

-- ============================================================================
-- 2. VEHICLES TABLE NORMALIZATION & BIDIRECTIONAL COMPATIBILITY
-- ============================================================================

-- Ensure canonical columns exist
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS status text DEFAULT 'available';
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS vehicle_name text;

-- Ensure legacy / bridge columns exist so queries selecting them never throw 42703
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS is_available boolean DEFAULT true;
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS is_posted boolean DEFAULT true;
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS category text DEFAULT 'Standard';

-- One-time data backfill
UPDATE public.vehicles
SET
  status = CASE
    WHEN status IS NOT NULL AND status != '' THEN status
    WHEN is_available IS TRUE THEN 'available'
    ELSE 'disabled'
  END,
  vehicle_name = CASE
    WHEN vehicle_name IS NOT NULL AND vehicle_name != '' THEN vehicle_name
    ELSE TRIM(CONCAT(COALESCE(brand, ''), ' ', COALESCE(model, '')))
  END,
  is_available = CASE
    WHEN status = 'available' THEN TRUE
    WHEN is_available IS TRUE THEN TRUE
    ELSE FALSE
  END,
  is_posted = CASE
    WHEN status IN ('available', 'rented', 'maintenance') THEN TRUE
    WHEN is_posted IS TRUE THEN TRUE
    ELSE FALSE
  END;

-- Normalization Trigger for public.vehicles
CREATE OR REPLACE FUNCTION public.sync_vehicles_normalized_columns()
RETURNS trigger AS $$
BEGIN
  -- Sync vehicle_name if empty
  IF NEW.vehicle_name IS NULL OR TRIM(NEW.vehicle_name) = '' THEN
    NEW.vehicle_name := TRIM(CONCAT(COALESCE(NEW.brand, ''), ' ', COALESCE(NEW.model, '')));
  END IF;

  -- Sync status <-> is_available & is_posted
  IF NEW.status IS NULL THEN
    IF NEW.is_available IS TRUE THEN
      NEW.status := 'available';
    ELSE
      NEW.status := 'disabled';
    END IF;
  END IF;

  IF NEW.status = 'available' THEN
    NEW.is_available := TRUE;
    NEW.is_posted := TRUE;
  ELSIF NEW.status IN ('rented', 'maintenance') THEN
    NEW.is_available := FALSE;
    NEW.is_posted := TRUE;
  ELSE
    NEW.is_available := FALSE;
    NEW.is_posted := FALSE;
  END IF;

  -- Sync category with vehicle_type if empty
  IF NEW.category IS NULL AND NEW.vehicle_type IS NOT NULL THEN
    NEW.category := NEW.vehicle_type;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_vehicles_normalized_columns ON public.vehicles;
CREATE TRIGGER trg_sync_vehicles_normalized_columns
BEFORE INSERT OR UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.sync_vehicles_normalized_columns();
