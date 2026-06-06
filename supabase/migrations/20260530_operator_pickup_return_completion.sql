-- Track operator pickup/return actions and completion timestamps.

BEGIN;

ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS picked_up_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS returned_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS completed_at timestamp with time zone;

CREATE INDEX IF NOT EXISTS idx_bookings_picked_up_at
  ON public.bookings(picked_up_at);

CREATE INDEX IF NOT EXISTS idx_bookings_returned_at
  ON public.bookings(returned_at);

CREATE INDEX IF NOT EXISTS idx_bookings_completed_at
  ON public.bookings(completed_at);

NOTIFY pgrst, 'reload schema';

COMMIT;
