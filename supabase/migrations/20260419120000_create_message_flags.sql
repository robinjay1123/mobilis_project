-- Create message_flags table for tracking off-platform transaction attempts
BEGIN;

CREATE TABLE IF NOT EXISTS public.message_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID,
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  
  -- Flag details
  flag_reason TEXT NOT NULL,
  message_content TEXT,
  risk_score NUMERIC(3,2),
  risk_level TEXT CHECK (risk_level IN ('low', 'medium', 'high')),
  
  -- Review status
  status TEXT NOT NULL DEFAULT 'pending_review' 
    CHECK (status IN ('pending_review', 'confirmed', 'dismissed')),
  admin_notes TEXT,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TIMESTAMP WITH TIME ZONE
);

-- Update users table to track off-platform flag counts
ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS off_platform_flag_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT false;

-- Update messages table to track auto-generated messages
ALTER TABLE IF EXISTS public.messages
  ADD COLUMN IF NOT EXISTS is_auto_generated BOOLEAN DEFAULT false;

-- Update bookings table to track conversation creation
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS conversation_created BOOLEAN DEFAULT false;

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_message_flags_sender_id 
  ON public.message_flags(sender_id);

CREATE INDEX IF NOT EXISTS idx_message_flags_status 
  ON public.message_flags(status);

CREATE INDEX IF NOT EXISTS idx_message_flags_created_at 
  ON public.message_flags(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_auto_generated 
  ON public.messages(is_auto_generated) WHERE is_auto_generated = true;

-- Enable RLS
ALTER TABLE public.message_flags ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view flags on their conversations
CREATE POLICY message_flags_select_own
  ON public.message_flags FOR SELECT
  USING (
    auth.uid() = sender_id
    OR auth.uid() IN (
      SELECT id FROM public.users WHERE role = 'admin'
    )
  );

-- Only admins can review flags
CREATE POLICY message_flags_update_admin
  ON public.message_flags FOR UPDATE
  USING (
    auth.uid() IN (SELECT id FROM public.users WHERE role = 'admin')
  );

-- Function to check if user is blocked
CREATE OR REPLACE FUNCTION public.is_user_blocked(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    SELECT is_blocked FROM public.users 
    WHERE id = user_id
  );
END;
$$ LANGUAGE plpgsql;

COMMIT;
