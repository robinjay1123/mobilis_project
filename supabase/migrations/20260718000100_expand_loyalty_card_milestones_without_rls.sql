-- Expand the renter loyalty card to match the 18-stamp PSDC loyalty card.
-- RLS remains disabled during the current testing phase.
alter table public.renter_loyalty_rewards
  add column if not exists redeemed_milestones integer[] not null default '{}';

-- Preserve the legacy 12-trip reward if it was claimed before this upgrade.
update public.renter_loyalty_rewards
set redeemed_milestones = array[12]
where reward_status = 'redeemed'
  and cardinality(redeemed_milestones) = 0;

alter table public.renter_loyalty_rewards disable row level security;

grant select, insert, update on public.renter_loyalty_rewards to authenticated;
grant all on public.renter_loyalty_rewards to service_role;

drop function if exists public.redeem_renter_loyalty_reward(uuid);

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

  if p_milestone not in (3, 6, 8, 10, 12, 15, 18) then
    raise exception 'Invalid loyalty reward milestone';
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

revoke all on function public.redeem_renter_loyalty_reward(uuid, integer) from public;
grant execute on function public.redeem_renter_loyalty_reward(uuid, integer) to authenticated;
grant execute on function public.redeem_renter_loyalty_reward(uuid, integer) to service_role;
