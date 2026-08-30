-- Create app_releases storage bucket for official Android APK releases
insert into storage.buckets (id, name, public)
values ('app_releases', 'app_releases', true)
on conflict (id) do update set public = true;

drop policy if exists "allow_public_read_app_releases" on storage.objects;
drop policy if exists "allow_authenticated_manage_app_releases" on storage.objects;

-- Allow everyone (anonymous & authenticated) to download APKs
create policy "allow_public_read_app_releases"
on storage.objects
for select
to authenticated, anon
using (bucket_id = 'app_releases');

-- Allow authenticated users / admins to upload APKs
create policy "allow_authenticated_manage_app_releases"
on storage.objects
for all
to authenticated, anon
using (bucket_id = 'app_releases')
with check (bucket_id = 'app_releases');
