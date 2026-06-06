BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('partner_documents', 'partner_documents', true)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  public = EXCLUDED.public;

DROP POLICY IF EXISTS "partner_documents_insert_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "partner_documents_select_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "partner_documents_update_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "partner_documents_delete_own_folder" ON storage.objects;

CREATE POLICY "partner_documents_insert_own_folder"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'partner_documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "partner_documents_select_own_folder"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'partner_documents'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR EXISTS (
        SELECT 1
        FROM public.users
        WHERE users.id = auth.uid()
          AND users.role = 'admin'
      )
    )
  );

CREATE POLICY "partner_documents_update_own_folder"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'partner_documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'partner_documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "partner_documents_delete_own_folder"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'partner_documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DO $$
BEGIN
  IF to_regclass('public.partner_vehicle_applications') IS NOT NULL THEN
    ALTER TABLE public.partner_vehicle_applications ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS partner_vehicle_applications_select_own ON public.partner_vehicle_applications;
    DROP POLICY IF EXISTS partner_vehicle_applications_insert_own ON public.partner_vehicle_applications;
    DROP POLICY IF EXISTS partner_vehicle_applications_update_own ON public.partner_vehicle_applications;
    DROP POLICY IF EXISTS partner_vehicle_applications_select_admin_all ON public.partner_vehicle_applications;
    DROP POLICY IF EXISTS partner_vehicle_applications_update_admin_all ON public.partner_vehicle_applications;

    CREATE POLICY partner_vehicle_applications_select_own
      ON public.partner_vehicle_applications
      FOR SELECT
      TO authenticated
      USING (
        partner_id = auth.uid()
      );

    CREATE POLICY partner_vehicle_applications_insert_own
      ON public.partner_vehicle_applications
      FOR INSERT
      TO authenticated
      WITH CHECK (
        partner_id = auth.uid()
      );

    CREATE POLICY partner_vehicle_applications_update_own
      ON public.partner_vehicle_applications
      FOR UPDATE
      TO authenticated
      USING (
        partner_id = auth.uid()
      )
      WITH CHECK (
        partner_id = auth.uid()
      );

    CREATE POLICY partner_vehicle_applications_select_admin_all
      ON public.partner_vehicle_applications
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM public.users
          WHERE users.id = auth.uid()
            AND users.role = 'admin'
        )
      );

    CREATE POLICY partner_vehicle_applications_update_admin_all
      ON public.partner_vehicle_applications
      FOR UPDATE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM public.users
          WHERE users.id = auth.uid()
            AND users.role = 'admin'
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1
          FROM public.users
          WHERE users.id = auth.uid()
            AND users.role = 'admin'
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.partner_vehicle_documents') IS NOT NULL THEN
    ALTER TABLE public.partner_vehicle_documents ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS partner_vehicle_documents_select_admin_all ON public.partner_vehicle_documents;
    DROP POLICY IF EXISTS partner_vehicle_documents_insert_admin_all ON public.partner_vehicle_documents;

    CREATE POLICY partner_vehicle_documents_select_admin_all
      ON public.partner_vehicle_documents
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM public.users
          WHERE users.id = auth.uid()
            AND users.role = 'admin'
        )
      );

    CREATE POLICY partner_vehicle_documents_insert_admin_all
      ON public.partner_vehicle_documents
      FOR INSERT
      TO authenticated
      WITH CHECK (
        EXISTS (
          SELECT 1
          FROM public.users
          WHERE users.id = auth.uid()
            AND users.role = 'admin'
        )
      );
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;
