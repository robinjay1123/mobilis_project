-- ==============================================================================
-- Comprehensive Row Level Security (RLS) Policy Architecture
-- Migration: 20260923000700_comprehensive_rls_security.sql
-- Description: Enables and enforces granular RLS policies across critical tables:
--   - public.users
--   - public.vehicles, vehicle_images, partner_vehicles
--   - public.bookings, booking_financials, booking_settlements, booking_payouts
--   - public.payments, reservation_payment_receipts
--   - public.driver_job_assignments, driver_trips, driver_earnings
--   - public.driver_documents, renter_documents, user_documents, partner_vehicle_documents
--   - public.tracking_locations, tracking_location_logs
--   - public.booking_vehicle_inspections, emergency_contacts, app_settings
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. SECURITY DEFINER Role Helper Functions (Prevents Infinite Recursion 42P17)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT role::text
  FROM public.users
  WHERE id = auth.uid()
     OR lower(email) = lower(auth.jwt() ->> 'email')
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE (role = 'admin' OR role = 'superadmin')
      AND (
        id = auth.uid()
        OR lower(email) = lower(auth.jwt() ->> 'email')
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.is_operator_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE role = 'operator'
      AND (
        id = auth.uid()
        OR lower(email) = lower(auth.jwt() ->> 'email')
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.is_staff_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE role IN ('admin', 'superadmin', 'operator')
      AND (
        id = auth.uid()
        OR lower(email) = lower(auth.jwt() ->> 'email')
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.is_partner_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE role = 'partner'
      AND (
        id = auth.uid()
        OR lower(email) = lower(auth.jwt() ->> 'email')
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.is_driver_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE role = 'driver'
      AND (
        id = auth.uid()
        OR lower(email) = lower(auth.jwt() ->> 'email')
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_operator_user() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_staff_user() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_partner_user() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_driver_user() TO authenticated, anon;

-- ------------------------------------------------------------------------------
-- 2. USERS TABLE
-- ------------------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;
CREATE POLICY "users_select_authenticated"
  ON public.users
  FOR SELECT
  TO authenticated
  USING (true); -- Authenticated users can view profiles (needed for driver/renter/operator joins)

DROP POLICY IF EXISTS "users_insert_signup" ON public.users;
CREATE POLICY "users_insert_signup"
  ON public.users
  FOR INSERT
  TO authenticated, anon
  WITH CHECK (id = auth.uid() OR public.is_staff_user());

DROP POLICY IF EXISTS "users_update_own_or_staff" ON public.users;
CREATE POLICY "users_update_own_or_staff"
  ON public.users
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid() OR public.is_staff_user())
  WITH CHECK (id = auth.uid() OR public.is_staff_user());

DROP POLICY IF EXISTS "users_delete_admin" ON public.users;
CREATE POLICY "users_delete_admin"
  ON public.users
  FOR DELETE
  TO authenticated
  USING (public.is_admin_user());

-- ------------------------------------------------------------------------------
-- 3. VEHICLES & VEHICLE IMAGES (Public Browsing Catalog)
-- ------------------------------------------------------------------------------
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "vehicles_select_public" ON public.vehicles;
CREATE POLICY "vehicles_select_public"
  ON public.vehicles
  FOR SELECT
  TO authenticated, anon
  USING (true); -- Public catalog: unauthenticated visitors can view available vehicles

DROP POLICY IF EXISTS "vehicles_insert_staff_or_partner" ON public.vehicles;
CREATE POLICY "vehicles_insert_staff_or_partner"
  ON public.vehicles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_staff_user() 
    OR (public.is_partner_user() AND owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "vehicles_update_staff_or_partner" ON public.vehicles;
CREATE POLICY "vehicles_update_staff_or_partner"
  ON public.vehicles
  FOR UPDATE
  TO authenticated
  USING (
    public.is_staff_user() 
    OR owner_id = auth.uid()
  )
  WITH CHECK (
    public.is_staff_user() 
    OR owner_id = auth.uid()
  );

DROP POLICY IF EXISTS "vehicles_delete_staff_or_partner" ON public.vehicles;
CREATE POLICY "vehicles_delete_staff_or_partner"
  ON public.vehicles
  FOR DELETE
  TO authenticated
  USING (
    public.is_staff_user() 
    OR owner_id = auth.uid()
  );

-- Vehicle Images
ALTER TABLE public.vehicle_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "vehicle_images_select_public" ON public.vehicle_images;
CREATE POLICY "vehicle_images_select_public"
  ON public.vehicle_images
  FOR SELECT
  TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS "vehicle_images_manage_staff_or_partner" ON public.vehicle_images;
CREATE POLICY "vehicle_images_manage_staff_or_partner"
  ON public.vehicle_images
  FOR ALL
  TO authenticated
  USING (
    public.is_staff_user()
    OR EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = vehicle_images.vehicle_id
        AND v.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_staff_user()
    OR EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = vehicle_images.vehicle_id
        AND v.owner_id = auth.uid()
    )
  );

-- Partner Vehicles table (if present)
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'partner_vehicles') THEN
    EXECUTE 'ALTER TABLE public.partner_vehicles ENABLE ROW LEVEL SECURITY;';
    EXECUTE 'DROP POLICY IF EXISTS "partner_vehicles_select" ON public.partner_vehicles;';
    EXECUTE 'CREATE POLICY "partner_vehicles_select" ON public.partner_vehicles FOR SELECT TO authenticated, anon USING (true);';
    EXECUTE 'DROP POLICY IF EXISTS "partner_vehicles_manage" ON public.partner_vehicles;';
    EXECUTE 'CREATE POLICY "partner_vehicles_manage" ON public.partner_vehicles FOR ALL TO authenticated USING (public.is_staff_user() OR partner_id = auth.uid()) WITH CHECK (public.is_staff_user() OR partner_id = auth.uid());';
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 4. BOOKINGS TABLE
-- ------------------------------------------------------------------------------
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

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
    OR EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = bookings.vehicle_id
        AND v.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "bookings_insert_renter_or_staff" ON public.bookings;
CREATE POLICY "bookings_insert_renter_or_staff"
  ON public.bookings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    renter_id = auth.uid()
    OR public.is_staff_user()
  );

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
    OR EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = bookings.vehicle_id
        AND v.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR driver_id = auth.uid()
    OR operator_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = bookings.vehicle_id
        AND v.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "bookings_delete_admin" ON public.bookings;
CREATE POLICY "bookings_delete_admin"
  ON public.bookings
  FOR DELETE
  TO authenticated
  USING (public.is_admin_user());

-- ------------------------------------------------------------------------------
-- 5. DRIVER JOBS & TRIPS
-- ------------------------------------------------------------------------------
ALTER TABLE public.driver_job_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "driver_job_assignments_select" ON public.driver_job_assignments;
CREATE POLICY "driver_job_assignments_select"
  ON public.driver_job_assignments
  FOR SELECT
  TO authenticated
  USING (
    public.is_staff_user()
    OR driver_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = driver_job_assignments.booking_id
        AND (b.renter_id = auth.uid() OR b.operator_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "driver_job_assignments_manage_staff" ON public.driver_job_assignments;
CREATE POLICY "driver_job_assignments_manage_staff"
  ON public.driver_job_assignments
  FOR ALL
  TO authenticated
  USING (public.is_staff_user())
  WITH CHECK (public.is_staff_user());

DROP POLICY IF EXISTS "driver_job_assignments_driver_reply" ON public.driver_job_assignments;
CREATE POLICY "driver_job_assignments_driver_reply"
  ON public.driver_job_assignments
  FOR UPDATE
  TO authenticated
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());

-- Driver Trips
ALTER TABLE public.driver_trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "driver_trips_select" ON public.driver_trips;
CREATE POLICY "driver_trips_select"
  ON public.driver_trips
  FOR SELECT
  TO authenticated
  USING (
    public.is_staff_user()
    OR driver_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = driver_trips.booking_id
        AND (b.renter_id = auth.uid() OR b.operator_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "driver_trips_manage" ON public.driver_trips;
CREATE POLICY "driver_trips_manage"
  ON public.driver_trips
  FOR ALL
  TO authenticated
  USING (public.is_staff_user() OR driver_id = auth.uid())
  WITH CHECK (public.is_staff_user() OR driver_id = auth.uid());

-- Driver Earnings
ALTER TABLE public.driver_earnings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "driver_earnings_select" ON public.driver_earnings;
CREATE POLICY "driver_earnings_select"
  ON public.driver_earnings
  FOR SELECT
  TO authenticated
  USING (public.is_staff_user() OR driver_id = auth.uid());

DROP POLICY IF EXISTS "driver_earnings_manage_staff" ON public.driver_earnings;
CREATE POLICY "driver_earnings_manage_staff"
  ON public.driver_earnings
  FOR ALL
  TO authenticated
  USING (public.is_staff_user())
  WITH CHECK (public.is_staff_user());

-- ------------------------------------------------------------------------------
-- 6. VERIFICATION DOCUMENTS (Driver, Renter, Vehicle, User)
-- ------------------------------------------------------------------------------

-- Driver Documents
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "driver_documents_select" ON public.driver_documents;
CREATE POLICY "driver_documents_select"
  ON public.driver_documents
  FOR SELECT
  TO authenticated
  USING (
    public.is_staff_user()
    OR driver_id = auth.uid()
    OR driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "driver_documents_insert" ON public.driver_documents;
CREATE POLICY "driver_documents_insert"
  ON public.driver_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_staff_user()
    OR driver_id = auth.uid()
    OR driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "driver_documents_update" ON public.driver_documents;
CREATE POLICY "driver_documents_update"
  ON public.driver_documents
  FOR UPDATE
  TO authenticated
  USING (
    public.is_staff_user()
    OR driver_id = auth.uid()
    OR driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
  )
  WITH CHECK (
    public.is_staff_user()
    OR driver_id = auth.uid()
    OR driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "driver_documents_delete_staff" ON public.driver_documents;
CREATE POLICY "driver_documents_delete_staff"
  ON public.driver_documents
  FOR DELETE
  TO authenticated
  USING (public.is_staff_user());

-- Renter Documents
ALTER TABLE public.renter_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "renter_documents_select" ON public.renter_documents;
CREATE POLICY "renter_documents_select"
  ON public.renter_documents
  FOR SELECT
  TO authenticated
  USING (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR renter_id IN (SELECT id FROM public.renters WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "renter_documents_insert" ON public.renter_documents;
CREATE POLICY "renter_documents_insert"
  ON public.renter_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR renter_id IN (SELECT id FROM public.renters WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "renter_documents_update" ON public.renter_documents;
CREATE POLICY "renter_documents_update"
  ON public.renter_documents
  FOR UPDATE
  TO authenticated
  USING (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR renter_id IN (SELECT id FROM public.renters WHERE user_id = auth.uid())
  )
  WITH CHECK (
    public.is_staff_user()
    OR renter_id = auth.uid()
    OR renter_id IN (SELECT id FROM public.renters WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "renter_documents_delete_staff" ON public.renter_documents;
CREATE POLICY "renter_documents_delete_staff"
  ON public.renter_documents
  FOR DELETE
  TO authenticated
  USING (public.is_staff_user());

-- User Documents
ALTER TABLE public.user_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_documents_select" ON public.user_documents;
CREATE POLICY "user_documents_select"
  ON public.user_documents
  FOR SELECT
  TO authenticated
  USING (
    public.is_staff_user()
    OR profile_id = auth.uid()
  );

DROP POLICY IF EXISTS "user_documents_insert" ON public.user_documents;
CREATE POLICY "user_documents_insert"
  ON public.user_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_staff_user()
    OR profile_id = auth.uid()
  );

DROP POLICY IF EXISTS "user_documents_update" ON public.user_documents;
CREATE POLICY "user_documents_update"
  ON public.user_documents
  FOR UPDATE
  TO authenticated
  USING (
    public.is_staff_user()
    OR profile_id = auth.uid()
  )
  WITH CHECK (
    public.is_staff_user()
    OR profile_id = auth.uid()
  );

DROP POLICY IF EXISTS "user_documents_delete_staff" ON public.user_documents;
CREATE POLICY "user_documents_delete_staff"
  ON public.user_documents
  FOR DELETE
  TO authenticated
  USING (public.is_staff_user());

-- Partner Vehicle Documents
ALTER TABLE public.partner_vehicle_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "partner_vehicle_documents_select" ON public.partner_vehicle_documents;
CREATE POLICY "partner_vehicle_documents_select"
  ON public.partner_vehicle_documents
  FOR SELECT
  TO authenticated
  USING (
    public.is_staff_user()
    OR EXISTS (
      SELECT 1 FROM public.partner_vehicle_applications pva
      WHERE pva.id = partner_vehicle_documents.partner_vehicle_application_id
        AND pva.partner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "partner_vehicle_documents_manage" ON public.partner_vehicle_documents;
CREATE POLICY "partner_vehicle_documents_manage"
  ON public.partner_vehicle_documents
  FOR ALL
  TO authenticated
  USING (
    public.is_staff_user()
    OR EXISTS (
      SELECT 1 FROM public.partner_vehicle_applications pva
      WHERE pva.id = partner_vehicle_documents.partner_vehicle_application_id
        AND pva.partner_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_staff_user()
    OR EXISTS (
      SELECT 1 FROM public.partner_vehicle_applications pva
      WHERE pva.id = partner_vehicle_documents.partner_vehicle_application_id
        AND pva.partner_id = auth.uid()
    )
  );

-- ------------------------------------------------------------------------------
-- 7. TRACKING LOCATIONS & LOGS
-- ------------------------------------------------------------------------------
ALTER TABLE public.tracking_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tracking_locations_select" ON public.tracking_locations;
CREATE POLICY "tracking_locations_select"
  ON public.tracking_locations
  FOR SELECT
  TO authenticated
  USING (
    public.is_staff_user()
    OR tracked_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = tracking_locations.booking_id
        AND (b.renter_id = auth.uid() OR b.driver_id = auth.uid() OR b.operator_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "tracking_locations_insert" ON public.tracking_locations;
CREATE POLICY "tracking_locations_insert"
  ON public.tracking_locations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_staff_user()
    OR tracked_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = tracking_locations.booking_id
        AND (b.driver_id = auth.uid() OR b.operator_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "tracking_locations_update_staff" ON public.tracking_locations;
CREATE POLICY "tracking_locations_update_staff"
  ON public.tracking_locations
  FOR UPDATE
  TO authenticated
  USING (public.is_staff_user() OR tracked_user_id = auth.uid())
  WITH CHECK (public.is_staff_user() OR tracked_user_id = auth.uid());

-- Tracking Location Logs
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'tracking_location_logs') THEN
    EXECUTE 'ALTER TABLE public.tracking_location_logs ENABLE ROW LEVEL SECURITY;';
    EXECUTE 'DROP POLICY IF EXISTS "tracking_location_logs_select" ON public.tracking_location_logs;';
    EXECUTE 'CREATE POLICY "tracking_location_logs_select" ON public.tracking_location_logs FOR SELECT TO authenticated USING (public.is_staff_user() OR tracked_user_id = auth.uid());';
    EXECUTE 'DROP POLICY IF EXISTS "tracking_location_logs_insert" ON public.tracking_location_logs;';
    EXECUTE 'CREATE POLICY "tracking_location_logs_insert" ON public.tracking_location_logs FOR INSERT TO authenticated WITH CHECK (public.is_staff_user() OR tracked_user_id = auth.uid());';
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 8. PAYMENTS & FINANCIALS
-- ------------------------------------------------------------------------------

-- Payments
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'payments') THEN
    EXECUTE 'ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;';
    EXECUTE 'DROP POLICY IF EXISTS "payments_select" ON public.payments;';
    EXECUTE 'CREATE POLICY "payments_select" ON public.payments FOR SELECT TO authenticated USING (public.is_staff_user() OR payer_user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = payments.booking_id AND b.renter_id = auth.uid()));';
    EXECUTE 'DROP POLICY IF EXISTS "payments_insert" ON public.payments;';
    EXECUTE 'CREATE POLICY "payments_insert" ON public.payments FOR INSERT TO authenticated WITH CHECK (payer_user_id = auth.uid() OR public.is_staff_user());';
    EXECUTE 'DROP POLICY IF EXISTS "payments_update_staff" ON public.payments;';
    EXECUTE 'CREATE POLICY "payments_update_staff" ON public.payments FOR UPDATE TO authenticated USING (public.is_staff_user()) WITH CHECK (public.is_staff_user());';
  END IF;
END $$;

-- Booking Financials
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'booking_financials') THEN
    EXECUTE 'ALTER TABLE public.booking_financials ENABLE ROW LEVEL SECURITY;';
    EXECUTE 'DROP POLICY IF EXISTS "booking_financials_select" ON public.booking_financials;';
    EXECUTE 'CREATE POLICY "booking_financials_select" ON public.booking_financials FOR SELECT TO authenticated USING (public.is_staff_user() OR EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_financials.booking_id AND (b.renter_id = auth.uid() OR b.driver_id = auth.uid() OR b.operator_id = auth.uid() OR EXISTS (SELECT 1 FROM public.vehicles v WHERE v.id = b.vehicle_id AND v.owner_id = auth.uid()))));';
    EXECUTE 'DROP POLICY IF EXISTS "booking_financials_manage_staff" ON public.booking_financials;';
    EXECUTE 'CREATE POLICY "booking_financials_manage_staff" ON public.booking_financials FOR ALL TO authenticated USING (public.is_staff_user()) WITH CHECK (public.is_staff_user());';
  END IF;
END $$;

-- Booking Settlements
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'booking_settlements') THEN
    EXECUTE 'ALTER TABLE public.booking_settlements ENABLE ROW LEVEL SECURITY;';
    EXECUTE 'DROP POLICY IF EXISTS "booking_settlements_select" ON public.booking_settlements;';
    EXECUTE 'CREATE POLICY "booking_settlements_select" ON public.booking_settlements FOR SELECT TO authenticated USING (public.is_staff_user() OR partner_user_id = auth.uid() OR driver_user_id = auth.uid() OR operator_user_id = auth.uid());';
    EXECUTE 'DROP POLICY IF EXISTS "booking_settlements_manage_staff" ON public.booking_settlements;';
    EXECUTE 'CREATE POLICY "booking_settlements_manage_staff" ON public.booking_settlements FOR ALL TO authenticated USING (public.is_staff_user()) WITH CHECK (public.is_staff_user());';
  END IF;
END $$;

-- Booking Payouts
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'booking_payouts') THEN
    EXECUTE 'ALTER TABLE public.booking_payouts ENABLE ROW LEVEL SECURITY;';
    EXECUTE 'DROP POLICY IF EXISTS "booking_payouts_select" ON public.booking_payouts;';
    EXECUTE 'CREATE POLICY "booking_payouts_select" ON public.booking_payouts FOR SELECT TO authenticated USING (public.is_staff_user() OR recipient_user_id = auth.uid());';
    EXECUTE 'DROP POLICY IF EXISTS "booking_payouts_manage_staff" ON public.booking_payouts;';
    EXECUTE 'CREATE POLICY "booking_payouts_manage_staff" ON public.booking_payouts FOR ALL TO authenticated USING (public.is_staff_user()) WITH CHECK (public.is_staff_user());';
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 9. INSPECTIONS & EMERGENCY CONTACTS
-- ------------------------------------------------------------------------------

-- Booking Vehicle Inspections
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'booking_vehicle_inspections') THEN
    EXECUTE 'ALTER TABLE public.booking_vehicle_inspections ENABLE ROW LEVEL SECURITY;';
    EXECUTE 'DROP POLICY IF EXISTS "booking_vehicle_inspections_select" ON public.booking_vehicle_inspections;';
    EXECUTE 'CREATE POLICY "booking_vehicle_inspections_select" ON public.booking_vehicle_inspections FOR SELECT TO authenticated USING (public.is_staff_user() OR inspector_id = auth.uid() OR EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_vehicle_inspections.booking_id AND (b.renter_id = auth.uid() OR b.driver_id = auth.uid() OR b.operator_id = auth.uid())));';
    EXECUTE 'DROP POLICY IF EXISTS "booking_vehicle_inspections_manage" ON public.booking_vehicle_inspections;';
    EXECUTE 'CREATE POLICY "booking_vehicle_inspections_manage" ON public.booking_vehicle_inspections FOR ALL TO authenticated USING (public.is_staff_user() OR inspector_id = auth.uid() OR EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_vehicle_inspections.booking_id AND (b.driver_id = auth.uid() OR b.operator_id = auth.uid()))) WITH CHECK (public.is_staff_user() OR inspector_id = auth.uid() OR EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_vehicle_inspections.booking_id AND (b.driver_id = auth.uid() OR b.operator_id = auth.uid())));';
  END IF;
END $$;

-- Emergency Contacts
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'emergency_contacts') THEN
    EXECUTE 'ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;';
    EXECUTE 'DROP POLICY IF EXISTS "emergency_contacts_select" ON public.emergency_contacts;';
    EXECUTE 'CREATE POLICY "emergency_contacts_select" ON public.emergency_contacts FOR SELECT TO authenticated USING (public.is_staff_user() OR user_id = auth.uid());';
    EXECUTE 'DROP POLICY IF EXISTS "emergency_contacts_manage" ON public.emergency_contacts;';
    EXECUTE 'CREATE POLICY "emergency_contacts_manage" ON public.emergency_contacts FOR ALL TO authenticated USING (public.is_staff_user() OR user_id = auth.uid()) WITH CHECK (public.is_staff_user() OR user_id = auth.uid());';
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 10. APP SETTINGS (Public Configuration Read, Admin Manage)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'app_settings') THEN
    EXECUTE 'ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;';
    EXECUTE 'DROP POLICY IF EXISTS "app_settings_select_public" ON public.app_settings;';
    EXECUTE 'CREATE POLICY "app_settings_select_public" ON public.app_settings FOR SELECT TO authenticated, anon USING (true);';
    EXECUTE 'DROP POLICY IF EXISTS "app_settings_manage_admin" ON public.app_settings;';
    EXECUTE 'CREATE POLICY "app_settings_manage_admin" ON public.app_settings FOR ALL TO authenticated USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());';
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 11. GRANT PERMISSIONS TO POSTGRES ROLES
-- ------------------------------------------------------------------------------
GRANT SELECT ON public.vehicles TO anon, authenticated;
GRANT SELECT ON public.vehicle_images TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vehicles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vehicle_images TO authenticated;

GRANT SELECT, INSERT, UPDATE ON public.bookings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT INSERT ON public.users TO anon; -- For registration

GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
