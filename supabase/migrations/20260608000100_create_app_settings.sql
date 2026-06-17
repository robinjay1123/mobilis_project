create table if not exists public.app_settings (
  key text primary key,
  value text not null,
  description text,
  updated_by uuid references public.users(id) on delete set null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

alter table public.app_settings enable row level security;

drop trigger if exists app_settings_set_updated_at on public.app_settings;
create trigger app_settings_set_updated_at
before update on public.app_settings
for each row
execute function public.set_updated_at();

insert into public.app_settings (key, value, description)
values (
  'rental_terms',
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

By continuing with this booking, the renter agrees to follow the vehicle rental policies, payment requirements, security deposit rules, pickup and return procedures, cancellation terms, damage responsibilities, and any additional instructions provided by Mobilis by PSDC.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer nec odio. Praesent libero. Sed cursus ante dapibus diam.',
  'Terms shown to renters before booking finalization.'
)
on conflict (key) do nothing;

drop policy if exists "app_settings_select_authenticated" on public.app_settings;
create policy "app_settings_select_authenticated"
on public.app_settings
for select
to authenticated
using (true);

drop policy if exists "app_settings_insert_admin" on public.app_settings;
create policy "app_settings_insert_admin"
on public.app_settings
for insert
to authenticated
with check (public.is_admin_user());

drop policy if exists "app_settings_update_admin" on public.app_settings;
create policy "app_settings_update_admin"
on public.app_settings
for update
to authenticated
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists "app_settings_delete_admin" on public.app_settings;
create policy "app_settings_delete_admin"
on public.app_settings
for delete
to authenticated
using (public.is_admin_user());

grant select on public.app_settings to authenticated;
grant insert, update, delete on public.app_settings to authenticated;
grant all on public.app_settings to service_role;

alter table public.bookings
add column if not exists rental_terms_accepted_at timestamp with time zone,
add column if not exists rental_terms_snapshot text;
