-- Prevent overlapping bookings for the same vehicle while the booking is still
-- pending, confirmed, or active.

BEGIN;

CREATE OR REPLACE FUNCTION public.is_vehicle_available_for_booking(
  p_vehicle_id uuid,
  p_start_date timestamp with time zone,
  p_end_date timestamp with time zone,
  p_exclude_booking_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.vehicle_id = p_vehicle_id
      AND (p_exclude_booking_id IS NULL OR b.id <> p_exclude_booking_id)
      AND lower(COALESCE(b.status, 'pending')) NOT IN (
        'cancelled',
        'canceled',
        'rejected',
        'completed'
      )
      AND b.start_date IS NOT NULL
      AND b.end_date IS NOT NULL
      AND p_start_date <= b.end_date
      AND p_end_date >= b.start_date
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_vehicle_available_for_booking(
  uuid,
  timestamp with time zone,
  timestamp with time zone,
  uuid
) TO authenticated;

CREATE OR REPLACE FUNCTION public.prevent_overlapping_bookings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.vehicle_id IS NULL OR NEW.start_date IS NULL OR NEW.end_date IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.end_date < NEW.start_date THEN
    RAISE EXCEPTION 'End date cannot be before start date'
      USING ERRCODE = '23514';
  END IF;

  IF lower(COALESCE(NEW.status, 'pending')) IN (
    'cancelled',
    'canceled',
    'rejected',
    'completed'
  ) THEN
    RETURN NEW;
  END IF;

  IF NOT public.is_vehicle_available_for_booking(
    NEW.vehicle_id,
    NEW.start_date,
    NEW.end_date,
    CASE WHEN TG_OP = 'UPDATE' THEN NEW.id ELSE NULL END
  ) THEN
    RAISE EXCEPTION 'Selected dates are unavailable for bookings'
      USING ERRCODE = '23P01';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_overlapping_bookings_trigger ON public.bookings;
CREATE TRIGGER prevent_overlapping_bookings_trigger
  BEFORE INSERT OR UPDATE OF vehicle_id, start_date, end_date, status
  ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_overlapping_bookings();

NOTIFY pgrst, 'reload schema';

COMMIT;
