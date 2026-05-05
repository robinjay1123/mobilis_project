-- Add vehicle metadata columns used by the operator vehicle form
-- Keeps existing vehicle fields intact while introducing the new metadata fields.

BEGIN;

ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Standard',
  ADD COLUMN IF NOT EXISTS vehicle_type TEXT DEFAULT 'Sedan',
  ADD COLUMN IF NOT EXISTS vehicle_name TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS color TEXT;

CREATE INDEX IF NOT EXISTS idx_vehicles_category ON public.vehicles(category);
CREATE INDEX IF NOT EXISTS idx_vehicles_vehicle_type ON public.vehicles(vehicle_type);
CREATE INDEX IF NOT EXISTS idx_vehicles_vehicle_name ON public.vehicles(vehicle_name);
CREATE INDEX IF NOT EXISTS idx_vehicles_color ON public.vehicles(color);

UPDATE public.vehicles
SET
  category = COALESCE(category, 'Standard'),
  vehicle_type = COALESCE(vehicle_type, 'Sedan')
WHERE category IS NULL OR vehicle_type IS NULL;

COMMIT;