insert into storage.buckets (id, name, public)
values
  ('reservation_qr_codes', 'reservation_qr_codes', true),
  ('reservation_receipts', 'reservation_receipts', true)
on conflict (id) do update set public = excluded.public;

create table if not exists public.reservation_payment_receipts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  renter_id uuid not null references public.users(id) on delete cascade,
  amount numeric(12,2) not null,
  payment_method text not null default 'psdc_qr_payment',
  payment_type text not null default 'reservation_only',
  reference_number text not null,
  proof_url text not null,
  proof_storage_path text,
  status text not null default 'pending_review',
  submitted_at timestamp with time zone not null default now(),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint reservation_payment_receipts_reference_number_check
    check (reference_number ~ '^[0-9]{13}$'),
  constraint reservation_payment_receipts_payment_type_check
    check (payment_type in ('reservation_only', 'full_payment')),
  constraint reservation_payment_receipts_status_check
    check (status in ('pending_review', 'approved', 'rejected', 'refunded'))
);

create index if not exists idx_reservation_payment_receipts_booking_id
  on public.reservation_payment_receipts(booking_id);

create index if not exists idx_reservation_payment_receipts_renter_id
  on public.reservation_payment_receipts(renter_id);

create index if not exists idx_reservation_payment_receipts_status
  on public.reservation_payment_receipts(status);

alter table public.reservation_payment_receipts enable row level security;

drop policy if exists "reservation_payment_receipts_select_own_or_staff"
on public.reservation_payment_receipts;
create policy "reservation_payment_receipts_select_own_or_staff"
on public.reservation_payment_receipts
for select
to authenticated
using (
  renter_id = auth.uid()
  or exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role in ('admin', 'operator')
  )
);

drop policy if exists "reservation_payment_receipts_insert_own"
on public.reservation_payment_receipts;
create policy "reservation_payment_receipts_insert_own"
on public.reservation_payment_receipts
for insert
to authenticated
with check (
  renter_id = auth.uid()
  and exists (
    select 1
    from public.bookings
    where bookings.id = booking_id
      and bookings.renter_id = auth.uid()
  )
);

drop policy if exists "reservation_payment_receipts_update_staff"
on public.reservation_payment_receipts;
create policy "reservation_payment_receipts_update_staff"
on public.reservation_payment_receipts
for update
to authenticated
using (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role in ('admin', 'operator')
  )
)
with check (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role in ('admin', 'operator')
  )
);

drop policy if exists "reservation_qr_codes_select_authenticated"
on storage.objects;
create policy "reservation_qr_codes_select_authenticated"
on storage.objects
for select
to authenticated
using (bucket_id = 'reservation_qr_codes');

drop policy if exists "reservation_qr_codes_insert_admin"
on storage.objects;
create policy "reservation_qr_codes_insert_admin"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'reservation_qr_codes'
  and exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'admin'
  )
);

drop policy if exists "reservation_qr_codes_update_admin"
on storage.objects;
create policy "reservation_qr_codes_update_admin"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'reservation_qr_codes'
  and exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'admin'
  )
)
with check (
  bucket_id = 'reservation_qr_codes'
  and exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'admin'
  )
);

drop policy if exists "reservation_qr_codes_delete_admin"
on storage.objects;
create policy "reservation_qr_codes_delete_admin"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'reservation_qr_codes'
  and exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'admin'
  )
);

drop policy if exists "reservation_receipts_insert_own_folder" on storage.objects;
create policy "reservation_receipts_insert_own_folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'reservation_receipts'
  and (storage.foldername(name))[1] = (auth.uid())::text
);

drop policy if exists "reservation_receipts_select_authenticated" on storage.objects;
create policy "reservation_receipts_select_authenticated"
on storage.objects
for select
to authenticated
using (bucket_id = 'reservation_receipts');

drop policy if exists "reservation_receipts_update_own_folder" on storage.objects;
create policy "reservation_receipts_update_own_folder"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'reservation_receipts'
  and (storage.foldername(name))[1] = (auth.uid())::text
)
with check (
  bucket_id = 'reservation_receipts'
  and (storage.foldername(name))[1] = (auth.uid())::text
);
