-- Enable Row Level Security on vehicles and add operator-only policies
-- Run with: supabase db push

-- Enable RLS (idempotent)
ALTER TABLE IF EXISTS public.vehicles ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to INSERT vehicles (no strict role check for debugging)
DROP POLICY IF EXISTS allow_operators_insert_vehicles ON public.vehicles;
CREATE POLICY allow_operators_insert_vehicles
  ON public.vehicles
  FOR INSERT
  TO authenticated
  WITH CHECK (owner_id = auth.uid());

-- Allow operators to SELECT their own vehicles OR allow public SELECT on posted vehicles
DROP POLICY IF EXISTS allow_operators_select_vehicles ON public.vehicles;
CREATE POLICY allow_operators_select_vehicles
  ON public.vehicles
  FOR SELECT
  TO authenticated
  USING (
    owner_id = auth.uid()
    OR is_posted = true
  );

DROP POLICY IF EXISTS allow_public_select_posted_vehicles ON public.vehicles;
CREATE POLICY allow_public_select_posted_vehicles
  ON public.vehicles
  FOR SELECT
  TO public
  USING (
    is_posted = true
  );

-- Allow authenticated users to UPDATE only their own vehicles (no strict role check for debugging)
DROP POLICY IF EXISTS allow_operators_update_vehicles ON public.vehicles;
CREATE POLICY allow_operators_update_vehicles
  ON public.vehicles
  FOR UPDATE
  TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Allow operators to DELETE only their own vehicles
DROP POLICY IF EXISTS allow_operators_delete_vehicles ON public.vehicles;
CREATE POLICY allow_operators_delete_vehicles
  ON public.vehicles
  FOR DELETE
  TO authenticated
  USING (
    owner_id = auth.uid()
  );

-- Note: Adapt role checks if your users table stores roles differently.
