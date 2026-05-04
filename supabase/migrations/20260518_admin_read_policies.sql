-- Admin read access for dashboard analytics and moderation views.

CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS users_select_admin_all ON public.users;
CREATE POLICY users_select_admin_all
  ON public.users
  FOR SELECT
  TO authenticated
  USING (public.is_admin_user());

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vehicles_select_admin_all ON public.vehicles;
CREATE POLICY vehicles_select_admin_all
  ON public.vehicles
  FOR SELECT
  TO authenticated
  USING (public.is_admin_user());

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bookings_select_admin_all ON public.bookings;
CREATE POLICY bookings_select_admin_all
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (public.is_admin_user());

ALTER TABLE public.user_verifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_verifications_select_admin_all ON public.user_verifications;
CREATE POLICY user_verifications_select_admin_all
  ON public.user_verifications
  FOR SELECT
  TO authenticated
  USING (public.is_admin_user());