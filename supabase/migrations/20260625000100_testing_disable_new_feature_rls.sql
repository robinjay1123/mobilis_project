-- Testing-phase access only. Authorization remains enforced in the app layer.
-- Replace this with reviewed RLS policies before production deployment.

alter table if exists public.emergency_contacts disable row level security;
alter table if exists public.booking_vehicle_inspections disable row level security;

grant select, insert, update, delete on public.emergency_contacts
  to authenticated;
grant select, insert, update, delete on public.booking_vehicle_inspections
  to authenticated;
