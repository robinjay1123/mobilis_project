-- Testing-phase verification fields. No new RLS policies are introduced.

alter table public.user_verifications
  add column if not exists id_front_url text,
  add column if not exists id_back_url text,
  add column if not exists face_selfie_url text,
  add column if not exists selfie_with_id_url text;

grant select, insert, update on public.user_verifications to authenticated;
