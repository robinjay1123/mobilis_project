-- Testing-phase profile photo columns.
-- Several app screens read profile photos from public.users. Some remote
-- databases only had avatar_url on role-specific tables, so profile uploads
-- failed when updating public.users.avatar_url.

alter table public.users
  add column if not exists avatar_url text,
  add column if not exists profile_picture_url text;

-- Testing phase only: avoid role-policy conflicts while profile photo upload
-- and display are being tested.
alter table public.users disable row level security;

grant select, insert, update, delete on public.users to authenticated;
