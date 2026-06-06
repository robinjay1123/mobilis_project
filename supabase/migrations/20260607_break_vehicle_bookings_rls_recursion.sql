-- Break the vehicles <-> bookings RLS recursion introduced by the driver
-- vehicle visibility policy. Renters fetching posted vehicles should not have
-- to traverse bookings policies.

BEGIN;

CREATE OR REPLACE FUNCTION public.is_assigned_driver_for_vehicle(
  p_vehicle_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.vehicle_id = p_vehicle_id
      AND b.driver_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_assigned_driver_for_vehicle(uuid) TO authenticated;

DROP POLICY IF EXISTS vehicles_select_assigned_driver ON public.vehicles;
CREATE POLICY vehicles_select_assigned_driver
  ON public.vehicles
  FOR SELECT
  TO authenticated
  USING (
    public.is_assigned_driver_for_vehicle(id)
  );

NOTIFY pgrst, 'reload schema';

COMMIT;
