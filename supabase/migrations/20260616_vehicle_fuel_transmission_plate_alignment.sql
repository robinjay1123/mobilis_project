-- Keep vehicle specs connected across applications, partner vehicles, and
-- renter-facing vehicle records.

BEGIN;

ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS fuel_type text DEFAULT 'Gasoline',
  ADD COLUMN IF NOT EXISTS transmission text DEFAULT 'Manual';

ALTER TABLE IF EXISTS public.partner_vehicles
  ADD COLUMN IF NOT EXISTS plate_number text,
  ADD COLUMN IF NOT EXISTS seats integer DEFAULT 5,
  ADD COLUMN IF NOT EXISTS fuel_type text DEFAULT 'Gasoline',
  ADD COLUMN IF NOT EXISTS transmission text DEFAULT 'Manual';

ALTER TABLE IF EXISTS public.partner_vehicle_applications
  ADD COLUMN IF NOT EXISTS seats integer DEFAULT 5,
  ADD COLUMN IF NOT EXISTS fuel_type text DEFAULT 'Gasoline',
  ADD COLUMN IF NOT EXISTS transmission text DEFAULT 'Manual';

UPDATE public.vehicles
SET transmission = 'Manual'
WHERE transmission IS NULL
   OR btrim(transmission) = ''
   OR lower(transmission) NOT IN ('manual', 'automatic');

UPDATE public.vehicles
SET fuel_type = 'Gasoline'
WHERE fuel_type IS NULL OR btrim(fuel_type) = '';

UPDATE public.partner_vehicles pv
SET
  plate_number = COALESCE(pv.plate_number, v.plate_number),
  seats = COALESCE(pv.seats, v.seats, 5),
  fuel_type = COALESCE(NULLIF(btrim(pv.fuel_type), ''), v.fuel_type, 'Gasoline'),
  transmission = CASE
    WHEN lower(COALESCE(NULLIF(btrim(pv.transmission), ''), v.transmission, 'Manual')) IN ('manual', 'automatic')
      THEN COALESCE(NULLIF(btrim(pv.transmission), ''), v.transmission, 'Manual')
    ELSE 'Manual'
  END
FROM public.vehicles v
WHERE pv.vehicle_id = v.id;

UPDATE public.partner_vehicle_applications
SET transmission = 'Manual'
WHERE transmission IS NULL
   OR btrim(transmission) = ''
   OR lower(transmission) NOT IN ('manual', 'automatic');

UPDATE public.partner_vehicle_applications
SET fuel_type = 'Gasoline'
WHERE fuel_type IS NULL OR btrim(fuel_type) = '';

CREATE INDEX IF NOT EXISTS idx_vehicles_fuel_type ON public.vehicles(fuel_type);
CREATE INDEX IF NOT EXISTS idx_vehicles_transmission ON public.vehicles(transmission);
CREATE INDEX IF NOT EXISTS idx_partner_vehicles_plate_number
  ON public.partner_vehicles(plate_number);
CREATE INDEX IF NOT EXISTS idx_partner_vehicles_fuel_type
  ON public.partner_vehicles(fuel_type);
CREATE INDEX IF NOT EXISTS idx_partner_vehicle_applications_fuel_type
  ON public.partner_vehicle_applications(fuel_type);

COMMIT;
