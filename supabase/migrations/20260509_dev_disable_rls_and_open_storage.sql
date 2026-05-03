-- Development-only permissive mode
-- Disable RLS on all public tables and allow open uploads to vehicle_images bucket.

BEGIN;

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY;', r.tablename);
  END LOOP;
END $$;

-- Make sure the vehicle_images bucket exists and is public for development
UPDATE storage.buckets
SET public = true
WHERE id = 'vehicle_images';

-- Allow any client to upload/list/read objects in the vehicle_images bucket
DROP POLICY IF EXISTS "dev_allow_all_vehicle_images" ON storage.objects;
CREATE POLICY "dev_allow_all_vehicle_images"
  ON storage.objects
  FOR ALL
  TO public
  USING (bucket_id = 'vehicle_images')
  WITH CHECK (bucket_id = 'vehicle_images');

COMMIT;
