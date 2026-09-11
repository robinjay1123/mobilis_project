-- ============================================================================
-- Migration: 20260911000300_reset_initial_vehicle_ratings_to_zero.sql
-- Description:
--   1. Ensure vehicles and partner_vehicles columns default to 0.0 rating and 0 count.
--   2. Reset all vehicles without genuine completed trip_ratings to 0.0 (count = 0).
--   3. Re-aggregate real ratings and counts for vehicles that have actual trip_ratings.
-- ============================================================================

-- 1. Ensure vehicles table default rating is 0.0 and rating_count is 0
ALTER TABLE IF EXISTS public.vehicles 
  ALTER COLUMN rating SET DEFAULT 0.0;

ALTER TABLE IF EXISTS public.vehicles 
  ALTER COLUMN rating_count SET DEFAULT 0;

-- 2. Ensure partner_vehicles table has rating & rating_count columns with 0.0 / 0 defaults
ALTER TABLE IF EXISTS public.partner_vehicles 
  ADD COLUMN IF NOT EXISTS rating numeric(3, 2) DEFAULT 0.0;

ALTER TABLE IF EXISTS public.partner_vehicles 
  ADD COLUMN IF NOT EXISTS rating_count integer DEFAULT 0;

ALTER TABLE IF EXISTS public.partner_vehicles 
  ALTER COLUMN rating SET DEFAULT 0.0;

ALTER TABLE IF EXISTS public.partner_vehicles 
  ALTER COLUMN rating_count SET DEFAULT 0;

-- 3. Reset all vehicles and partner_vehicles to 0.0 rating and 0 count initially
UPDATE public.vehicles
SET 
  rating = 0.0,
  rating_count = 0;

UPDATE public.partner_vehicles
SET 
  rating = 0.0,
  rating_count = 0;

-- 4. Re-calculate genuine ratings and counts from public.trip_ratings where target_role = 'vehicle'
WITH vehicle_aggregates AS (
  SELECT
    target_user_id AS vehicle_id,
    ROUND(AVG(rating)::numeric, 2) AS avg_rating,
    COUNT(*)::integer AS rev_count
  FROM public.trip_ratings
  WHERE target_role = 'vehicle'
  GROUP BY target_user_id
)
UPDATE public.vehicles v
SET
  rating = va.avg_rating,
  rating_count = va.rev_count
FROM vehicle_aggregates va
WHERE v.id = va.vehicle_id;

WITH partner_vehicle_aggregates AS (
  SELECT
    target_user_id AS vehicle_id,
    ROUND(AVG(rating)::numeric, 2) AS avg_rating,
    COUNT(*)::integer AS rev_count
  FROM public.trip_ratings
  WHERE target_role = 'vehicle'
  GROUP BY target_user_id
)
UPDATE public.partner_vehicles pv
SET
  rating = pva.avg_rating,
  rating_count = pva.rev_count
FROM partner_vehicle_aggregates pva
WHERE pv.id = pva.vehicle_id;
