create table if not exists public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  full_name text not null,
  phone_number text not null,
  relationship text not null,
  is_default boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create index if not exists idx_emergency_contacts_user_id
  on public.emergency_contacts(user_id);

alter table public.emergency_contacts disable row level security;
grant select, insert, update, delete on public.emergency_contacts
  to authenticated;

drop trigger if exists set_emergency_contacts_updated_at on public.emergency_contacts;
create trigger set_emergency_contacts_updated_at
before update on public.emergency_contacts
for each row
execute function public.set_updated_at();

alter table public.bookings
  add column if not exists emergency_contact_name text,
  add column if not exists emergency_contact_phone text,
  add column if not exists emergency_contact_relationship text;
