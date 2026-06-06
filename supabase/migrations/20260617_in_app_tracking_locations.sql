-- In-app GPS tracking for active bookings.
-- The app records the current user's device location while a booking is active.

BEGIN;

CREATE TABLE IF NOT EXISTS public.tracking_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  vehicle_id uuid REFERENCES public.vehicles(id) ON DELETE SET NULL,
  tracked_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  accuracy_meters double precision,
  speed_mps double precision,
  heading_degrees double precision,
  source text NOT NULL DEFAULT 'driver_app',
  recorded_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tracking_locations_booking_user_unique
    UNIQUE (booking_id, tracked_user_id)
);

CREATE INDEX IF NOT EXISTS idx_tracking_locations_booking_id
  ON public.tracking_locations(booking_id);
CREATE INDEX IF NOT EXISTS idx_tracking_locations_vehicle_id
  ON public.tracking_locations(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_tracking_locations_tracked_user_id
  ON public.tracking_locations(tracked_user_id);
CREATE INDEX IF NOT EXISTS idx_tracking_locations_recorded_at
  ON public.tracking_locations(recorded_at DESC);

ALTER TABLE public.tracking_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tracking_locations_select_admin_operator ON public.tracking_locations;
CREATE POLICY tracking_locations_select_admin_operator
  ON public.tracking_locations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN ('admin', 'operator')
    )
  );

DROP POLICY IF EXISTS tracking_locations_select_own_booking ON public.tracking_locations;
CREATE POLICY tracking_locations_select_own_booking
  ON public.tracking_locations
  FOR SELECT
  TO authenticated
  USING (
    tracked_user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.bookings b
      WHERE b.id = public.tracking_locations.booking_id
        AND b.renter_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tracking_locations_insert_own ON public.tracking_locations;
CREATE POLICY tracking_locations_insert_own
  ON public.tracking_locations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    tracked_user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.bookings b
      LEFT JOIN public.drivers d ON d.id = b.driver_id
      WHERE b.id = booking_id
        AND (
          b.renter_id = auth.uid()
          OR d.user_id = auth.uid()
        )
        AND b.status IN ('approved', 'confirmed', 'active')
    )
  );

DROP POLICY IF EXISTS tracking_locations_update_own ON public.tracking_locations;
CREATE POLICY tracking_locations_update_own
  ON public.tracking_locations
  FOR UPDATE
  TO authenticated
  USING (tracked_user_id = auth.uid())
  WITH CHECK (
    tracked_user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.bookings b
      LEFT JOIN public.drivers d ON d.id = b.driver_id
      WHERE b.id = booking_id
        AND (
          b.renter_id = auth.uid()
          OR d.user_id = auth.uid()
        )
        AND b.status IN ('approved', 'confirmed', 'active')
    )
  );

NOTIFY pgrst, 'reload schema';

COMMIT;
