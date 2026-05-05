-- Storage RLS policies for identity images
-- Supports uploads to: verifications/<auth.uid()>/...

BEGIN;

-- Ensure bucket exists (kept public so generated public URLs remain accessible)
INSERT INTO storage.buckets (id, name, public)
VALUES ('id_images', 'id_images', true)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  public = EXCLUDED.public;

-- Remove old policies if they exist
DROP POLICY IF EXISTS "id_images_insert_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "id_images_select_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "id_images_update_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "id_images_delete_own_folder" ON storage.objects;

-- Allow authenticated users to upload only inside their own folder
CREATE POLICY "id_images_insert_own_folder"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'id_images'
    AND (storage.foldername(name))[1] = 'verifications'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- Allow authenticated users to list/read only their own files
CREATE POLICY "id_images_select_own_folder"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'id_images'
    AND (storage.foldername(name))[1] = 'verifications'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- Allow authenticated users to update only their own files
CREATE POLICY "id_images_update_own_folder"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'id_images'
    AND (storage.foldername(name))[1] = 'verifications'
    AND (storage.foldername(name))[2] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'id_images'
    AND (storage.foldername(name))[1] = 'verifications'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- Allow authenticated users to delete only their own files
CREATE POLICY "id_images_delete_own_folder"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'id_images'
    AND (storage.foldername(name))[1] = 'verifications'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

COMMIT;
