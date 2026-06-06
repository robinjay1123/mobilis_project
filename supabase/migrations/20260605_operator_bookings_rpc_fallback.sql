-- Provide a security-definer fallback for the operator bookings screen so it
-- can load bookings even when overlapping RLS policies drift.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_operator_bookings()
RETURNS SETOF public.bookings
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT b.*
  FROM public.bookings b
  WHERE public.is_operator_user()
     OR b.vehicle_id IN (
       SELECT v.id
       FROM public.vehicles v
       WHERE v.owner_id = auth.uid()
          OR v.operator_id = auth.uid()
     )
  ORDER BY b.created_at DESC
  LIMIT 100;
$$;

GRANT EXECUTE ON FUNCTION public.get_operator_bookings() TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
