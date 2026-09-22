-- Migration: Bridge and Normalization for public.partner_vehicles
-- Description: Establishes bidirectional sync triggers and data backfills to safely
-- normalize public.partner_vehicles without breaking existing queries, approval flows, or PostgREST endpoints.

-- ============================================================================
-- 1. ENSURE CANONICAL COLUMNS EXIST ON public.partner_vehicles
-- ============================================================================

ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS vehicle_name text;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS vehicle_type text DEFAULT 'Sedan';
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS status text DEFAULT 'available';
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS price_per_day numeric DEFAULT 0;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS fuel_type text DEFAULT 'Gasoline';
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS transmission text DEFAULT 'Manual';
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS seats integer DEFAULT 5;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS color text DEFAULT 'White';
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS location text DEFAULT 'Dagupan City, Pangasinan';
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS owner_is_driver boolean DEFAULT false;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS rating numeric DEFAULT 0.0;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS rating_count integer DEFAULT 0;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS cleaning_until timestamp with time zone;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS auto_relist_at timestamp with time zone;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

-- Ensure legacy / bridge columns exist so queries selecting/updating them never throw 42703
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS is_available boolean DEFAULT true;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS is_posted boolean DEFAULT true;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS category text DEFAULT 'Standard';
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS price_per_hour numeric DEFAULT 0;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS longitude double precision;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS owner_name text;
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS owner_role text DEFAULT 'partner';
ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS application_status text DEFAULT 'approved';

-- ============================================================================
-- 2. ONE-TIME DATA BACKFILL & HARMONIZATION
-- ============================================================================

UPDATE public.partner_vehicles
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
  vehicle_type = COALESCE(vehicle_type, category, 'Sedan'),
  category = COALESCE(category, vehicle_type, 'Standard'),
  is_available = CASE
    WHEN status = 'available' THEN TRUE
    WHEN is_available IS TRUE THEN TRUE
    ELSE FALSE
  END,
  is_posted = CASE
    WHEN status IN ('available', 'rented', 'maintenance') THEN TRUE
    WHEN is_posted IS TRUE THEN TRUE
    ELSE FALSE
  END,
  owner_role = 'partner',
  rating = COALESCE(rating, 0.0),
  rating_count = COALESCE(rating_count, 0);

-- ============================================================================
-- 3. BIDIRECTIONAL SYNC TRIGGER FOR public.partner_vehicles
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sync_partner_vehicles_normalized_columns()
RETURNS trigger AS $$
BEGIN
  -- 1. Sync vehicle_name if empty
  IF NEW.vehicle_name IS NULL OR TRIM(NEW.vehicle_name) = '' THEN
    NEW.vehicle_name := TRIM(CONCAT(COALESCE(NEW.brand, ''), ' ', COALESCE(NEW.model, '')));
  END IF;

  -- 2. Sync vehicle_type <-> category
  IF NEW.vehicle_type IS NULL AND NEW.category IS NOT NULL THEN
    NEW.vehicle_type := NEW.category;
  ELSIF NEW.category IS NULL AND NEW.vehicle_type IS NOT NULL THEN
    NEW.category := NEW.vehicle_type;
  END IF;

  -- 3. Sync status <-> is_available & is_posted
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

  -- 4. Sync application_status with status
  IF NEW.application_status IS NULL THEN
    IF NEW.status IN ('available', 'rented', 'maintenance', 'disabled', 'sold') THEN
      NEW.application_status := 'approved';
    ELSE
      NEW.application_status := NEW.status;
    END IF;
  END IF;

  -- 5. Always set owner_role to 'partner'
  NEW.owner_role := 'partner';

  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Replace legacy trigger with comprehensive normalized trigger
DROP TRIGGER IF EXISTS trg_sync_partner_vehicle_name ON public.partner_vehicles;
DROP TRIGGER IF EXISTS trg_sync_partner_vehicles_normalized_columns ON public.partner_vehicles;

CREATE TRIGGER trg_sync_partner_vehicles_normalized_columns
BEFORE INSERT OR UPDATE ON public.partner_vehicles
FOR EACH ROW EXECUTE FUNCTION public.sync_partner_vehicles_normalized_columns();
