alter table public.bookings
  add column if not exists operator_trip_confirmed_at timestamptz,
  add column if not exists partner_trip_confirmed_at timestamptz,
  add column if not exists driver_trip_confirmed_at timestamptz,
  add column if not exists renter_trip_confirmed_at timestamptz;

update public.bookings
set
  operator_trip_confirmed_at = coalesce(operator_trip_confirmed_at, completed_at),
  partner_trip_confirmed_at = coalesce(partner_trip_confirmed_at, completed_at),
  driver_trip_confirmed_at = coalesce(driver_trip_confirmed_at, completed_at)
where status = 'completed'
  and completed_at is not null;
