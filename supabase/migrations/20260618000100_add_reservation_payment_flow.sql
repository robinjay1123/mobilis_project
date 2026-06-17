alter table public.bookings
add column if not exists reservation_fee_amount numeric(12,2) not null default 1000,
add column if not exists reservation_payment_status text not null default 'not_submitted',
add column if not exists reservation_payment_method text,
add column if not exists reservation_payment_type text not null default 'reservation_only',
add column if not exists reservation_payment_covers_total boolean not null default false,
add column if not exists reservation_payment_reference text,
add column if not exists reservation_payment_proof_url text,
add column if not exists reservation_payment_submitted_at timestamp with time zone,
add column if not exists refund_status text;

create index if not exists idx_bookings_reservation_payment_status
  on public.bookings(reservation_payment_status);

insert into public.app_settings (key, value, description)
values
  ('reservation_payment_amount', '1000', 'Refundable reservation payment required before booking request creation.'),
  ('reservation_payment_qr_url', '', 'Public image URL for the PSDC online banking QR code shown to renters.'),
  ('reservation_payment_account_name', 'PSDC', 'Payment account name shown beside the reservation QR code.'),
  ('reservation_payment_instructions', 'Pay the refundable reservation fee, upload the payment screenshot, and enter the 13-digit transaction reference number.', 'Instructions shown on the reservation payment screen.')
on conflict (key) do nothing;

insert into storage.buckets (id, name, public)
values ('reservation_receipts', 'reservation_receipts', true)
on conflict (id) do nothing;

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
