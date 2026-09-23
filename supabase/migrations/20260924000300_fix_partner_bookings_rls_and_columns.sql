-- ==============================================================================
-- Migration: 20260924000300_fix_partner_bookings_rls_and_columns.sql
-- Description:
--   1. Ensures partner_id and owner_id columns exist on public.bookings.
--   2. Adds performance indexes for partner bookings lookups.
--   3. Adds a trigger to automatically resolve and populate partner_id, owner_id,
--      and partner_vehicle_id from metadata and vehicle linkages.
--   4. Backfills partner_id, owner_id, and partner_vehicle_id on existing bookings.
--   5. Fixes RLS policies on public.bookings (SELECT and UPDATE) and
--      public.booking_financials to allow partners to query and manage bookings
--      for their vehicles (whether canonical vehicles or partner_vehicles).
--   6. Ensures authenticated partners can query public.partners.
-- ==============================================================================

-- 1. Ensure columns exist on public.bookings
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS partner_id uuid;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS owner_id uuid;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS partner_vehicle_id uuid;

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_bookings_partner_id ON public.bookings(partner_id);
CREATE INDEX IF NOT EXISTS idx_bookings_owner_id ON public.bookings(owner_id);
CREATE INDEX IF NOT EXISTS idx_bookings_partner_vehicle_id ON public.bookings(partner_vehicle_id);

-- 3. Automatic resolution function & trigger for partner booking linkage
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
      -- Check vehicles table for owner_id / partner_id
      SELECT v.owner_id, v.partner_id
      INTO v_u_id, v_p_id
      FROM public.vehicles v
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

DROP TRIGGER IF EXISTS trg_sync_booking_partner_linkage ON public.bookings;
CREATE TRIGGER trg_sync_booking_partner_linkage
BEFORE INSERT OR UPDATE OF vehicle_id, partner_vehicle_id, metadata ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.sync_booking_partner_linkage();

-- 4. Backfill existing bookings
DO $$
BEGIN
  -- 4.1 Backfill partner_vehicle_id
  UPDATE public.bookings b
  SET partner_vehicle_id = pv.id
  FROM public.partner_vehicles pv
  WHERE b.partner_vehicle_id IS NULL
    AND (b.vehicle_id = pv.id OR b.vehicle_id = pv.vehicle_id);

  -- 4.2 Backfill partner_id and owner_id from partner_vehicles
  UPDATE public.bookings b
  SET partner_id = COALESCE(b.partner_id, pv.partner_id),
      owner_id = COALESCE(b.owner_id, pv.user_id, pv.partner_id)
  FROM public.partner_vehicles pv
  WHERE (b.partner_vehicle_id = pv.id OR b.vehicle_id = pv.id OR b.vehicle_id = pv.vehicle_id)
    AND (b.partner_id IS NULL OR b.owner_id IS NULL);

  -- 4.3 Backfill from metadata
  UPDATE public.bookings
  SET partner_id = COALESCE(partner_id, NULLIF(metadata->>'partner_id', '')::uuid)
  WHERE partner_id IS NULL
    AND metadata IS NOT NULL
    AND metadata ? 'partner_id'
    AND metadata->>'partner_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

  UPDATE public.bookings
  SET owner_id = COALESCE(owner_id, NULLIF(metadata->>'owner_id', '')::uuid)
  WHERE owner_id IS NULL
    AND metadata IS NOT NULL
    AND metadata ? 'owner_id'
    AND metadata->>'owner_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

  -- 4.4 Backfill from vehicles table owner_id
  UPDATE public.bookings b
  SET owner_id = COALESCE(b.owner_id, v.owner_id)
  FROM public.vehicles v
  WHERE b.vehicle_id = v.id
    AND b.owner_id IS NULL
    AND v.owner_id IS NOT NULL;
END $$;

-- 5. Comprehensive RLS on public.bookings (SELECT)
DROP POLICY IF EXISTS "bookings_select_participants" ON public.bookings;
CREATE POLICY "bookings_select_participants"
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR driver_id = auth.uid()
    OR operator_id = auth.uid()
    OR partner_id = auth.uid()
    OR owner_id = auth.uid()
    OR (metadata IS NOT NULL AND (
      metadata->>'partner_id' = auth.uid()::text
      OR metadata->>'owner_id' = auth.uid()::text
    ))
    -- Partner via partner_vehicles table
    OR EXISTS (
      SELECT 1 FROM public.partner_vehicles pv
      WHERE (pv.id = bookings.partner_vehicle_id OR pv.id = bookings.vehicle_id OR pv.vehicle_id = bookings.vehicle_id)
        AND (
          pv.partner_id = auth.uid()
          OR pv.user_id = auth.uid()
          OR pv.partner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
        )
    )
    -- Owner / Partner via canonical vehicles table
    OR EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = bookings.vehicle_id
        AND (
          v.owner_id = auth.uid()
          OR v.operator_id = auth.uid()
          OR v.owner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
        )
    )
    -- Profile linkage via partners table
    OR (partner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid()))
    OR (owner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid()))
    OR (metadata IS NOT NULL AND (
      (metadata->>'partner_id') IN (SELECT p.id::text FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
      OR (metadata->>'owner_id') IN (SELECT p.id::text FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
    ))
  );

-- 6. Comprehensive RLS on public.bookings (UPDATE)
DROP POLICY IF EXISTS "bookings_update_participants" ON public.bookings;
CREATE POLICY "bookings_update_participants"
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR driver_id = auth.uid()
    OR operator_id = auth.uid()
    OR partner_id = auth.uid()
    OR owner_id = auth.uid()
    OR (metadata IS NOT NULL AND (
      metadata->>'partner_id' = auth.uid()::text
      OR metadata->>'owner_id' = auth.uid()::text
    ))
    OR EXISTS (
      SELECT 1 FROM public.partner_vehicles pv
      WHERE (pv.id = bookings.partner_vehicle_id OR pv.id = bookings.vehicle_id OR pv.vehicle_id = bookings.vehicle_id)
        AND (
          pv.partner_id = auth.uid()
          OR pv.user_id = auth.uid()
          OR pv.partner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
        )
    )
    OR EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = bookings.vehicle_id
        AND (
          v.owner_id = auth.uid()
          OR v.operator_id = auth.uid()
          OR v.owner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
        )
    )
    OR (partner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid()))
    OR (owner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid()))
    OR (metadata IS NOT NULL AND (
      (metadata->>'partner_id') IN (SELECT p.id::text FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
      OR (metadata->>'owner_id') IN (SELECT p.id::text FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
    ))
  )
  WITH CHECK (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR driver_id = auth.uid()
    OR operator_id = auth.uid()
    OR partner_id = auth.uid()
    OR owner_id = auth.uid()
    OR (metadata IS NOT NULL AND (
      metadata->>'partner_id' = auth.uid()::text
      OR metadata->>'owner_id' = auth.uid()::text
    ))
    OR EXISTS (
      SELECT 1 FROM public.partner_vehicles pv
      WHERE (pv.id = bookings.partner_vehicle_id OR pv.id = bookings.vehicle_id OR pv.vehicle_id = bookings.vehicle_id)
        AND (
          pv.partner_id = auth.uid()
          OR pv.user_id = auth.uid()
          OR pv.partner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
        )
    )
    OR EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = bookings.vehicle_id
        AND (
          v.owner_id = auth.uid()
          OR v.operator_id = auth.uid()
          OR v.owner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
        )
    )
    OR (partner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid()))
    OR (owner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid()))
    OR (metadata IS NOT NULL AND (
      (metadata->>'partner_id') IN (SELECT p.id::text FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
      OR (metadata->>'owner_id') IN (SELECT p.id::text FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid())
    ))
  );

-- 7. Update booking_financials RLS for partner visibility
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'booking_financials') THEN
    EXECUTE 'DROP POLICY IF EXISTS "booking_financials_select" ON public.booking_financials;';
    EXECUTE 'CREATE POLICY "booking_financials_select" ON public.booking_financials FOR SELECT TO authenticated USING (
      public.is_staff_user()
      OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = booking_financials.booking_id
          AND (
            b.renter_id = auth.uid()
            OR b.driver_id = auth.uid()
            OR b.operator_id = auth.uid()
            OR b.partner_id = auth.uid()
            OR b.owner_id = auth.uid()
            OR (b.metadata IS NOT NULL AND (
              b.metadata->>''partner_id'' = auth.uid()::text
              OR b.metadata->>''owner_id'' = auth.uid()::text
            ))
            OR EXISTS (
              SELECT 1 FROM public.partner_vehicles pv
              WHERE (pv.id = b.partner_vehicle_id OR pv.id = b.vehicle_id OR pv.vehicle_id = b.vehicle_id)
                AND (pv.partner_id = auth.uid() OR pv.user_id = auth.uid() OR pv.partner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid()))
            )
            OR EXISTS (
              SELECT 1 FROM public.vehicles v
              WHERE v.id = b.vehicle_id
                AND (v.owner_id = auth.uid() OR v.owner_id IN (SELECT p.id FROM public.partners p WHERE p.user_id = auth.uid() OR p.id = auth.uid()))
            )
          )
      )
    );';
  END IF;
END $$;

-- 8. Partners table RLS policies & permissions
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'partners') THEN
    EXECUTE 'ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;';
    EXECUTE 'DROP POLICY IF EXISTS "partners_select" ON public.partners;';
    EXECUTE 'CREATE POLICY "partners_select" ON public.partners FOR SELECT TO authenticated, anon USING (true);';
    EXECUTE 'DROP POLICY IF EXISTS "partners_manage" ON public.partners;';
    EXECUTE 'CREATE POLICY "partners_manage" ON public.partners FOR ALL TO authenticated USING (public.is_staff_user() OR user_id = auth.uid() OR id = auth.uid()) WITH CHECK (public.is_staff_user() OR user_id = auth.uid() OR id = auth.uid());';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE ON public.partners TO authenticated;';
  END IF;
END $$;

-- 9. Grants & PostgREST reload
GRANT SELECT, INSERT, UPDATE ON public.bookings TO authenticated;
NOTIFY pgrst, 'reload schema';
