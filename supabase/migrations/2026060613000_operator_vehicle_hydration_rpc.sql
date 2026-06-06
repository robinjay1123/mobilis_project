-- Provide a security-definer fallback for operator-side vehicle hydration on
-- booking cards.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_operator_booking_vehicles(
  p_vehicle_ids uuid[]
)
RETURNS TABLE (
  id uuid,
  brand text,
  model text,
  year integer,
  owner_id uuid,
  vehicle_name text,
  price_per_day numeric
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    v.id,
    v.brand::text,
    v.model::text,
    v.year,
    v.owner_id,
    v.vehicle_name::text,
    v.price_per_day
  FROM public.vehicles v
  WHERE v.id = ANY(COALESCE(p_vehicle_ids, ARRAY[]::uuid[]))
    AND (
      public.is_operator_user()
      OR v.owner_id = auth.uid()
      OR v.operator_id = auth.uid()
    );
$$;

GRANT EXECUTE ON FUNCTION public.get_operator_booking_vehicles(uuid[]) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
