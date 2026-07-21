-- Completion-time accounting ledger. This migration intentionally does not
-- enable RLS while the project is in its cross-role testing phase.
create table if not exists public.booking_settlements (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  gross_amount numeric(12, 2) not null default 0,
  rental_amount numeric(12, 2) not null default 0,
  delivery_amount numeric(12, 2) not null default 0,
  late_fee_amount numeric(12, 2) not null default 0,
  platform_commission numeric(12, 2) not null default 0,
  partner_user_id uuid references public.users(id) on delete set null,
  partner_amount numeric(12, 2) not null default 0,
  operator_user_id uuid references public.users(id) on delete set null,
  operator_managed_amount numeric(12, 2) not null default 0,
  driver_user_id uuid references public.users(id) on delete set null,
  driver_gross_amount numeric(12, 2) not null default 0,
  driver_commission_amount numeric(12, 2) not null default 0,
  driver_amount numeric(12, 2) not null default 0,
  status text not null default 'pending'
    check (status in ('pending', 'released', 'voided')),
  released_at timestamptz,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.booking_payouts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  recipient_user_id uuid not null references public.users(id) on delete cascade,
  recipient_role text not null check (recipient_role in ('partner', 'driver')),
  gross_amount numeric(12, 2) not null default 0,
  deductions numeric(12, 2) not null default 0,
  net_amount numeric(12, 2) not null default 0,
  status text not null default 'released'
    check (status in ('pending', 'released', 'voided')),
  released_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (booking_id, recipient_user_id, recipient_role)
);

alter table public.driver_earnings
  add column if not exists booking_id uuid references public.bookings(id) on delete cascade;

create unique index if not exists idx_driver_earnings_booking_unique
  on public.driver_earnings(booking_id)
  where booking_id is not null;

create index if not exists idx_booking_settlements_operator
  on public.booking_settlements(operator_user_id, released_at desc);
create index if not exists idx_booking_payouts_recipient
  on public.booking_payouts(recipient_user_id, released_at desc);

alter table public.booking_settlements disable row level security;
alter table public.booking_payouts disable row level security;

grant all on table public.booking_settlements to anon, authenticated, service_role;
grant all on table public.booking_payouts to anon, authenticated, service_role;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'booking_settlements'
  ) then
    alter publication supabase_realtime add table public.booking_settlements;
  end if;
end $$;
