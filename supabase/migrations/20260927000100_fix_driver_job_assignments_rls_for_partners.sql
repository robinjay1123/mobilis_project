-- ==============================================================================
-- Migration: 20260927000100_fix_driver_job_assignments_rls_for_partners.sql
-- Description:
--   1. Create helper function `public.can_manage_booking(p_booking_id uuid)`
--      allowing staff (admin, superadmin, operator) AND booking vehicle owners /
--      partners to manage driver job assignments and trips for their bookings.
--   2. Update RLS policies on public.driver_job_assignments:
--      - SELECT: Staff, booking managers (partners/operators/owners), assigned driver, and renter.
--      - INSERT: Staff and booking managers (partners/operators/owners).
--      - UPDATE: Staff and booking managers, or the assigned driver (for accepting/rejecting/status).
--      - DELETE: Staff and booking managers.
--   3. Update RLS policies on public.driver_trips for partner visibility & management.
--   4. Add SECURITY DEFINER trigger on public.driver_job_assignments to automatically
--      sync driver availability (users.is_available & drivers.is_available).
-- ==============================================================================

-- 1. Helper function to check if the current user can manage a booking
CREATE OR REPLACE FUNCTION public.can_manage_booking(p_booking_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF p_booking_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- 1. Staff users (admin, superadmin, operator) have global management authority
  IF public.is_staff_user() THEN
    RETURN TRUE;
  END IF;

  -- 2. Check if current user is the partner, owner, or assigned operator for this specific booking
  RETURN EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE b.id = p_booking_id
      AND (
        b.operator_id = auth.uid()
        OR b.partner_id = auth.uid()
        OR b.owner_id = auth.uid()
        OR (b.metadata IS NOT NULL AND (
          b.metadata->>'partner_id' = auth.uid()::text
          OR b.metadata->>'owner_id' = auth.uid()::text
        ))
        -- Linkage via public.partners table
        OR (b.partner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid()))
        OR (b.owner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid()))
        OR (b.metadata IS NOT NULL AND (
          (b.metadata->>'partner_id') IN (SELECT p.id::text FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
          OR (b.metadata->>'owner_id') IN (SELECT p.id::text FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
        ))
        -- Linkage via partner_vehicles table
        OR EXISTS (
          SELECT 1 FROM public.partner_vehicles pv
          WHERE (pv.id = b.partner_vehicle_id OR pv.id = b.vehicle_id OR pv.vehicle_id = b.vehicle_id)
            AND (
              pv.partner_id = auth.uid()
              OR pv.user_id = auth.uid()
              OR pv.partner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
            )
        )
        -- Linkage via canonical vehicles table
        OR EXISTS (
          SELECT 1 FROM public.vehicles v
          WHERE v.id = b.vehicle_id
            AND (
              v.owner_id = auth.uid()
              OR v.operator_id = auth.uid()
              OR v.partner_id = auth.uid()
              OR v.owner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
            )
        )
      )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_manage_booking(uuid) TO authenticated, anon;

-- 2. Update RLS policies on public.driver_job_assignments
ALTER TABLE public.driver_job_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "driver_job_assignments_select" ON public.driver_job_assignments;
DROP POLICY IF EXISTS "driver_job_assignments_manage_staff" ON public.driver_job_assignments;
DROP POLICY IF EXISTS "driver_job_assignments_driver_reply" ON public.driver_job_assignments;
DROP POLICY IF EXISTS "driver_job_assignments_insert" ON public.driver_job_assignments;
DROP POLICY IF EXISTS "driver_job_assignments_update" ON public.driver_job_assignments;
DROP POLICY IF EXISTS "driver_job_assignments_delete" ON public.driver_job_assignments;
DROP POLICY IF EXISTS "driver_job_assignments_manage" ON public.driver_job_assignments;

-- SELECT policy: Staff, booking managers (partners/operators/owners), assigned driver, and booking renter
CREATE POLICY "driver_job_assignments_select"
  ON public.driver_job_assignments
  FOR SELECT
  TO authenticated
  USING (
    public.can_manage_booking(booking_id)
    OR driver_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = driver_job_assignments.booking_id
        AND b.renter_id = auth.uid()
    )
  );

-- INSERT policy: Staff and booking managers (partners/operators/owners)
CREATE POLICY "driver_job_assignments_insert"
  ON public.driver_job_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.can_manage_booking(booking_id)
  );

-- UPDATE policy: Staff, booking managers, or the assigned driver
CREATE POLICY "driver_job_assignments_update"
  ON public.driver_job_assignments
  FOR UPDATE
  TO authenticated
  USING (
    public.can_manage_booking(booking_id)
    OR driver_id = auth.uid()
  )
  WITH CHECK (
    public.can_manage_booking(booking_id)
    OR driver_id = auth.uid()
  );

-- DELETE policy: Staff and booking managers
CREATE POLICY "driver_job_assignments_delete"
  ON public.driver_job_assignments
  FOR DELETE
  TO authenticated
  USING (
    public.can_manage_booking(booking_id)
  );

-- 3. Update RLS policies on public.driver_trips
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'driver_trips') THEN
    ALTER TABLE public.driver_trips ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "driver_trips_select" ON public.driver_trips;
    DROP POLICY IF EXISTS "driver_trips_manage" ON public.driver_trips;

    CREATE POLICY "driver_trips_select"
      ON public.driver_trips
      FOR SELECT
      TO authenticated
      USING (
        public.can_manage_booking(booking_id)
        OR driver_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.bookings b
          WHERE b.id = driver_trips.booking_id
            AND b.renter_id = auth.uid()
        )
      );

    CREATE POLICY "driver_trips_manage"
      ON public.driver_trips
      FOR ALL
      TO authenticated
      USING (
        public.can_manage_booking(booking_id)
        OR driver_id = auth.uid()
      )
      WITH CHECK (
        public.can_manage_booking(booking_id)
        OR driver_id = auth.uid()
      );

    GRANT ALL ON TABLE public.driver_trips TO authenticated;
    GRANT ALL ON TABLE public.driver_trips TO service_role;
  END IF;
END $$;

-- 4. Trigger to automatically sync driver availability on assignment status changes
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_sync_driver_job_assignment_availability ON public.driver_job_assignments;
CREATE TRIGGER trg_sync_driver_job_assignment_availability
AFTER INSERT OR UPDATE OF status, driver_id ON public.driver_job_assignments
FOR EACH ROW
EXECUTE FUNCTION public.sync_driver_job_assignment_availability();

-- 5. Permissions & PostgREST reload
GRANT ALL ON TABLE public.driver_job_assignments TO authenticated;
GRANT ALL ON TABLE public.driver_job_assignments TO service_role;
NOTIFY pgrst, 'reload schema';
