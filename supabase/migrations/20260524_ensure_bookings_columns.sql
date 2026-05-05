-- Ensure all required columns exist in bookings table
-- Add missing columns if they don't exist

BEGIN;

ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  ADD COLUMN IF NOT EXISTS vehicle_id uuid REFERENCES public.vehicles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS renter_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS driver_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS start_date timestamp without time zone,
  ADD COLUMN IF NOT EXISTS end_date timestamp without time zone,
  ADD COLUMN IF NOT EXISTS total_cost numeric(12,2),
  ADD COLUMN IF NOT EXISTS total_price numeric(12,2),
  ADD COLUMN IF NOT EXISTS with_driver boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamp without time zone DEFAULT now();

-- Ensure vehicle_id is not null and has proper index
CREATE INDEX IF NOT EXISTS idx_bookings_vehicle_id ON public.bookings(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_bookings_renter_id ON public.bookings(renter_id);
CREATE INDEX IF NOT EXISTS idx_bookings_driver_id ON public.bookings(driver_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);

COMMIT;
