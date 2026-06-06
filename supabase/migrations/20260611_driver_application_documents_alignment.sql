-- Align driver application schema with app flow:
-- users(role=driver) -> drivers(user_id) -> driver_documents(driver_id)
-- and add license_url for uploaded driver license image.

BEGIN;

ALTER TABLE IF EXISTS public.drivers
  ADD COLUMN IF NOT EXISTS license_url text;

CREATE TABLE IF NOT EXISTS public.driver_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  document_type character varying NOT NULL,
  file_url character varying NOT NULL,
  issue_date date NOT NULL,
  expiry_date date NOT NULL,
  status character varying DEFAULT 'pending',
  admin_notes text,
  verified_at timestamp without time zone,
  verified_by uuid REFERENCES public.users(id),
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_driver_documents_driver_id
  ON public.driver_documents(driver_id);

CREATE INDEX IF NOT EXISTS idx_driver_documents_status
  ON public.driver_documents(status);

NOTIFY pgrst, 'reload schema';

COMMIT;

