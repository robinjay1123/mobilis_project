-- Remove owner_type from vehicles
BEGIN;

ALTER TABLE IF EXISTS public.vehicles
  DROP COLUMN IF EXISTS owner_type;

DROP INDEX IF EXISTS public.idx_vehicles_owner_type;

COMMIT;
