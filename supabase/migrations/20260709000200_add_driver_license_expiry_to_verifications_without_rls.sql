alter table public.user_verifications
  add column if not exists driver_license_expiry date;

grant select, insert, update on public.user_verifications to authenticated;
