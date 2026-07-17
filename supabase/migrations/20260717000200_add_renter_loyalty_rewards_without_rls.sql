-- Persist each renter's six-month loyalty membership and reward redemption.
-- RLS remains disabled for the current testing phase.
create table if not exists public.renter_loyalty_rewards (
  renter_id uuid primary key references public.users(id) on delete cascade,
  membership_started_at timestamptz not null default now(),
  membership_expires_at timestamptz not null default (now() + interval '6 months'),
  reward_status text not null default 'locked'
    check (reward_status in ('locked', 'redeemed')),
  redeemed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.renter_loyalty_rewards disable row level security;

grant select, insert, update on public.renter_loyalty_rewards to authenticated;
grant all on public.renter_loyalty_rewards to service_role;

create or replace function public.redeem_renter_loyalty_reward(
  p_renter_id uuid
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

  select count(*)::integer
    into completed_trip_count
  from public.bookings
  where renter_id = p_renter_id
    and lower(coalesce(status, '')) = 'completed';

  if completed_trip_count < 12 then
    raise exception 'Complete 12 successful trips before redeeming this reward';
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

  if loyalty_record.reward_status <> 'redeemed' then
    update public.renter_loyalty_rewards
    set reward_status = 'redeemed',
        redeemed_at = now(),
        updated_at = now()
    where renter_id = p_renter_id
    returning * into loyalty_record;
  end if;

  return loyalty_record;
end;
$$;

revoke all on function public.redeem_renter_loyalty_reward(uuid) from public;
grant execute on function public.redeem_renter_loyalty_reward(uuid) to authenticated;
grant execute on function public.redeem_renter_loyalty_reward(uuid) to service_role;
