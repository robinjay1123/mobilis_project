-- Migration: Add optional cleaning turnaround timestamp columns to vehicles and partner_vehicles
ALTER TABLE IF EXISTS public.vehicles 
ADD COLUMN IF NOT EXISTS cleaning_until timestamptz,
ADD COLUMN IF NOT EXISTS auto_relist_at timestamptz;

ALTER TABLE IF EXISTS public.partner_vehicles 
ADD COLUMN IF NOT EXISTS cleaning_until timestamptz,
ADD COLUMN IF NOT EXISTS auto_relist_at timestamptz;
