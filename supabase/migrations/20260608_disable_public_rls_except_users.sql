-- Development-only reset: disable RLS for all public tables except users.
-- This keeps the users table protected while making the rest of the app
-- easier to iterate on without per-role policy churn.

BEGIN;

DO $$
DECLARE
  policy_record record;
BEGIN
  FOR policy_record IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename <> 'users'
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      policy_record.policyname,
      policy_record.schemaname,
      policy_record.tablename
    );
  END LOOP;
END $$;

DO $$
DECLARE
  table_record record;
BEGIN
  FOR table_record IN
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename <> 'users'
  LOOP
    EXECUTE format(
      'ALTER TABLE %I.%I DISABLE ROW LEVEL SECURITY',
      table_record.schemaname,
      table_record.tablename
    );
    EXECUTE format(
      'ALTER TABLE %I.%I NO FORCE ROW LEVEL SECURITY',
      table_record.schemaname,
      table_record.tablename
    );
  END LOOP;
END $$;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
