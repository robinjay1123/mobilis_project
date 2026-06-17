alter table if exists public.partner_vehicle_applications
  add column if not exists owner_is_driver boolean default false not null;

alter table if exists public.partner_vehicle_applications
  add column if not exists is_available boolean default false not null;

alter table if exists public.partner_vehicles
  add column if not exists owner_is_driver boolean default false not null;

alter table if exists public.partner_vehicles
  add column if not exists is_available boolean default false not null;

alter table if exists public.vehicles
  add column if not exists owner_is_driver boolean default false not null;

create index if not exists idx_partner_vehicle_applications_owner_is_driver
  on public.partner_vehicle_applications(owner_is_driver);

create index if not exists idx_partner_vehicles_is_available
  on public.partner_vehicles(is_available);
