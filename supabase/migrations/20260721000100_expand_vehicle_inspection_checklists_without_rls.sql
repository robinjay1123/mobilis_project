alter table public.booking_vehicle_inspections
  add column if not exists checklist_items jsonb not null default '{}'::jsonb,
  add column if not exists released_by text,
  add column if not exists received_by text,
  add column if not exists completed_at timestamp with time zone;

alter table public.booking_vehicle_inspections disable row level security;

grant select, insert, update, delete on public.booking_vehicle_inspections
  to authenticated;

