-- ==============================================================================
-- Migration: 20260926000100_performance_indexing_and_rls_acceleration.sql
-- Description: Targeted indexes to accelerate Row Level Security (RLS) checks
--              and high-frequency dashboard queries, preventing CPU starvation
--              and database "unhealthy" status during testing.
-- ==============================================================================

-- 1. Accelerate RLS helper functions (is_admin_user, is_operator_user, is_staff_user, is_partner_user)
-- These functions evaluate: WHERE (id = auth.uid() OR lower(email) = lower(auth.jwt() ->> 'email'))
-- Without an expression index on lower(email), Postgres may perform sequential scans on public.users.
CREATE INDEX IF NOT EXISTS idx_users_lower_email
  ON public.users (lower(email));

CREATE INDEX IF NOT EXISTS idx_users_role_lower_email
  ON public.users (role, lower(email));

CREATE INDEX IF NOT EXISTS idx_users_id_role
  ON public.users (id, role);

-- 2. Accelerate global latest tracking lookups (order by recorded_at desc)
CREATE INDEX IF NOT EXISTS idx_tracking_locations_recorded_at_desc
  ON public.tracking_locations (recorded_at DESC);

-- 3. Accelerate bookings updated_at sorting for dashboard & action log feeds
CREATE INDEX IF NOT EXISTS idx_bookings_updated_at_desc
  ON public.bookings (updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_bookings_operator_status
  ON public.bookings (operator_id, status)
  WHERE operator_id IS NOT NULL;

-- 4. Accelerate partner fleet lookups
CREATE INDEX IF NOT EXISTS idx_partner_vehicles_partner_status
  ON public.partner_vehicles (partner_id, status);
