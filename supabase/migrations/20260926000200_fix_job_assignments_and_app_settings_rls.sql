-- ==============================================================================
-- Migration: 20260926000200_fix_job_assignments_and_app_settings_rls.sql
-- Description:
-- 1. Add rejection_reason column to driver_job_assignments to prevent PostgREST errors.
-- 2. Allow operators and administrators to manage app_settings (desk operator MPIN sync).
-- ==============================================================================

-- 1. Add rejection_reason to driver_job_assignments
ALTER TABLE public.driver_job_assignments 
  ADD COLUMN IF NOT EXISTS rejection_reason text;

-- 2. Ensure RLS policies on app_settings allow both admin and operator roles
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'app_settings') THEN
    ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

    -- Ensure SELECT is open to all authenticated and anon users
    DROP POLICY IF EXISTS "app_settings_select_public" ON public.app_settings;
    DROP POLICY IF EXISTS "app_settings_select_authenticated" ON public.app_settings;
    CREATE POLICY "app_settings_select_public" 
      ON public.app_settings 
      FOR SELECT 
      TO authenticated, anon 
      USING (true);

    -- Allow admins, superadmins, and operators to insert/update settings (such as desk_operator_mpins)
    DROP POLICY IF EXISTS "app_settings_manage_admin" ON public.app_settings;
    DROP POLICY IF EXISTS "app_settings_insert_admin" ON public.app_settings;
    DROP POLICY IF EXISTS "app_settings_update_admin" ON public.app_settings;
    DROP POLICY IF EXISTS "app_settings_delete_admin" ON public.app_settings;

    CREATE POLICY "app_settings_manage_staff" 
      ON public.app_settings 
      FOR ALL 
      TO authenticated 
      USING (
        EXISTS (
          SELECT 1 FROM public.users u
          WHERE (u.id = auth.uid() OR lower(u.email) = lower(auth.jwt() ->> 'email'))
            AND u.role IN ('admin', 'superadmin', 'operator')
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.users u
          WHERE (u.id = auth.uid() OR lower(u.email) = lower(auth.jwt() ->> 'email'))
            AND u.role IN ('admin', 'superadmin', 'operator')
        )
      );

    GRANT ALL ON TABLE public.app_settings TO authenticated;
    GRANT ALL ON TABLE public.app_settings TO service_role;
  END IF;
END $$;
