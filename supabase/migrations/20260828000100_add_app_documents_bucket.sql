-- Create app_documents storage bucket for legal agreement PDFs and system documents
insert into storage.buckets (id, name, public)
values ('app_documents', 'app_documents', true)
on conflict (id) do update set public = true;

drop policy if exists "allow_all_app_documents" on storage.objects;

create policy "allow_all_app_documents"
on storage.objects
for all
to authenticated, anon
using (bucket_id = 'app_documents')
with check (bucket_id = 'app_documents');
