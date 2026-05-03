-- Add owner_type column to vehicles to record whether owner is partner/operator
ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS owner_type TEXT DEFAULT 'partner';

-- Backfill existing vehicles without owner_type as 'partner'
UPDATE public.vehicles
SET owner_type = COALESCE(owner_type, 'partner')
WHERE owner_type IS NULL;

-- Index for queries filtering by owner_type
CREATE INDEX IF NOT EXISTS idx_vehicles_owner_type ON public.vehicles(owner_type);

COMMENT ON COLUMN public.vehicles.owner_type IS 'Type of owner: partner | operator | system';
