ALTER TABLE public.user_verifications
  DROP COLUMN IF EXISTS face_photo_url;

NOTIFY pgrst, 'reload schema';
