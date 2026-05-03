-- Drop obsolete vehicle columns that are no longer used by the app schema.
-- Keep vehicle_images.image_url intact for the gallery relation.

BEGIN;

ALTER TABLE IF EXISTS public.vehicles
  DROP COLUMN IF EXISTS image_url,
  DROP COLUMN IF EXISTS transmission,
  DROP COLUMN IF EXISTS fuel_type;

COMMIT;