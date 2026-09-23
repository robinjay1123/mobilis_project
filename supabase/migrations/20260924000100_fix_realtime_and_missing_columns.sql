-- Migration: Fix Realtime WAL replication and PostgREST schema column compatibility
-- Description: Adds user_id on partner_vehicles and total_amount on bookings to cure
-- 42703 "column partner_vehicles.user_id does not exist" and "column bookings_1.total_amount does not exist"
-- which were causing 12-14 second WAL replication bottlenecks in PostgreSQL.

-- ============================================================================
-- 1. ADD AND SYNC user_id ON public.partner_vehicles
-- ============================================================================

ALTER TABLE public.partner_vehicles ADD COLUMN IF NOT EXISTS user_id uuid;

-- Backfill user_id from partners.user_id
UPDATE public.partner_vehicles pv
SET user_id = p.user_id
FROM public.partners p
WHERE pv.partner_id = p.id
  AND (pv.user_id IS NULL OR pv.user_id != p.user_id);

-- Update the sync trigger function to keep user_id in sync
CREATE OR REPLACE FUNCTION public.sync_partner_vehicles_normalized_columns()
RETURNS trigger AS $$
BEGIN
  -- Sync user_id from partners table if empty
  IF NEW.user_id IS NULL AND NEW.partner_id IS NOT NULL THEN
    SELECT user_id INTO NEW.user_id
    FROM public.partners
    WHERE id = NEW.partner_id
    LIMIT 1;
  END IF;

  -- 1. Sync vehicle_name if empty
  IF NEW.vehicle_name IS NULL OR TRIM(NEW.vehicle_name) = '' THEN
    NEW.vehicle_name := TRIM(CONCAT(COALESCE(NEW.brand, ''), ' ', COALESCE(NEW.model, '')));
  END IF;

  -- 2. Sync vehicle_type <-> category
  IF NEW.vehicle_type IS NULL AND NEW.category IS NOT NULL THEN
    NEW.vehicle_type := NEW.category;
  ELSIF NEW.category IS NULL AND NEW.vehicle_type IS NOT NULL THEN
    NEW.category := NEW.vehicle_type;
  END IF;

  -- 3. Sync status <-> is_available & is_posted
  IF NEW.status IS NULL THEN
    IF NEW.is_available IS TRUE THEN
      NEW.status := 'available';
    ELSE
      NEW.status := 'disabled';
    END IF;
  END IF;

  IF NEW.status = 'available' THEN
    NEW.is_available := TRUE;
    NEW.is_posted := TRUE;
  ELSIF NEW.status IN ('rented', 'maintenance') THEN
    NEW.is_available := FALSE;
    NEW.is_posted := TRUE;
  ELSE
    NEW.is_available := FALSE;
    NEW.is_posted := FALSE;
  END IF;

  -- 4. Sync application_status with status
  IF NEW.application_status IS NULL THEN
    IF NEW.status IN ('available', 'rented', 'maintenance', 'disabled', 'sold') THEN
      NEW.application_status := 'approved';
    ELSE
      NEW.application_status := NEW.status;
    END IF;
  END IF;

  -- 5. Always set owner_role to 'partner'
  NEW.owner_role := 'partner';

  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Refresh partner_vehicles RLS policy to support both partner_id and user_id safely
DROP POLICY IF EXISTS "partner_vehicles_manage" ON public.partner_vehicles;
CREATE POLICY "partner_vehicles_manage"
  ON public.partner_vehicles
  FOR ALL
  TO authenticated
  USING (
    public.is_staff_user()
    OR partner_id = auth.uid()
    OR user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.partners p
      WHERE p.id = partner_vehicles.partner_id
        AND p.user_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_staff_user()
    OR partner_id = auth.uid()
    OR user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.partners p
      WHERE p.id = partner_vehicles.partner_id
        AND p.user_id = auth.uid()
    )
  );

-- ============================================================================
-- 2. ADD AND SYNC total_amount ON public.bookings
-- ============================================================================

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS total_amount numeric;

-- Backfill total_amount from total_price
UPDATE public.bookings
SET total_amount = COALESCE(total_price, 0)
WHERE total_amount IS NULL;

-- Ensure total_amount is kept synchronized on insert/update of bookings
CREATE OR REPLACE FUNCTION public.sync_booking_total_amount()
RETURNS trigger AS $$
BEGIN
  IF NEW.total_amount IS NULL OR (NEW.total_price IS NOT NULL AND NEW.total_amount != NEW.total_price) THEN
    NEW.total_amount := COALESCE(NEW.total_price, NEW.total_amount, 0);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_booking_total_amount ON public.bookings;
CREATE TRIGGER trg_sync_booking_total_amount
BEFORE INSERT OR UPDATE OF total_price, total_amount ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.sync_booking_total_amount();
