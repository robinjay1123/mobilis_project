-- Fix RLS policy for operators to view bookings for their vehicles
-- Ensures operators can see all bookings for vehicles they own (owner_id)

BEGIN;

-- Drop the problematic policy that uses function call
DROP POLICY IF EXISTS bookings_select_operator_own ON public.bookings;

-- Create a simpler, direct policy without function calls
CREATE POLICY bookings_select_operator_own
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    -- Operator/owner can select bookings for vehicles they own
    vehicle_id IN (
      SELECT id
      FROM public.vehicles
      WHERE owner_id = auth.uid()
    )
  );

COMMIT;
