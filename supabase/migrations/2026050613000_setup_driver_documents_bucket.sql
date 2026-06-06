-- Setup driver_documents storage bucket for license and NBI uploads
-- Structure: driver_documents/<driver_id>/<document_type>_<timestamp>.<ext>

BEGIN;

-- Create drivers_documents bucket (public so URLs are accessible)
INSERT INTO storage.buckets (id, name, public)
VALUES ('drivers_documents', 'drivers_documents', true)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  public = EXCLUDED.public;

-- Note: RLS policies are disabled by default as per user preference
-- All authenticated users can read/write to this bucket during development

COMMIT;
