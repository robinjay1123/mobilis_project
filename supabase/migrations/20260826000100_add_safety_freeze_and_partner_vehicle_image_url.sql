-- Migration: Add safety_freeze to bookings and image_url to partner_vehicles
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS safety_freeze BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_bookings_safety_freeze
  ON public.bookings(safety_freeze)
  WHERE safety_freeze IS TRUE;

ALTER TABLE IF EXISTS public.partner_vehicles
  ADD COLUMN IF NOT EXISTS image_url TEXT;
