-- Add vehicle_type and search-related columns to vehicles table
-- Purpose: Enable vehicle categorization and search/filter functionality in renter UI

BEGIN;

-- Ensure category column exists for vehicle classification
ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Standard',
  ADD COLUMN IF NOT EXISTS vehicle_type TEXT DEFAULT 'Sedan',
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS color TEXT,
  ADD COLUMN IF NOT EXISTS seats INTEGER DEFAULT 4,
  ADD COLUMN IF NOT EXISTS transmission TEXT,
  ADD COLUMN IF NOT EXISTS fuel_type TEXT,
  ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 4.5,
  ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- Add indexes for search and filtering performance
CREATE INDEX IF NOT EXISTS idx_vehicles_category ON public.vehicles(category);
CREATE INDEX IF NOT EXISTS idx_vehicles_vehicle_type ON public.vehicles(vehicle_type);
CREATE INDEX IF NOT EXISTS idx_vehicles_brand ON public.vehicles(brand);
CREATE INDEX IF NOT EXISTS idx_vehicles_model ON public.vehicles(model);
CREATE INDEX IF NOT EXISTS idx_vehicles_status_available ON public.vehicles(status, is_available);
CREATE INDEX IF NOT EXISTS idx_vehicles_price_per_day ON public.vehicles(price_per_day);

-- Create a full-text search index for brand, model, and description
ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS search_text tsvector;

-- Update existing records with initial category values if they don't have one
UPDATE public.vehicles
SET category = CASE
  WHEN vehicle_type IN ('SUV', 'Crossover') THEN 'SUV'
  WHEN vehicle_type IN ('Van', 'Minivan') THEN 'Van'
  WHEN vehicle_type IN ('Sports', 'Coupe') THEN 'Luxury'
  ELSE 'Economy'
END
WHERE category = 'Standard' OR category IS NULL;

COMMIT;
