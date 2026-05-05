-- Fix verification submission failures on schemas where public.users has no updated_at column.
-- The verification trigger should sync status fields only.

CREATE OR REPLACE FUNCTION public.sync_user_verification_status()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.users
  SET
    verification_status = NEW.verification_status,
    id_verified = (NEW.verification_status = 'verified')
  WHERE id = NEW.user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;