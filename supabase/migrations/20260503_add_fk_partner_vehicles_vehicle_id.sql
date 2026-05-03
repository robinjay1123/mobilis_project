-- Ensure partner_vehicles has vehicle_id column and add FK to vehicles(id)
BEGIN;

ALTER TABLE IF EXISTS public.partner_vehicles
  ADD COLUMN IF NOT EXISTS vehicle_id uuid;

-- Add foreign key constraint if it doesn't already exist
DO $$
BEGIN
  IF to_regclass('public.partner_vehicles') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'partner_vehicles_vehicle_id_fkey'
        AND conrelid = 'public.partner_vehicles'::regclass
    ) THEN
      ALTER TABLE public.partner_vehicles
        ADD CONSTRAINT partner_vehicles_vehicle_id_fkey
        FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id) ON DELETE CASCADE;
    END IF;
  END IF;
END$$;

-- Add index for faster joins
CREATE INDEX IF NOT EXISTS idx_partner_vehicles_vehicle_id ON public.partner_vehicles(vehicle_id);

COMMIT;
