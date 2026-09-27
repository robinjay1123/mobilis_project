-- Fix missing is_available column on public.drivers and harden the sync trigger

-- 1. Ensure is_available exists on public.drivers table
ALTER TABLE IF EXISTS public.drivers
  ADD COLUMN IF NOT EXISTS is_available boolean DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_drivers_is_available
  ON public.drivers(is_available);

-- Backfill availability from users table if available
UPDATE public.drivers d
SET is_available = COALESCE(u.is_available, true)
FROM public.users u
WHERE d.user_id = u.id
  AND d.is_available IS NULL;

-- 2. Harden the sync_driver_job_assignment_availability trigger function
CREATE OR REPLACE FUNCTION public.sync_driver_job_assignment_availability()
RETURNS trigger AS $$
BEGIN
  IF NEW.status IN ('pending_offer', 'assigned', 'confirmed', 'in_progress') THEN
    UPDATE public.users SET is_available = false WHERE id = NEW.driver_id;
    UPDATE public.drivers SET is_available = false WHERE user_id = NEW.driver_id OR id = NEW.driver_id;
  ELSIF NEW.status IN ('rejected', 'cancelled', 'expired', 'completed', 'superseded') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.driver_job_assignments
      WHERE driver_id = NEW.driver_id
        AND id <> NEW.id
        AND status IN ('pending_offer', 'assigned', 'confirmed', 'in_progress')
    ) THEN
      UPDATE public.users SET is_available = true WHERE id = NEW.driver_id;
      UPDATE public.drivers SET is_available = true WHERE user_id = NEW.driver_id OR id = NEW.driver_id;
    END IF;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Ensure that any auxiliary availability update issues never abort the job assignment transaction
  RAISE WARNING 'sync_driver_job_assignment_availability caught error: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Ensure trigger is attached properly
DROP TRIGGER IF EXISTS trg_sync_driver_job_assignment_availability ON public.driver_job_assignments;
CREATE TRIGGER trg_sync_driver_job_assignment_availability
AFTER INSERT OR UPDATE OF status, driver_id ON public.driver_job_assignments
FOR EACH ROW
EXECUTE FUNCTION public.sync_driver_job_assignment_availability();

-- 4. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
