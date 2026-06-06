-- Match the app's AuthService.getUserRole behavior: operator role can be
-- resolved either by auth uid or by the authenticated email fallback.

BEGIN;

CREATE OR REPLACE FUNCTION public.is_operator_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE role = 'operator'
      AND (
        id = auth.uid()
        OR lower(email) = lower(auth.jwt() ->> 'email')
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_operator_user() TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
