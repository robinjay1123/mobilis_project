-- Migration: Auto-expire driver job assignments after 10 minutes
-- Enables auto-decline/expiry of unanswered driver job offers so operator or partner can re-assign

-- 1. Add expires_at column to driver_job_assignments if not exists
ALTER TABLE public.driver_job_assignments
ADD COLUMN IF NOT EXISTS expires_at timestamp with time zone;

-- 2. Populate expires_at for existing pending offers
UPDATE public.driver_job_assignments
SET expires_at = COALESCE(offered_at, created_at, CURRENT_TIMESTAMP) + INTERVAL '10 minutes'
WHERE expires_at IS NULL AND status IN ('pending_offer', 'assigned');

-- 3. Create index for fast expiration sweeps
CREATE INDEX IF NOT EXISTS idx_driver_job_assignments_expires_at
ON public.driver_job_assignments (status, expires_at);

-- 4. PostgreSQL function to expire stale driver job assignments
CREATE OR REPLACE FUNCTION public.expire_stale_driver_job_assignments()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_expired_count integer := 0;
    r RECORD;
    v_now timestamp with time zone := CURRENT_TIMESTAMP;
BEGIN
    FOR r IN
        SELECT
            dja.id,
            dja.booking_id,
            dja.driver_id
        FROM public.driver_job_assignments dja
        WHERE dja.status IN ('pending_offer', 'assigned')
          AND (
            (dja.expires_at IS NOT NULL AND dja.expires_at <= v_now)
            OR (dja.offered_at IS NOT NULL AND dja.offered_at <= v_now - INTERVAL '10 minutes')
            OR (dja.created_at IS NOT NULL AND dja.created_at <= v_now - INTERVAL '10 minutes')
          )
    LOOP
        -- 1. Mark assignment as expired / auto-declined
        UPDATE public.driver_job_assignments
        SET status = 'expired',
            rejection_reason = 'Auto-declined: 10-minute driver acceptance window expired',
            replied_at = v_now,
            updated_at = v_now
        WHERE id = r.id;

        -- 2. Reset booking's driver_id and return status to pending if still awaiting driver response
        UPDATE public.bookings
        SET driver_id = NULL,
            status = 'pending',
            updated_at = v_now
        WHERE id = r.booking_id
          AND (driver_id = r.driver_id OR driver_id IS NULL)
          AND status IN ('pending', 'awaiting_driver', 'pending_approval');

        -- 3. Restore driver availability in both users and drivers tables
        IF r.driver_id IS NOT NULL THEN
            UPDATE public.users
            SET is_available = true
            WHERE id = r.driver_id;

            UPDATE public.drivers
            SET is_available = true
            WHERE user_id = r.driver_id OR id = r.driver_id;
        END IF;

        v_expired_count := v_expired_count + 1;
    END LOOP;

    RETURN v_expired_count;
END;
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.expire_stale_driver_job_assignments() TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_driver_job_assignments() TO anon;
GRANT EXECUTE ON FUNCTION public.expire_stale_driver_job_assignments() TO service_role;
