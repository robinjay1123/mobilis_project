-- Reassert operator read access needed by the operator bookings screen.
-- This avoids depending on older policy state from several overlapping
-- migrations.

BEGIN;

CREATE OR REPLACE FUNCTION public.is_operator_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE role = 'operator'
      AND (
        id = auth.uid()
        OR lower(email) = lower(auth.jwt() ->> 'email')
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_operator_user() TO authenticated;

DROP POLICY IF EXISTS bookings_select_operator_own ON public.bookings;
DROP POLICY IF EXISTS bookings_select_operator_all ON public.bookings;
CREATE POLICY bookings_select_operator_all
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    public.is_operator_user()
    OR vehicle_id IN (
      SELECT id
      FROM public.vehicles
      WHERE owner_id = auth.uid()
         OR operator_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS users_select_operator_all ON public.users;
CREATE POLICY users_select_operator_all
  ON public.users
  FOR SELECT
  TO authenticated
  USING (
    public.is_operator_user()
    OR auth.uid() = id
  );

DROP POLICY IF EXISTS vehicles_select_operator_all ON public.vehicles;
CREATE POLICY vehicles_select_operator_all
  ON public.vehicles
  FOR SELECT
  TO authenticated
  USING (
    public.is_operator_user()
    OR owner_id = auth.uid()
    OR operator_id = auth.uid()
  );

NOTIFY pgrst, 'reload schema';

COMMIT;
