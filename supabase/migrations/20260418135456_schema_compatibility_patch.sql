-- Compatibility migration for existing Mobilis schemas.
-- This patch aligns column names and relationships with current app code.

BEGIN;

-- users compatibility
ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS full_name text,
  ADD COLUMN IF NOT EXISTS application_status text,
  ADD COLUMN IF NOT EXISTS id_verified boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS verification_status text;

UPDATE public.users
SET full_name = COALESCE(full_name, name)
WHERE full_name IS NULL
  AND EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'name'
  );

UPDATE public.users
SET application_status = COALESCE(application_status, CASE
  WHEN role IN ('partner', 'driver') THEN 'pending'
  ELSE 'none'
END)
WHERE application_status IS NULL;

UPDATE public.users
SET verification_status = COALESCE(verification_status, CASE
  WHEN id_verified IS TRUE THEN 'verified'
  ELSE 'pending'
END)
WHERE verification_status IS NULL;

-- partners compatibility
ALTER TABLE IF EXISTS public.partners
  ADD COLUMN IF NOT EXISTS business_address text,
  ADD COLUMN IF NOT EXISTS business_phone text;

UPDATE public.partners
SET business_address = COALESCE(business_address, address)
WHERE business_address IS NULL
  AND EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'partners'
      AND column_name = 'address'
  );

-- renters compatibility: app expects renters.user_id
ALTER TABLE IF EXISTS public.renters
  ADD COLUMN IF NOT EXISTS user_id uuid;

UPDATE public.renters
SET user_id = id
WHERE user_id IS NULL;

DO $$
BEGIN
  IF to_regclass('public.renters') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'renters_user_id_fkey'
        AND conrelid = 'public.renters'::regclass
    ) THEN
      ALTER TABLE public.renters
        ADD CONSTRAINT renters_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.users(id);
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'renters_user_id_key'
        AND conrelid = 'public.renters'::regclass
    ) THEN
      ALTER TABLE public.renters
        ADD CONSTRAINT renters_user_id_key UNIQUE (user_id);
    END IF;
  END IF;
END $$;

-- bookings compatibility: app uses start_date/end_date and location fields
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS start_date timestamp without time zone,
  ADD COLUMN IF NOT EXISTS end_date timestamp without time zone,
  ADD COLUMN IF NOT EXISTS pickup_location text,
  ADD COLUMN IF NOT EXISTS dropoff_location text;

UPDATE public.bookings
SET start_date = COALESCE(start_date, start_time),
    end_date = COALESCE(end_date, expected_return_time)
WHERE (start_date IS NULL OR end_date IS NULL)
  AND EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'bookings'
      AND column_name = 'start_time'
  )
  AND EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'bookings'
      AND column_name = 'expected_return_time'
  );

-- drivers compatibility: app and docs reference tier alias
ALTER TABLE IF EXISTS public.drivers
  ADD COLUMN IF NOT EXISTS tier text;

UPDATE public.drivers
SET tier = COALESCE(tier, driver_tier)
WHERE tier IS NULL
  AND EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'drivers'
      AND column_name = 'driver_tier'
  );

-- partner_vehicle_applications compatibility with service layer
ALTER TABLE IF EXISTS public.partner_vehicle_applications
  ADD COLUMN IF NOT EXISTS application_status text,
  ADD COLUMN IF NOT EXISTS brand text,
  ADD COLUMN IF NOT EXISTS model text,
  ADD COLUMN IF NOT EXISTS year integer,
  ADD COLUMN IF NOT EXISTS plate_number text,
  ADD COLUMN IF NOT EXISTS price_per_day numeric,
  ADD COLUMN IF NOT EXISTS price_per_hour numeric,
  ADD COLUMN IF NOT EXISTS vehicle_photo_url text,
  ADD COLUMN IF NOT EXISTS rejection_reason text,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamp without time zone,
  ADD COLUMN IF NOT EXISTS created_vehicle_id uuid;

UPDATE public.partner_vehicle_applications
SET application_status = COALESCE(application_status, status)
WHERE application_status IS NULL;

DO $$
BEGIN
  IF to_regclass('public.partner_vehicle_applications') IS NOT NULL THEN
    -- App inserts without partner_vehicle_id.
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'partner_vehicle_applications'
        AND column_name = 'partner_vehicle_id'
    ) THEN
      BEGIN
        ALTER TABLE public.partner_vehicle_applications
          ALTER COLUMN partner_vehicle_id DROP NOT NULL;
      EXCEPTION WHEN others THEN
        NULL;
      END;
    END IF;

    -- Ensure partner_id references users(id) for app-side joins.
    IF EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'partner_vehicle_applications_partner_id_fkey'
        AND conrelid = 'public.partner_vehicle_applications'::regclass
    ) THEN
      ALTER TABLE public.partner_vehicle_applications
        DROP CONSTRAINT partner_vehicle_applications_partner_id_fkey;
    END IF;

    ALTER TABLE public.partner_vehicle_applications
      ADD CONSTRAINT partner_vehicle_applications_partner_id_fkey
      FOREIGN KEY (partner_id) REFERENCES public.users(id);
  END IF;
END $$;

-- Helpful indexes for current query patterns
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_application_status ON public.users(application_status);
CREATE INDEX IF NOT EXISTS idx_bookings_start_date ON public.bookings(start_date);
CREATE INDEX IF NOT EXISTS idx_bookings_end_date ON public.bookings(end_date);
CREATE INDEX IF NOT EXISTS idx_partner_vehicle_applications_partner_id ON public.partner_vehicle_applications(partner_id);
CREATE INDEX IF NOT EXISTS idx_partner_vehicle_applications_application_status ON public.partner_vehicle_applications(application_status);

COMMIT;