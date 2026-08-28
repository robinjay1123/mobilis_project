-- ============================================================================
-- Migration: 20260829000100_optimize_database_performance_indexes.sql
-- Purpose: Optimize Supabase PostgreSQL indexes to eliminate full table scans,
-- reduce Disk I/O, prevent statement timeouts (57014), and speed up high-frequency
-- lookups across bookings, vehicles, messages, settlements, and verifications.
-- ============================================================================

-- 1. BOOKINGS INDEXES
-- Optimize queries by partner, partner vehicle, owner, and compound status queries
create index if not exists idx_bookings_partner_id
  on public.bookings using btree (partner_id)
  where partner_id is not null;

create index if not exists idx_bookings_partner_vehicle_id
  on public.bookings using btree (partner_vehicle_id)
  where partner_vehicle_id is not null;

create index if not exists idx_bookings_owner_id
  on public.bookings using btree (owner_id)
  where owner_id is not null;

create index if not exists idx_bookings_renter_created_at
  on public.bookings using btree (renter_id, created_at desc);

create index if not exists idx_bookings_status_created_at
  on public.bookings using btree (status, created_at desc);

create index if not exists idx_bookings_driver_status
  on public.bookings using btree (driver_id, status)
  where driver_id is not null;

create index if not exists idx_bookings_extension_status
  on public.bookings using btree (extension_status)
  where extension_status is not null and extension_status != 'none';

-- 2. PARTNER VEHICLES INDEXES
-- Accelerate partner fleet listings and availability lookups
create index if not exists idx_partner_vehicles_partner_id
  on public.partner_vehicles using btree (partner_id);

create index if not exists idx_partner_vehicles_status_avail
  on public.partner_vehicles using btree (status, is_available, is_posted);

create index if not exists idx_partner_vehicles_user_id
  on public.partner_vehicles using btree (user_id)
  where user_id is not null;

create index if not exists idx_partner_vehicles_owner_id
  on public.partner_vehicles using btree (owner_id)
  where owner_id is not null;

-- 3. CONVERSATIONS & MESSAGING INDEXES
-- Accelerate user conversation discovery and message thread ordering
create index if not exists idx_conversation_participants_user_id
  on public.conversation_participants using btree (user_id);

create index if not exists idx_messages_conv_created_at
  on public.messages using btree (conversation_id, created_at desc);

create index if not exists idx_messages_conv_unread
  on public.messages using btree (conversation_id, is_read)
  where is_read = false;

create index if not exists idx_conversations_user_other
  on public.conversations using btree (user_id, other_user_id);

-- 4. BOOKING SETTLEMENTS & FINANCIAL INDEXES
-- Accelerate financial lookups by booking, partner, driver, and operator
create index if not exists idx_booking_settlements_booking_id
  on public.booking_settlements using btree (booking_id);

create index if not exists idx_booking_settlements_partner_user
  on public.booking_settlements using btree (partner_user_id)
  where partner_user_id is not null;

create index if not exists idx_booking_settlements_driver_user
  on public.booking_settlements using btree (driver_user_id)
  where driver_user_id is not null;

create index if not exists idx_booking_settlements_status
  on public.booking_settlements using btree (status);

-- 5. DRIVER JOB ASSIGNMENTS & VERIFICATIONS
create index if not exists idx_driver_job_assignments_status_offered
  on public.driver_job_assignments using btree (status, offered_at);

create index if not exists idx_user_verifications_user_id
  on public.user_verifications using btree (user_id);

create index if not exists idx_user_verifications_status
  on public.user_verifications using btree (verification_status);

create index if not exists idx_partner_vehicle_apps_status_created
  on public.partner_vehicle_applications using btree (application_status, created_at desc);

create index if not exists idx_trip_ratings_target_vehicle
  on public.trip_ratings using btree (target_vehicle_id)
  where target_vehicle_id is not null;

create index if not exists idx_tracking_locations_active_recent
  on public.tracking_locations using btree (booking_id, recorded_at desc);
