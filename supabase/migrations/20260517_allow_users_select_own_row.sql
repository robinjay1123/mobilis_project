-- Allow authenticated users to read their own profile row.
-- This is required for role resolution and dashboard routing.

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select_own_row" ON public.users;
CREATE POLICY "users_select_own_row"
  ON public.users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);