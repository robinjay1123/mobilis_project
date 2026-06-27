alter table public.bookings
  add column if not exists rental_subtotal numeric,
  add column if not exists delivery_distance_km numeric,
  add column if not exists delivery_rate_per_km numeric,
  add column if not exists delivery_fee numeric default 0,
  add column if not exists late_return_days integer default 0,
  add column if not exists late_return_fee numeric default 0,
  add column if not exists renter_signature_url text,
  add column if not exists renter_signature_text text,
  add column if not exists renter_valid_id_url text,
  add column if not exists renter_selfie_url text,
  add column if not exists co_traveler_name text,
  add column if not exists co_traveler_phone text,
  add column if not exists co_traveler_license text;

alter table public.messages
  add column if not exists attachment_url text,
  add column if not exists attachment_type text,
  add column if not exists attachment_name text,
  add column if not exists attachment_size integer;

insert into storage.buckets (id, name, public)
values ('booking_evidence', 'booking_evidence', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('chat_attachments', 'chat_attachments', false)
on conflict (id) do nothing;

drop policy if exists "booking_evidence_insert_own_folder"
  on storage.objects;
create policy "booking_evidence_insert_own_folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'booking_evidence'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "booking_evidence_select_authenticated"
  on storage.objects;
create policy "booking_evidence_select_authenticated"
on storage.objects
for select
to authenticated
using (bucket_id = 'booking_evidence');

drop policy if exists "chat_attachments_insert_own_folder"
  on storage.objects;
create policy "chat_attachments_insert_own_folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'chat_attachments'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "chat_attachments_select_authenticated"
  on storage.objects;
create policy "chat_attachments_select_authenticated"
on storage.objects
for select
to authenticated
using (bucket_id = 'chat_attachments');

create table if not exists public.booking_vehicle_inspections (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  inspection_type text not null check (inspection_type in ('before', 'after')),
  inspector_id uuid not null references public.users(id) on delete cascade,
  fuel_level text,
  mileage numeric,
  cleanliness text,
  scratches text,
  dents text,
  damages text,
  remarks text,
  evidence_urls jsonb not null default '[]'::jsonb,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  unique (booking_id, inspection_type, inspector_id)
);

create index if not exists idx_booking_vehicle_inspections_booking_id
  on public.booking_vehicle_inspections(booking_id);

alter table public.booking_vehicle_inspections disable row level security;
grant select, insert, update, delete on public.booking_vehicle_inspections
  to authenticated;

drop trigger if exists set_booking_vehicle_inspections_updated_at
  on public.booking_vehicle_inspections;
create trigger set_booking_vehicle_inspections_updated_at
before update on public.booking_vehicle_inspections
for each row
execute function public.set_updated_at();
