-- Add timestamp-precise booking windows (Asia/Manila aware).
-- These fields allow back-to-back bookings on the same day when the prior
-- booking returns earlier (e.g. 06:00).

BEGIN;

ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS start_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS end_at timestamp with time zone;

-- Backfill from legacy columns if present.
-- Defaults:
-- - start_at: 09:00 on start_date
-- - end_at:   06:00 on end_date
-- Interpreted in Asia/Manila and stored as timestamptz.
DO $$
BEGIN
  IF to_regclass('public.bookings') IS NOT NULL THEN
    -- Only attempt backfill if legacy columns exist.
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'bookings'
        AND column_name IN ('start_date', 'end_date')
    ) THEN
      UPDATE public.bookings
      SET
        start_at = COALESCE(
          start_at,
          (date_trunc('day', start_date)::date + time '09:00') AT TIME ZONE 'Asia/Manila'
        ),
        end_at = COALESCE(
          end_at,
          (date_trunc('day', end_date)::date + time '06:00') AT TIME ZONE 'Asia/Manila'
        )
      WHERE (start_at IS NULL OR end_at IS NULL)
        AND start_date IS NOT NULL
        AND end_date IS NOT NULL;
    END IF;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bookings_start_at ON public.bookings(start_at);
CREATE INDEX IF NOT EXISTS idx_bookings_end_at ON public.bookings(end_at);

NOTIFY pgrst, 'reload schema';

COMMIT;

