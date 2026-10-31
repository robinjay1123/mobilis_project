-- Dynamic loyalty card milestones table for the PSDC 18-stamp card
create table if not exists public.loyalty_card_milestones (
  id uuid primary key default gen_random_uuid(),
  stamp integer not null unique,
  label text not null,
  description text default '',
  reward_type text not null default 'discount', -- 'discount', 'gift', 'free_time'
  discount_amount numeric default 0.0,
  discount_percent numeric default 0.0,
  free_hours integer default 0,
  voucher_code text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.loyalty_card_milestones disable row level security;
grant select, insert, update, delete on public.loyalty_card_milestones to authenticated;
grant all on public.loyalty_card_milestones to service_role;

-- Index
create index if not exists idx_loyalty_card_milestones_stamp on public.loyalty_card_milestones(stamp);

-- Seed default PSDC 18-stamp loyalty card milestones
insert into public.loyalty_card_milestones (stamp, label, description, reward_type, discount_amount, free_hours, voucher_code, is_active)
values
  (3, '₱50 OFF', '₱50 discount reward for 3 completed trips', 'discount', 50.0, 0, 'LOYALTY50', true),
  (6, '₱200 OFF', '₱200 discount reward for 6 completed trips', 'discount', 200.0, 0, 'LOYALTY200', true),
  (8, 'PSDC Mug', 'Official PSDC Mug merchandise prize', 'gift', 0.0, 0, null, true),
  (10, 'PSDC Umbrella', 'Official PSDC Umbrella merchandise prize', 'gift', 0.0, 0, null, true),
  (12, '₱300 OFF', '₱300 discount reward for 12 completed trips', 'discount', 300.0, 0, 'LOYALTY300', true),
  (15, 'Free 3 Hours', 'Free 3 hours additional rental reward', 'free_time', 0.0, 3, 'LOYALTY_FREE3H', true),
  (18, 'Free 24 Hours', 'Free 24 hours full day rental reward', 'free_time', 0.0, 24, 'LOYALTY_FREE24H', true)
on conflict (stamp) do update set
  label = excluded.label,
  description = excluded.description;

-- Update redeem_renter_loyalty_reward function to accept any dynamic milestone stamp (1 to 18)
create or replace function public.redeem_renter_loyalty_reward(
  p_renter_id uuid,
  p_milestone integer
)
returns public.renter_loyalty_rewards
language plpgsql
security definer
set search_path = public
as $$
declare
  completed_trip_count integer;
  loyalty_record public.renter_loyalty_rewards;
begin
  if auth.uid() is distinct from p_renter_id then
    raise exception 'You can only redeem your own loyalty reward';
  end if;

  if p_milestone < 1 or p_milestone > 18 then
    raise exception 'Invalid loyalty reward milestone stamp %', p_milestone;
  end if;

  insert into public.renter_loyalty_rewards (renter_id)
  values (p_renter_id)
  on conflict (renter_id) do nothing;

  select *
    into loyalty_record
  from public.renter_loyalty_rewards
  where renter_id = p_renter_id
  for update;

  if loyalty_record.membership_expires_at < now() then
    raise exception 'This loyalty membership has expired';
  end if;

  select count(*)::integer
    into completed_trip_count
  from public.bookings
  where renter_id = p_renter_id
    and lower(coalesce(status, '')) = 'completed'
    and coalesce(completed_at, created_at) >= loyalty_record.membership_started_at
    and coalesce(completed_at, created_at) <= loyalty_record.membership_expires_at;

  if completed_trip_count < p_milestone then
    raise exception 'Complete % successful trips before redeeming this reward', p_milestone;
  end if;

  if not (p_milestone = any(loyalty_record.redeemed_milestones)) then
    update public.renter_loyalty_rewards
    set redeemed_milestones = array_append(redeemed_milestones, p_milestone),
        reward_status = case when p_milestone = 18 then 'redeemed' else 'locked' end,
        redeemed_at = now(),
        updated_at = now()
    where renter_id = p_renter_id
    returning * into loyalty_record;
  end if;

  return loyalty_record;
end;
$$;

grant execute on function public.redeem_renter_loyalty_reward(uuid, integer) to authenticated;
grant execute on function public.redeem_renter_loyalty_reward(uuid, integer) to service_role;

