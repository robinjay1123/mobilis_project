-- Migration: Finalize Partner Vehicles Column Normalization
-- Description: Prunes isolated deprecated bloat columns from public.partner_vehicles
-- following complete client-side query modernization and trigger harmonization.

-- ============================================================================
-- 1. UPDATE TRIGGER TO NOT ASSIGN TO PRUNED COLUMNS
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sync_partner_vehicles_normalized_columns()
RETURNS trigger AS $$
BEGIN
  -- 1. Sync vehicle_name if empty
  IF NEW.vehicle_name IS NULL OR TRIM(NEW.vehicle_name) = '' THEN
    NEW.vehicle_name := TRIM(CONCAT(COALESCE(NEW.brand, ''), ' ', COALESCE(NEW.model, '')));
  END IF;

  -- 2. Sync status <-> is_available & is_posted
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

  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. PRUNE DEPRECATED & DUPLICATE COLUMNS FROM public.partner_vehicles
-- ============================================================================

-- Prune hourly pricing column (rentals are strictly daily per pricing structure)
ALTER TABLE public.partner_vehicles DROP COLUMN IF EXISTS price_per_hour CASCADE;

-- Prune duplicate category column (canonical vehicle_type holds type)
ALTER TABLE public.partner_vehicles DROP COLUMN IF EXISTS category CASCADE;

-- Prune redundant owner role column (always partner by table definition)
ALTER TABLE public.partner_vehicles DROP COLUMN IF EXISTS owner_role CASCADE;

-- Prune application status (canonical status belongs in partner_vehicle_applications)
ALTER TABLE public.partner_vehicles DROP COLUMN IF EXISTS application_status CASCADE;
