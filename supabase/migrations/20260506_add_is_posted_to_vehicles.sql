-- Add posting state directly to vehicles for operator-owned vehicles
BEGIN;

ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS is_posted boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_vehicles_is_posted ON public.vehicles(is_posted);

COMMIT;
