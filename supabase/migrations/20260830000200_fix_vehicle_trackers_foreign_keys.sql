-- Migration: Make vehicle_trackers foreign key constraints flexible for partner_vehicles, vehicles, and partner_vehicle_applications
-- Drop rigid foreign keys that trigger code 23503 when a partner vehicle ID or application ID is linked

ALTER TABLE public.vehicle_trackers DROP CONSTRAINT IF EXISTS vehicle_trackers_vehicle_id_fkey;
ALTER TABLE public.vehicle_trackers DROP CONSTRAINT IF EXISTS vehicle_trackers_partner_vehicle_id_fkey;
ALTER TABLE public.vehicle_trackers DROP CONSTRAINT IF EXISTS vehicle_trackers_vehicle_application_id_fkey;

-- Ensure columns are nullable and flexible
ALTER TABLE public.vehicle_trackers ALTER COLUMN vehicle_id DROP NOT NULL;
ALTER TABLE public.vehicle_trackers ALTER COLUMN partner_vehicle_id DROP NOT NULL;
ALTER TABLE public.vehicle_trackers ALTER COLUMN vehicle_application_id DROP NOT NULL;
