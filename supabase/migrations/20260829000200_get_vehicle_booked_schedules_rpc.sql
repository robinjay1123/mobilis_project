-- Function to safely return booked date/time ranges for a vehicle to all users (renters/operators/drivers)
-- without exposing any sensitive renter personal/financial data.
CREATE OR REPLACE FUNCTION "public"."get_vehicle_booked_schedules"("p_vehicle_id" "uuid")
RETURNS TABLE(
  start_at timestamp with time zone,
  end_at timestamp with time zone,
  start_date text,
  end_date text,
  status text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    b.start_at,
    b.end_at,
    b.start_date::text,
    b.end_date::text,
    b.status
  FROM public.bookings b
  WHERE (b.vehicle_id = p_vehicle_id OR b.partner_vehicle_id = p_vehicle_id)
    AND lower(COALESCE(b.status, 'pending')) NOT IN (
      'cancelled',
      'canceled',
      'rejected',
      'completed'
    )
    AND b.start_at IS NOT NULL
    AND b.end_at IS NOT NULL;
$$;

GRANT ALL ON FUNCTION "public"."get_vehicle_booked_schedules"("p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_vehicle_booked_schedules"("p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_vehicle_booked_schedules"("p_vehicle_id" "uuid") TO "service_role";

-- Ensure is_vehicle_available_for_booking checks both vehicle_id and partner_vehicle_id
CREATE OR REPLACE FUNCTION "public"."is_vehicle_available_for_booking"(
  "p_vehicle_id" "uuid",
  "p_start_date" timestamp with time zone,
  "p_end_date" timestamp with time zone,
  "p_exclude_booking_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE (b.vehicle_id = p_vehicle_id OR b.partner_vehicle_id = p_vehicle_id)
      AND (p_exclude_booking_id IS NULL OR b.id <> p_exclude_booking_id)
      AND lower(COALESCE(b.status, 'pending')) NOT IN (
        'cancelled',
        'canceled',
        'rejected',
        'completed'
      )
      AND b.start_at IS NOT NULL
      AND b.end_at IS NOT NULL
      AND p_start_date < b.end_at
      AND p_end_date > b.start_at
  );
$$;

GRANT ALL ON FUNCTION "public"."is_vehicle_available_for_booking"("p_vehicle_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_exclude_booking_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_vehicle_available_for_booking"("p_vehicle_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_exclude_booking_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_vehicle_available_for_booking"("p_vehicle_id" "uuid", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_exclude_booking_id" "uuid") TO "service_role";
