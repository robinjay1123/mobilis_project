-- Migration: 20260920000200_add_telemetry_pruning_and_maintenance.sql
-- Description: Automated GPS telemetry data pruning job and maintenance RPC.
-- Purges high-frequency location logs older than the retention period (default 60 days)
-- while preserving all critical safety incident records (trip_safety_events).

CREATE OR REPLACE FUNCTION public.prune_old_tracking_logs(
    p_retention_days INTEGER DEFAULT 60,
    p_batch_limit INTEGER DEFAULT 10000
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_deleted_count INTEGER := 0;
    v_cutoff_timestamp TIMESTAMPTZ;
BEGIN
    -- Calculate the cutoff date based on retention days
    v_cutoff_timestamp := now() - (COALESCE(p_retention_days, 60) || ' days')::INTERVAL;

    -- Delete old location breadcrumbs in bounded batches to avoid transaction log lockup
    WITH deleted_rows AS (
        DELETE FROM public.tracking_location_logs
        WHERE id IN (
            SELECT tll.id
            FROM public.tracking_location_logs tll
            LEFT JOIN public.bookings b ON b.id = tll.booking_id
            WHERE tll.recorded_at < v_cutoff_timestamp
              AND (
                  b.id IS NULL -- Orphaned logs
                  OR b.status IN ('completed', 'cancelled', 'returned', 'rejected', 'expired')
                  OR tll.recorded_at < (now() - INTERVAL '120 days') -- Hard safety limit for unclosed trips
              )
            LIMIT p_batch_limit
        )
        RETURNING id
    )
    SELECT count(*) INTO v_deleted_count FROM deleted_rows;

    -- Log maintenance action in audit logs if the table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'admin_audit_logs'
    ) THEN
        INSERT INTO public.admin_audit_logs (
            action,
            entity_type,
            notes,
            metadata
        ) VALUES (
            'telemetry_pruned',
            'tracking_location_logs',
            format('Pruned %s old tracking location logs older than %s days', v_deleted_count, p_retention_days),
            jsonb_build_object(
                'deleted_count', v_deleted_count,
                'retention_days', p_retention_days,
                'cutoff_timestamp', v_cutoff_timestamp
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_count', v_deleted_count,
        'retention_days', p_retention_days,
        'cutoff_timestamp', v_cutoff_timestamp,
        'executed_at', now()
    );
END;
$$;

-- Grant execution permissions for maintenance RPC
GRANT EXECUTE ON FUNCTION public.prune_old_tracking_logs(INTEGER, INTEGER) TO authenticated, service_role, anon;

-- Setup scheduled execution via pg_cron if available on the Supabase instance
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
    ) THEN
        -- Remove existing job if already registered to avoid duplication
        PERFORM cron.unschedule('daily_telemetry_prune');
        
        -- Schedule daily execution at 03:00 UTC
        PERFORM cron.schedule(
            'daily_telemetry_prune',
            '0 3 * * *',
            'SELECT public.prune_old_tracking_logs(60, 20000);'
        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Safely ignore if cron extension permissions are restricted on the current tier
        RAISE NOTICE 'pg_cron schedule setup skipped or not permitted: %', SQLERRM;
END $$;
