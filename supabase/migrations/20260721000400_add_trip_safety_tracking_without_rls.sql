-- Participant navigation and append-only trip safety evidence.
-- RLS remains disabled while the project is in its requested testing phase.

alter table public.bookings
  add column if not exists pickup_latitude double precision,
  add column if not exists pickup_longitude double precision,
  add column if not exists dropoff_latitude double precision,
  add column if not exists dropoff_longitude double precision;

create table if not exists public.tracking_location_logs (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  tracked_user_id uuid references public.users(id) on delete set null,
  latitude double precision not null,
  longitude double precision not null,
  accuracy_meters double precision,
  speed_mps double precision,
  heading_degrees double precision,
  source text not null default 'driver_app',
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.trip_safety_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  event_type text not null,
  severity text not null default 'warning',
  title text not null,
  message text not null,
  latitude double precision,
  longitude double precision,
  speed_kph double precision,
  details jsonb not null default '{}'::jsonb,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists tracking_location_logs_booking_recorded_idx
  on public.tracking_location_logs (booking_id, recorded_at desc);
create index if not exists trip_safety_events_booking_created_idx
  on public.trip_safety_events (booking_id, created_at desc);
create index if not exists trip_safety_events_type_idx
  on public.trip_safety_events (event_type, created_at desc);

alter table public.tracking_location_logs disable row level security;
alter table public.trip_safety_events disable row level security;

grant select, insert, update, delete on public.tracking_location_logs to authenticated;
grant select, insert, update, delete on public.trip_safety_events to authenticated;
grant select, insert, update, delete on public.tracking_location_logs to service_role;
grant select, insert, update, delete on public.trip_safety_events to service_role;
