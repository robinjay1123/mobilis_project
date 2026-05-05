-- Add hourly pricing and coordinates for vehicles.
-- Mirrors the signup locator flow by storing a text location and coordinates.

BEGIN;

ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS price_per_hour numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS location text,
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;

CREATE INDEX IF NOT EXISTS idx_vehicles_price_per_hour ON public.vehicles(price_per_hour);
CREATE INDEX IF NOT EXISTS idx_vehicles_location ON public.vehicles(location);
CREATE INDEX IF NOT EXISTS idx_vehicles_latitude ON public.vehicles(latitude);
CREATE INDEX IF NOT EXISTS idx_vehicles_longitude ON public.vehicles(longitude);

COMMIT;