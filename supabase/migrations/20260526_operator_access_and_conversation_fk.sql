-- Give operator accounts the read/update access required by the operations
-- dashboard, and ensure conversations can be embedded with bookings.

BEGIN;

CREATE OR REPLACE FUNCTION public.is_operator_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
      AND role = 'operator'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_operator_user() TO authenticated;

-- Operators need to fetch all bookings awaiting approval/dispatch, not only
-- bookings for vehicles where their id was copied into vehicles.operator_id.
DROP POLICY IF EXISTS bookings_select_operator_own ON public.bookings;
DROP POLICY IF EXISTS bookings_select_operator_all ON public.bookings;
CREATE POLICY bookings_select_operator_all
  ON public.bookings
  FOR SELECT
  TO authenticated
  USING (
    public.is_operator_user()
    OR vehicle_id IN (
      SELECT id
      FROM public.vehicles
      WHERE owner_id = auth.uid()
         OR operator_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS bookings_update_operator_own ON public.bookings;
DROP POLICY IF EXISTS bookings_update_operator_all ON public.bookings;
CREATE POLICY bookings_update_operator_all
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (
    public.is_operator_user()
    OR vehicle_id IN (
      SELECT id
      FROM public.vehicles
      WHERE owner_id = auth.uid()
         OR operator_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_operator_user()
    OR vehicle_id IN (
      SELECT id
      FROM public.vehicles
      WHERE owner_id = auth.uid()
         OR operator_id = auth.uid()
    )
  );

-- Embedded booking rows need their vehicle and renter records too.
DROP POLICY IF EXISTS users_select_operator_all ON public.users;
CREATE POLICY users_select_operator_all
  ON public.users
  FOR SELECT
  TO authenticated
  USING (public.is_operator_user());

DROP POLICY IF EXISTS vehicles_select_operator_all ON public.vehicles;
CREATE POLICY vehicles_select_operator_all
  ON public.vehicles
  FOR SELECT
  TO authenticated
  USING (public.is_operator_user());

-- The operator messages screen embeds bookings from conversations using the
-- conversations_booking_id_fkey hint. Add the missing relationship if needed.
ALTER TABLE IF EXISTS public.conversations
  ADD COLUMN IF NOT EXISTS booking_id uuid,
  ADD COLUMN IF NOT EXISTS user_id uuid,
  ADD COLUMN IF NOT EXISTS other_user_id uuid,
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

DO $$
BEGIN
  IF to_regclass('public.conversations') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'conversations_booking_id_fkey'
        AND conrelid = 'public.conversations'::regclass
    ) THEN
      ALTER TABLE public.conversations
        ADD CONSTRAINT conversations_booking_id_fkey
        FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'conversations_user_id_fkey'
        AND conrelid = 'public.conversations'::regclass
    ) THEN
      ALTER TABLE public.conversations
        ADD CONSTRAINT conversations_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'conversations_other_user_id_fkey'
        AND conrelid = 'public.conversations'::regclass
    ) THEN
      ALTER TABLE public.conversations
        ADD CONSTRAINT conversations_other_user_id_fkey
        FOREIGN KEY (other_user_id) REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

COMMIT;
