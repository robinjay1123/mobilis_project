-- Add operator_id column to vehicles and FK to users
BEGIN;

ALTER TABLE IF EXISTS public.vehicles
  ADD COLUMN IF NOT EXISTS operator_id uuid;

DO $$
BEGIN
  IF to_regclass('public.vehicles') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'vehicles_operator_id_fkey'
        AND conrelid = 'public.vehicles'::regclass
    ) THEN
      ALTER TABLE public.vehicles
        ADD CONSTRAINT vehicles_operator_id_fkey
        FOREIGN KEY (operator_id) REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_vehicles_operator_id ON public.vehicles(operator_id);

COMMIT;
