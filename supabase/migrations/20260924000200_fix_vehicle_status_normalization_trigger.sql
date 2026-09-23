-- Migration: Fix vehicle status normalization trigger for vehicles and partner_vehicles
-- Description: Ensures that status 'active' is also recognized alongside 'available' as listed/available,
-- preventing the trigger from inadvertently resetting is_posted and is_available to false.

-- 1. Update trigger on public.vehicles
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

  IF NEW.status IN ('available', 'active') THEN
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

-- 2. Update trigger on public.partner_vehicles
CREATE OR REPLACE FUNCTION public.sync_partner_vehicles_normalized_columns()
RETURNS trigger AS $$
BEGIN
  -- Sync user_id from partners table if empty
  IF NEW.user_id IS NULL AND NEW.partner_id IS NOT NULL THEN
    SELECT user_id INTO NEW.user_id
    FROM public.partners
    WHERE id = NEW.partner_id
    LIMIT 1;
  END IF;

  -- Sync vehicle_type <-> category
  IF NEW.vehicle_type IS NULL AND NEW.category IS NOT NULL THEN
    NEW.vehicle_type := NEW.category;
  ELSIF NEW.category IS NULL AND NEW.vehicle_type IS NOT NULL THEN
    NEW.category := NEW.vehicle_type;
  END IF;

  -- Sync status <-> is_available & is_posted
  IF NEW.status IS NULL THEN
    IF NEW.is_available IS TRUE THEN
      NEW.status := 'available';
    ELSE
      NEW.status := 'disabled';
    END IF;
  END IF;

  IF NEW.status IN ('available', 'active') THEN
    NEW.is_available := TRUE;
    NEW.is_posted := TRUE;
  ELSIF NEW.status IN ('rented', 'maintenance') THEN
    NEW.is_available := FALSE;
    NEW.is_posted := TRUE;
  ELSE
    NEW.is_available := FALSE;
    NEW.is_posted := FALSE;
  END IF;

  -- Sync application_status with status
  IF NEW.application_status IS NULL THEN
    IF NEW.status IN ('available', 'active', 'rented', 'maintenance', 'disabled', 'sold') THEN
      NEW.application_status := 'approved';
    ELSE
      NEW.application_status := NEW.status;
    END IF;
  END IF;

  -- Always set owner_role to 'partner'
  NEW.owner_role := 'partner';

  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
