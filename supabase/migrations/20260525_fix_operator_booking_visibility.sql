-- Restore operator booking visibility for vehicles assigned through operator_id.
-- The previous policy only checked owner_id, so assigned operators could not
-- fetch bookings for partner/operator-managed vehicles.

BEGIN;

DROP POLICY IF EXISTS bookings_select_operator_own ON public.bookings;
CREATE POLICY bookings_select_operator_own
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    vehicle_id IN (
      SELECT id
      FROM public.vehicles
      WHERE owner_id = auth.uid()
         OR operator_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS bookings_update_operator_own ON public.bookings;
CREATE POLICY bookings_update_operator_own
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (
    vehicle_id IN (
      SELECT id
      FROM public.vehicles
      WHERE owner_id = auth.uid()
         OR operator_id = auth.uid()
    )
  )
  WITH CHECK (
    vehicle_id IN (
      SELECT id
      FROM public.vehicles
      WHERE owner_id = auth.uid()
         OR operator_id = auth.uid()
    )
  );

COMMIT;
