-- Add transmission field to vehicles table for car details
-- Supports Manual or Automatic transmission types

BEGIN;

ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS transmission text DEFAULT 'Manual';

-- Add index for transmission filtering
CREATE INDEX IF NOT EXISTS idx_vehicles_transmission ON public.vehicles(transmission);

-- Update existing records to have a default transmission type
UPDATE public.vehicles
SET transmission = 'Manual'
WHERE transmission IS NULL OR transmission = '';

COMMIT;
