-- Ensure assigned drivers can fetch their active assigned bookings and the
-- basic vehicle/renter details needed by the driver Jobs tab.

BEGIN;

DROP POLICY IF EXISTS bookings_select_driver ON public.bookings;
CREATE POLICY bookings_select_driver
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    driver_id = auth.uid()
    OR (
      driver_id = auth.uid()
      AND lower(COALESCE(status, 'pending')) IN (
        'approved',
        'confirmed',
        'active',
        'completed'
      )
    )
  );

DROP POLICY IF EXISTS vehicles_select_assigned_driver ON public.vehicles;
CREATE POLICY vehicles_select_assigned_driver
  ON public.vehicles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.bookings b
      WHERE b.vehicle_id = public.vehicles.id
        AND b.driver_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS users_select_assigned_booking_driver ON public.users;
CREATE POLICY users_select_assigned_booking_driver
  ON public.users
  FOR SELECT
  TO authenticated
  USING (
    id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.bookings b
      WHERE b.renter_id = public.users.id
        AND b.driver_id = auth.uid()
    )
  );

NOTIFY pgrst, 'reload schema';

COMMIT;
