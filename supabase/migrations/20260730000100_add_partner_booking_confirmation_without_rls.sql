-- Adds partner booking confirmation gate columns and vehicle rating aggregation.
-- RLS intentionally remains disabled while cross-role testing is in progress.

-- Partner booking confirmation (pre-operator-approval gate for partner vehicles)
alter table public.bookings
  add column if not exists partner_booking_confirmed_at  timestamptz,
  add column if not exists partner_booking_confirmed_by  uuid references public.users(id) on delete set null,
  add column if not exists partner_booking_rejected_at   timestamptz,
  add column if not exists partner_booking_rejection_reason text;

-- Index to quickly find partner-vehicle bookings awaiting confirmation
create index if not exists idx_bookings_partner_pending_confirmation
  on public.bookings(partner_booking_confirmed_at, status)
  where partner_booking_confirmed_at is null
    and lower(coalesce(status, '')) = 'pending';

-- Vehicle rating columns (aggregated from trip_ratings where target_role = 'vehicle')
alter table public.vehicles
  add column if not exists rating       numeric(3, 2) default 0.0,
  add column if not exists rating_count integer        default 0;

-- Index for fast vehicle rating lookups on listing/search screens
create index if not exists idx_vehicles_rating
  on public.vehicles(rating desc nulls last);