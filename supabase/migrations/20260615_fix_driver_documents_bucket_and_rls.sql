-- Repair driver document storage bucket name and restore user-scoped RLS
-- App upload path: driver_documents/<auth.uid()>/<document_type>_<timestamp>.<ext>

BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('driver_documents', 'driver_documents', true)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  public = EXCLUDED.public;

DROP POLICY IF EXISTS "driver_documents_insert_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "driver_documents_select_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "driver_documents_update_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "driver_documents_delete_own_folder" ON storage.objects;

CREATE POLICY "driver_documents_insert_own_folder"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'driver_documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "driver_documents_select_own_folder"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'driver_documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "driver_documents_update_own_folder"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'driver_documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'driver_documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "driver_documents_delete_own_folder"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'driver_documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

COMMIT;
