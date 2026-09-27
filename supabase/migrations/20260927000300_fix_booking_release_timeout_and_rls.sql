-- ==============================================================================
-- Migration: 20260927000300_fix_booking_release_timeout_and_rls.sql
-- Description: 
--   1. Drop obsolete recursive payment-booking sync triggers that cause statement timeout (code 57014)
--   2. Streamline RLS policies on public.bookings (UPDATE and SELECT) using can_manage_booking()
--   3. Ensure recursion guard on fn_sync_payment_to_booking
-- ==============================================================================

-- 1. Drop deadlocking legacy triggers on bookings table
DROP TRIGGER IF EXISTS trg_sync_booking_to_payment ON public.bookings;
DROP FUNCTION IF EXISTS public.fn_sync_booking_to_payment();

-- 2. Streamline and accelerate RLS for UPDATE on public.bookings
DROP POLICY IF EXISTS "bookings_update_participants" ON public.bookings;
CREATE POLICY "bookings_update_participants"
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR driver_id = auth.uid()
    OR operator_id = auth.uid()
    OR partner_id = auth.uid()
    OR owner_id = auth.uid()
    OR public.can_manage_booking(id)
  )
  WITH CHECK (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR driver_id = auth.uid()
    OR operator_id = auth.uid()
    OR partner_id = auth.uid()
    OR owner_id = auth.uid()
    OR public.can_manage_booking(id)
  );

-- 3. Streamline and accelerate RLS for SELECT on public.bookings
DROP POLICY IF EXISTS "bookings_select_participants" ON public.bookings;
CREATE POLICY "bookings_select_participants"
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR driver_id = auth.uid()
    OR operator_id = auth.uid()
    OR partner_id = auth.uid()
    OR owner_id = auth.uid()
    OR public.can_manage_booking(id)
  );

-- 4. Harden payment-to-booking sync function against trigger recursion
CREATE OR REPLACE FUNCTION public.fn_sync_payment_to_booking()
RETURNS TRIGGER AS $$
DECLARE
  v_booking_id UUID;
  v_total_paid NUMERIC(12, 2) := 0.00;
  v_latest_id UUID;
  v_latest_at TIMESTAMPTZ;
  v_booking_total NUMERIC(12, 2) := 0.00;
BEGIN
  -- Prevent infinite recursion
  IF pg_trigger_depth() > 1 THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  v_booking_id := COALESCE(NEW.booking_id, OLD.booking_id);
  IF v_booking_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT COALESCE(SUM(amount), 0.00)
  INTO v_total_paid
  FROM public.payments
  WHERE booking_id = v_booking_id
    AND status IN ('verified', 'approved', 'paid')
    AND payment_type != 'refund';

  SELECT id, created_at
  INTO v_latest_id, v_latest_at
  FROM public.payments
  WHERE booking_id = v_booking_id
  ORDER BY created_at DESC
  LIMIT 1;

  SELECT COALESCE(total_price, 0.00)
  INTO v_booking_total
  FROM public.bookings
  WHERE id = v_booking_id;

  UPDATE public.bookings
  SET
    total_paid_amount = v_total_paid,
    last_payment_id = v_latest_id,
    last_payment_at = v_latest_at,
    payment_status = CASE
      WHEN v_total_paid >= v_booking_total AND v_booking_total > 0 THEN 'paid'
      WHEN v_total_paid > 0 THEN 'partially_paid'
      ELSE payment_status
    END
  WHERE id = v_booking_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
