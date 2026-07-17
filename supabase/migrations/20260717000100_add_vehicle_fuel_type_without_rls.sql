-- Keep older testing databases compatible with the operator vehicle form.
-- This migration only adds/normalizes the data column; it does not enable RLS.
alter table if exists public.vehicles
  add column if not exists fuel_type text default 'Unleaded';

update public.vehicles
set fuel_type = 'Unleaded'
where fuel_type is null or btrim(fuel_type) = '';

comment on column public.vehicles.fuel_type is
  'Vehicle fuel classification selected during vehicle registration.';
