-- Fix RLS policies for bookings - simplify INSERT policy
-- The previous policy was too restrictive and causing 42501 errors

BEGIN;

-- ============================================================================
-- Drop old restrictive policies
-- ============================================================================
DROP POLICY IF EXISTS bookings_insert_renter ON public.bookings;

-- ============================================================================
-- RENTER: INSERT new bookings (SIMPLIFIED)
-- ============================================================================
CREATE POLICY bookings_insert_renter
  ON public.bookings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Must be creating booking as themselves (renter_id = current user)
    renter_id = auth.uid()
  );

-- ============================================================================
-- RENTER: SELECT own bookings (KEEP AS IS)
-- ============================================================================
-- Already exists, no changes needed

-- ============================================================================
-- OPERATOR: SELECT bookings for their vehicles (SIMPLIFIED)
-- ============================================================================
DROP POLICY IF EXISTS bookings_select_operator_own ON public.bookings;
CREATE POLICY bookings_select_operator_own
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    -- User is owner or operator of the vehicle
    EXISTS (
      SELECT 1
      FROM public.vehicles v
      WHERE v.id = vehicle_id
        AND (v.owner_id = auth.uid() OR v.operator_id = auth.uid())
    )
  );

-- ============================================================================
-- OPERATOR: UPDATE bookings for their vehicles (SIMPLIFIED)
-- ============================================================================
DROP POLICY IF EXISTS bookings_update_operator_own ON public.bookings;
CREATE POLICY bookings_update_operator_own
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (
    -- User is owner or operator of the vehicle
    EXISTS (
      SELECT 1
      FROM public.vehicles v
      WHERE v.id = vehicle_id
        AND (v.owner_id = auth.uid() OR v.operator_id = auth.uid())
    )
  )
  WITH CHECK (
    -- Can only update if still own the vehicle
    EXISTS (
      SELECT 1
      FROM public.vehicles v
      WHERE v.id = vehicle_id
        AND (v.owner_id = auth.uid() OR v.operator_id = auth.uid())
    )
  );

COMMIT;
