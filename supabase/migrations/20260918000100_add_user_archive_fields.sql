-- Migration to add archive fields to public.users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS archived_at timestamp with time zone;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS archive_reason text;

-- Create index for fast filtering of active vs archived users
CREATE INDEX IF NOT EXISTS idx_users_is_archived ON public.users(is_archived);
