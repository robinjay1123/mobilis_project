alter table public.user_verifications
  add column if not exists driver_years_experience text,
  add column if not exists driver_previous_companies text;

grant select, insert, update on public.user_verifications to authenticated;
