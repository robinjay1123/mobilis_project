-- Testing-phase storage setup. The app uses public URLs for document review,
-- booking evidence, vehicle images, receipts, and profile/verification images.
-- Keep these broad only while testing; replace with tighter policies before
-- production.

insert into storage.buckets (id, name, public)
values
  ('booking_evidence', 'booking_evidence', true),
  ('chat_attachments', 'chat_attachments', true),
  ('driver_documents', 'driver_documents', true),
  ('id_images', 'id_images', true),
  ('partner_documents', 'partner_documents', true),
  ('reservation_qr_codes', 'reservation_qr_codes', true),
  ('reservation_receipts', 'reservation_receipts', true),
  ('trip_review_images', 'trip_review_images', true),
  ('vehicle_images', 'vehicle_images', true)
on conflict (id) do update
set public = true;

drop policy if exists "testing_allow_all_booking_evidence" on storage.objects;
drop policy if exists "testing_allow_all_chat_attachments" on storage.objects;
drop policy if exists "testing_allow_all_driver_documents" on storage.objects;
drop policy if exists "testing_allow_all_id_images" on storage.objects;
drop policy if exists "testing_allow_all_partner_documents" on storage.objects;
drop policy if exists "testing_allow_all_reservation_qr_codes" on storage.objects;
drop policy if exists "testing_allow_all_reservation_receipts" on storage.objects;
drop policy if exists "testing_allow_all_trip_review_images" on storage.objects;
drop policy if exists "testing_allow_all_vehicle_images" on storage.objects;

create policy "testing_allow_all_booking_evidence"
on storage.objects
for all
to authenticated
using (bucket_id = 'booking_evidence')
with check (bucket_id = 'booking_evidence');

create policy "testing_allow_all_chat_attachments"
on storage.objects
for all
to authenticated
using (bucket_id = 'chat_attachments')
with check (bucket_id = 'chat_attachments');

create policy "testing_allow_all_driver_documents"
on storage.objects
for all
to authenticated
using (bucket_id = 'driver_documents')
with check (bucket_id = 'driver_documents');

create policy "testing_allow_all_id_images"
on storage.objects
for all
to authenticated
using (bucket_id = 'id_images')
with check (bucket_id = 'id_images');

create policy "testing_allow_all_partner_documents"
on storage.objects
for all
to authenticated
using (bucket_id = 'partner_documents')
with check (bucket_id = 'partner_documents');

create policy "testing_allow_all_reservation_qr_codes"
on storage.objects
for all
to authenticated
using (bucket_id = 'reservation_qr_codes')
with check (bucket_id = 'reservation_qr_codes');

create policy "testing_allow_all_reservation_receipts"
on storage.objects
for all
to authenticated
using (bucket_id = 'reservation_receipts')
with check (bucket_id = 'reservation_receipts');

create policy "testing_allow_all_trip_review_images"
on storage.objects
for all
to authenticated
using (bucket_id = 'trip_review_images')
with check (bucket_id = 'trip_review_images');

create policy "testing_allow_all_vehicle_images"
on storage.objects
for all
to authenticated
using (bucket_id = 'vehicle_images')
with check (bucket_id = 'vehicle_images');
