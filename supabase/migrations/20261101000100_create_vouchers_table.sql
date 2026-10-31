-- Create dynamic vouchers and discount codes table
create table if not exists public.vouchers (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  description text default '',
  discount_percent numeric default 0.0,
  discount_amount numeric default 0.0,
  is_percent boolean not null default true,
  min_trips_required integer not null default 0,
  min_spend numeric default 0.0,
  expires_at timestamptz,
  is_active boolean not null default true,
  max_uses integer,
  used_count integer not null default 0,
  category text not null default 'seasonal', -- 'seasonal', 'loyalty_milestone', 'promo'
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable open access for authenticated users, service role has full access
alter table public.vouchers disable row level security;
grant select, insert, update, delete on public.vouchers to authenticated;
grant all on public.vouchers to service_role;

-- Index for fast lookup by code and active status
create index if not exists idx_vouchers_code on public.vouchers(lower(code));
create index if not exists idx_vouchers_active on public.vouchers(is_active);

-- Seed initial seasonal and loyalty discount vouchers
insert into public.vouchers (code, title, description, discount_percent, discount_amount, is_percent, min_trips_required, min_spend, expires_at, is_active, category)
values
  ('SUMMER2026', 'Summer Getaway 15% OFF', 'Enjoy 15% off your next summer rental trip with PSDC!', 15.0, 0.0, true, 0, 1000.0, now() + interval '90 days', true, 'seasonal'),
  ('WELCOME100', 'Welcome to PSDC ₱100 OFF', '₱100 off your rental trip with PSDC!', 0.0, 100.0, false, 0, 500.0, now() + interval '180 days', true, 'promo'),
  ('PSDC3TRIPS10', '10% OFF Frequent Renter Voucher', 'Unlocked after 3 completed trips with PSDC!', 10.0, 0.0, true, 3, 0.0, null, true, 'loyalty_milestone'),
  ('PSDC5TRIPS500', '₱500 OFF PSDC Loyal Renter Reward', 'Unlocked after 5 completed trips with PSDC!', 0.0, 500.0, false, 5, 0.0, null, true, 'loyalty_milestone'),
  ('PSDCVIP20', '20% OFF PSDC VIP Renter Voucher', 'Unlocked after 10 completed trips with PSDC!', 20.0, 0.0, true, 10, 0.0, null, true, 'loyalty_milestone')
on conflict (code) do nothing;
