-- Create user_verifications table for ID and face verification
BEGIN;

CREATE TABLE IF NOT EXISTS public.user_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  
  -- Document storage
  id_document_url TEXT,
  face_photo_url TEXT,
  
  -- Verification status
  verification_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending', 'verified', 'rejected')),
  
  -- Face matching
  face_match_percentage NUMERIC(5,2),
  
  -- Admin feedback
  rejection_reason TEXT,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  verified_at TIMESTAMP WITH TIME ZONE,
  
  -- Audit
  verified_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_user_verifications_user_id 
  ON public.user_verifications(user_id);

CREATE INDEX IF NOT EXISTS idx_user_verifications_status 
  ON public.user_verifications(verification_status);

CREATE INDEX IF NOT EXISTS idx_user_verifications_created_at 
  ON public.user_verifications(created_at DESC);

-- Enable RLS
ALTER TABLE public.user_verifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own verification
CREATE POLICY user_verifications_select_self
  ON public.user_verifications FOR SELECT
  USING (auth.uid() = user_id);

-- Only admins can update verifications
CREATE POLICY user_verifications_update_admin
  ON public.user_verifications FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT id FROM public.users WHERE role = 'admin'
    )
  );

-- Only admins can insert verifications (app inserts via service)
CREATE POLICY user_verifications_insert_authenticated
  ON public.user_verifications FOR INSERT
  WITH CHECK (true);

-- Sync function: update users.verification_status when verification status changes
CREATE OR REPLACE FUNCTION public.sync_user_verification_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the users table with verification status
  UPDATE public.users
  SET 
    verification_status = NEW.verification_status,
    id_verified = (NEW.verification_status = 'verified'),
    updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.user_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to sync verification status to users table
DROP TRIGGER IF EXISTS trigger_sync_user_verification_status 
  ON public.user_verifications;

CREATE TRIGGER trigger_sync_user_verification_status
  AFTER INSERT OR UPDATE ON public.user_verifications
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_user_verification_status();

COMMIT;
