-- Testing-phase tracking storage. Access is authenticated but not role-filtered
-- in PostgreSQL; the application limits which booking each role can display.

create table if not exists public.tracking_locations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  tracked_user_id uuid not null references public.users(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  accuracy_meters double precision,
  speed_mps double precision,
  heading_degrees double precision,
  source text not null default 'driver_app',
  recorded_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  unique (booking_id, tracked_user_id)
);

create index if not exists idx_tracking_locations_booking_id
  on public.tracking_locations(booking_id);
create index if not exists idx_tracking_locations_vehicle_id
  on public.tracking_locations(vehicle_id);
create index if not exists idx_tracking_locations_recorded_at
  on public.tracking_locations(recorded_at desc);

alter table public.tracking_locations disable row level security;
grant select, insert, update, delete on public.tracking_locations
  to authenticated;
