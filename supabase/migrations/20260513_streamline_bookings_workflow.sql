-- Streamline bookings for renter -> operator approval workflow.
-- Keeps only workflow-relevant fields and supports optional driver assignment.

BEGIN;

ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS with_driver boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS operator_notes text,
  ADD COLUMN IF NOT EXISTS rejection_reason text,
  ADD COLUMN IF NOT EXISTS approved_at timestamp without time zone,
  ADD COLUMN IF NOT EXISTS rejected_at timestamp without time zone,
  ADD COLUMN IF NOT EXISTS driver_assigned_at timestamp without time zone,
  ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone DEFAULT now();

-- Normalize null values for required workflow flags.
UPDATE public.bookings
SET with_driver = false
WHERE with_driver IS NULL;

UPDATE public.bookings
SET status = 'pending'
WHERE status IS NULL OR trim(status) = '';

-- Drop duplicate legacy fields that conflict with current workflow naming.
ALTER TABLE IF EXISTS public.bookings
  DROP COLUMN IF EXISTS start_time,
  DROP COLUMN IF EXISTS expected_return_time,
  DROP COLUMN IF EXISTS cancellation_reason,
  DROP COLUMN IF EXISTS cancelled_at;

-- Ensure driver references users table when driver assignment is used.
DO $$
BEGIN
  IF to_regclass('public.bookings') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'bookings_driver_id_fkey'
        AND conrelid = 'public.bookings'::regclass
    ) THEN
      ALTER TABLE public.bookings
        ADD CONSTRAINT bookings_driver_id_fkey
        FOREIGN KEY (driver_id) REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_with_driver ON public.bookings(with_driver);
CREATE INDEX IF NOT EXISTS idx_bookings_driver_id ON public.bookings(driver_id);

COMMIT;
