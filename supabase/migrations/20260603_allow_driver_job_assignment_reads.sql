-- Allow drivers to read their own job assignment rows so the Jobs tab can
-- fall back to assignment records when needed.

BEGIN;

DROP POLICY IF EXISTS driver_job_assignments_select_own ON public.driver_job_assignments;
CREATE POLICY driver_job_assignments_select_own
  ON public.driver_job_assignments
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

DROP POLICY IF EXISTS driver_job_assignments_update_own ON public.driver_job_assignments;
CREATE POLICY driver_job_assignments_update_own
  ON public.driver_job_assignments
  FOR UPDATE
  TO authenticated
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());

NOTIFY pgrst, 'reload schema';

COMMIT;
