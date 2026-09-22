-- Migration: Finalize Partner Vehicles Column Normalization
-- Description: Prunes isolated deprecated bloat columns from public.partner_vehicles
-- following complete client-side query modernization and trigger harmonization.

-- ============================================================================
-- 1. PRUNE DEPRECATED & DUPLICATE COLUMNS FROM public.partner_vehicles
-- ============================================================================

-- Prune hourly pricing column (rentals are strictly daily per pricing structure)
ALTER TABLE public.partner_vehicles DROP COLUMN IF EXISTS price_per_hour;

-- Prune duplicate category column (canonical vehicle_type holds type)
ALTER TABLE public.partner_vehicles DROP COLUMN IF EXISTS category;

-- Prune redundant owner role column (always partner by table definition)
ALTER TABLE public.partner_vehicles DROP COLUMN IF EXISTS owner_role;

-- Prune application status (canonical status belongs in partner_vehicle_applications)
ALTER TABLE public.partner_vehicles DROP COLUMN IF EXISTS application_status;
