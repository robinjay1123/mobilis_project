-- Migration: Add user_metadata, raw_user_meta_data, and mpin columns to public.users
-- This ensures that any queries requesting user_metadata or mpin columns succeed without throwing PostgrestException 42703

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS user_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS raw_user_meta_data jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS mpin_enabled boolean DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS mpin_hash text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS mpin_salt text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS mpin_updated_at text;
