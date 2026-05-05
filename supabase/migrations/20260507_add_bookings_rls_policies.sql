-- Add RLS policies for complete booking workflow:
-- - Renters: INSERT, SELECT own bookings
-- - Operators: SELECT, UPDATE bookings for their vehicles
-- - Admins: Full access (already exists)

BEGIN;

-- ============================================================================
-- Helper function to check if user owns a vehicle
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_vehicle_owner(vehicle_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.vehicles
    WHERE id = vehicle_id
      AND owner_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_vehicle_owner(uuid) TO authenticated;

-- ============================================================================
-- Helper function to check if user is vehicle operator
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_vehicle_operator(vehicle_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.vehicles
    WHERE id = vehicle_id
      AND (owner_id = auth.uid() OR operator_id = auth.uid())
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_vehicle_operator(uuid) TO authenticated;

-- ============================================================================
-- RENTER: INSERT new bookings
-- ============================================================================
DROP POLICY IF EXISTS bookings_insert_renter ON public.bookings;
CREATE POLICY bookings_insert_renter
  ON public.bookings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Only renters with role='renter' can insert
    (SELECT role FROM public.users WHERE id = auth.uid()) = 'renter'
    -- Must be creating booking as themselves (renter_id = current user)
    AND renter_id = auth.uid()
    -- Vehicle must exist and be posted
    AND EXISTS (
      SELECT 1
      FROM public.vehicles
      WHERE id = vehicle_id
        AND is_posted = true
    )
  );

-- ============================================================================
-- RENTER: SELECT own bookings
-- ============================================================================
DROP POLICY IF EXISTS bookings_select_renter_own ON public.bookings;
CREATE POLICY bookings_select_renter_own
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    renter_id = auth.uid()
  );

-- ============================================================================
-- OPERATOR: SELECT bookings for their vehicles
-- ============================================================================
DROP POLICY IF EXISTS bookings_select_operator_own ON public.bookings;
CREATE POLICY bookings_select_operator_own
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    -- User is operator/owner of the vehicle in this booking
    public.is_vehicle_operator(vehicle_id)
  );

-- ============================================================================
-- OPERATOR: UPDATE bookings for their vehicles
-- (approve, reject, assign driver, update notes, etc.)
-- ============================================================================
DROP POLICY IF EXISTS bookings_update_operator_own ON public.bookings;
CREATE POLICY bookings_update_operator_own
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (
    -- User is operator/owner of the vehicle in this booking
    public.is_vehicle_operator(vehicle_id)
  )
  WITH CHECK (
    -- Can only update if still own the vehicle
    public.is_vehicle_operator(vehicle_id)
  );

-- ============================================================================
-- ADMIN: Full access (SELECT already exists)
-- ============================================================================
-- Admin INSERT policy
DROP POLICY IF EXISTS bookings_insert_admin ON public.bookings;
CREATE POLICY bookings_insert_admin
  ON public.bookings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_admin_user()
  );

-- Admin UPDATE policy
DROP POLICY IF EXISTS bookings_update_admin ON public.bookings;
CREATE POLICY bookings_update_admin
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (
    public.is_admin_user()
  )
  WITH CHECK (
    public.is_admin_user()
  );

-- Admin DELETE policy
DROP POLICY IF EXISTS bookings_delete_admin ON public.bookings;
CREATE POLICY bookings_delete_admin
  ON public.bookings
  FOR DELETE
  TO authenticated
  USING (
    public.is_admin_user()
  );

-- ============================================================================
-- DRIVER: SELECT bookings assigned to them (if they are drivers)
-- ============================================================================
DROP POLICY IF EXISTS bookings_select_driver ON public.bookings;
CREATE POLICY bookings_select_driver
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    -- User is assigned as driver in this booking
    driver_id = auth.uid()
      AND (SELECT role FROM public.users WHERE id = auth.uid()) = 'driver'
  );

COMMIT;
