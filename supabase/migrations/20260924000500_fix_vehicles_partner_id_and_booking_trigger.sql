-- ==============================================================================
-- Migration: 20260924000500_fix_vehicles_partner_id_and_booking_trigger.sql
-- Description:
--   1. Adds partner_id column to public.vehicles and creates index.
--   2. Backfills partner_id on public.vehicles from partner_vehicles and partners.
--   3. Fixes public.sync_booking_partner_linkage() function so it safely resolves
--      owner_id and partner_id without failing if partner_id is missing or null,
--      preventing Postgres error 42703 "column v.partner_id does not exist".
--   4. Backfills partner_id on public.bookings from public.vehicles.
-- ==============================================================================

-- 1. Ensure partner_id column exists on public.vehicles
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS partner_id uuid;
CREATE INDEX IF NOT EXISTS idx_vehicles_partner_id ON public.vehicles(partner_id);

-- 2. Backfill vehicles.partner_id from partner_vehicles
UPDATE public.vehicles v
SET partner_id = pv.partner_id
FROM public.partner_vehicles pv
WHERE (pv.vehicle_id = v.id OR pv.id = v.id)
  AND v.partner_id IS NULL
  AND pv.partner_id IS NOT NULL;

-- 2.1 Backfill vehicles.partner_id from partners table where owner_role is 'partner'
UPDATE public.vehicles v
SET partner_id = p.id
FROM public.partners p
WHERE v.owner_role = 'partner'
  AND (p.user_id = v.owner_id OR p.id = v.owner_id)
  AND v.partner_id IS NULL;

-- 3. Replace sync_booking_partner_linkage() with safe resolution query
CREATE OR REPLACE FUNCTION public.sync_booking_partner_linkage()
RETURNS TRIGGER AS $$
DECLARE
  v_pv_id uuid;
  v_p_id uuid;
  v_u_id uuid;
  v_meta_pid text;
  v_meta_oid text;
BEGIN
  -- Extract from metadata if available
  IF NEW.metadata IS NOT NULL THEN
    v_meta_pid := NEW.metadata ->> 'partner_id';
    v_meta_oid := NEW.metadata ->> 'owner_id';

    IF NEW.partner_id IS NULL AND v_meta_pid IS NOT NULL AND v_meta_pid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      NEW.partner_id := v_meta_pid::uuid;
    END IF;

    IF NEW.owner_id IS NULL AND v_meta_oid IS NOT NULL AND v_meta_oid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      NEW.owner_id := v_meta_oid::uuid;
    END IF;
  END IF;

  -- Attempt to resolve partner vehicle and partner ID
  IF NEW.partner_vehicle_id IS NOT NULL THEN
    SELECT pv.id, pv.partner_id, COALESCE(pv.user_id, p.user_id)
    INTO v_pv_id, v_p_id, v_u_id
    FROM public.partner_vehicles pv
    LEFT JOIN public.partners p ON p.id = pv.partner_id
    WHERE pv.id = NEW.partner_vehicle_id
    LIMIT 1;

    IF v_p_id IS NOT NULL AND NEW.partner_id IS NULL THEN
      NEW.partner_id := v_p_id;
    END IF;
    IF v_u_id IS NOT NULL AND NEW.owner_id IS NULL THEN
      NEW.owner_id := v_u_id;
    END IF;
  ELSIF NEW.vehicle_id IS NOT NULL THEN
    -- Check if vehicle_id directly matches a partner_vehicle id or canonical vehicle_id
    SELECT pv.id, pv.partner_id, COALESCE(pv.user_id, p.user_id)
    INTO v_pv_id, v_p_id, v_u_id
    FROM public.partner_vehicles pv
    LEFT JOIN public.partners p ON p.id = pv.partner_id
    WHERE pv.id = NEW.vehicle_id OR pv.vehicle_id = NEW.vehicle_id
    LIMIT 1;

    IF v_pv_id IS NOT NULL THEN
      NEW.partner_vehicle_id := COALESCE(NEW.partner_vehicle_id, v_pv_id);
      IF v_p_id IS NOT NULL AND NEW.partner_id IS NULL THEN
        NEW.partner_id := v_p_id;
      END IF;
      IF v_u_id IS NOT NULL AND NEW.owner_id IS NULL THEN
        NEW.owner_id := v_u_id;
      END IF;
    ELSE
      -- Check vehicles table for owner_id and resolve partner_id via partner_id column, partners table, or owner_id
      SELECT 
        v.owner_id, 
        COALESCE(
          v.partner_id,
          p.id,
          CASE WHEN v.owner_role = 'partner' THEN v.owner_id ELSE NULL END
        )
      INTO v_u_id, v_p_id
      FROM public.vehicles v
      LEFT JOIN public.partners p ON (p.user_id = v.owner_id OR p.id = v.owner_id)
      WHERE v.id = NEW.vehicle_id
      LIMIT 1;

      IF v_u_id IS NOT NULL AND NEW.owner_id IS NULL THEN
        NEW.owner_id := v_u_id;
      END IF;
      IF v_p_id IS NOT NULL AND NEW.partner_id IS NULL THEN
        NEW.partner_id := v_p_id;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure trigger is active
DROP TRIGGER IF EXISTS trg_sync_booking_partner_linkage ON public.bookings;
CREATE TRIGGER trg_sync_booking_partner_linkage
BEFORE INSERT OR UPDATE OF vehicle_id, partner_vehicle_id, metadata ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.sync_booking_partner_linkage();

-- 4. Backfill partner_id on public.bookings from public.vehicles if still null
UPDATE public.bookings b
SET partner_id = COALESCE(b.partner_id, v.partner_id)
FROM public.vehicles v
WHERE b.vehicle_id = v.id
  AND b.partner_id IS NULL
  AND v.partner_id IS NOT NULL;
