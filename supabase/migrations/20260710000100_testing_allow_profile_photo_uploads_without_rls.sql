-- Testing-phase storage access for profile photos and verification images.
-- The previous id_images policies only allowed `verifications/<user-id>/...`,
-- which blocked profile photo uploads under `profile_pictures/<user-id>/...`.
-- Keep this broad only for testing; replace with reviewed bucket policies before production.

insert into storage.buckets (id, name, public)
values ('id_images', 'id_images', true)
on conflict (id) do update
set public = true;

drop policy if exists "id_images_delete_own_folder" on storage.objects;
drop policy if exists "id_images_insert_own_folder" on storage.objects;
drop policy if exists "id_images_select_own_folder" on storage.objects;
drop policy if exists "id_images_update_own_folder" on storage.objects;
drop policy if exists "testing_allow_all_id_images" on storage.objects;

create policy "testing_allow_all_id_images"
on storage.objects
for all
to authenticated
using (bucket_id = 'id_images')
with check (bucket_id = 'id_images');
