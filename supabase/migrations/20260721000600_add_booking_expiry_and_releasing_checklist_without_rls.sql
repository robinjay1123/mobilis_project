-- Detailed unit releasing records and unattended-booking expiry.
-- RLS intentionally remains disabled while cross-role testing is in progress.

alter table public.booking_vehicle_inspections
  add column if not exists tires_details text,
  add column if not exists mags_details text,
  add column if not exists autosweep_balance text,
  add column if not exists easytrip_balance text,
  add column if not exists other_items text,
  add column if not exists section_remarks jsonb not null default '{}'::jsonb;

alter table public.booking_vehicle_inspections disable row level security;
grant all on table public.booking_vehicle_inspections
  to anon, authenticated, service_role;

alter table public.bookings
  add column if not exists action_deadline timestamptz default (now() + interval '48 hours'),
  add column if not exists auto_cancelled_at timestamptz,
  add column if not exists auto_cancel_reason text,
  add column if not exists refund_processed_at timestamptz;

update public.bookings
set action_deadline = coalesce(created_at::timestamptz, now()) + interval '48 hours'
where lower(coalesce(status, 'pending')) = 'pending'
  and action_deadline is null;

create index if not exists idx_bookings_pending_action_deadline
  on public.bookings(action_deadline)
  where lower(coalesce(status, '')) = 'pending';

create table if not exists public.booking_refunds (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  renter_id uuid references public.users(id) on delete set null,
  amount numeric(12, 2) not null default 0,
  payment_reference text,
  status text not null default 'pending_disbursement'
    check (status in ('pending_disbursement', 'processed', 'not_required')),
  reason text not null,
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.booking_refunds disable row level security;
grant all on table public.booking_refunds to anon, authenticated, service_role;

create index if not exists idx_booking_refunds_status
  on public.booking_refunds(status, requested_at desc);

create or replace function public.process_expired_pending_bookings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  expired_booking record;
  responsible_user_id uuid;
  refund_amount numeric(12, 2);
  has_payment boolean;
  processed_count integer := 0;
begin
  for expired_booking in
    select
      b.*,
      v.owner_id as vehicle_owner_id,
      lower(coalesce(owner_user.role, '')) as vehicle_owner_role,
      trim(concat_ws(' ', v.brand, v.model)) as vehicle_title
    from public.bookings b
    left join public.vehicles v on v.id = b.vehicle_id
    left join public.users owner_user on owner_user.id = v.owner_id
    where lower(coalesce(b.status, 'pending')) = 'pending'
      and coalesce(
        b.action_deadline,
        b.created_at::timestamptz + interval '48 hours'
      ) <= now()
    for update of b skip locked
  loop
    has_payment :=
      lower(coalesce(expired_booking.reservation_payment_status, 'not_submitted'))
        not in ('', 'not_submitted', 'rejected', 'failed')
      or nullif(trim(coalesce(expired_booking.reservation_payment_reference, '')), '')
        is not null
      or nullif(trim(coalesce(expired_booking.reservation_payment_proof_url, '')), '')
        is not null;

    refund_amount := case
      when not has_payment then 0
      when expired_booking.reservation_payment_covers_total is true then
        coalesce(expired_booking.total_price, expired_booking.total_cost, 0)
      else coalesce(expired_booking.reservation_fee_amount, 0)
    end;

    update public.bookings
    set
      status = 'cancelled',
      auto_cancelled_at = now(),
      auto_cancel_reason = 'No operator or partner action within 48 hours',
      refund_status = case
        when has_payment then 'refund_needed'
        else 'not_required'
      end,
      updated_at = now()
    where id = expired_booking.id;

    update public.conversations
    set status = 'closed', updated_at = now()
    where booking_id = expired_booking.id;

    if has_payment then
      insert into public.booking_refunds (
        booking_id,
        renter_id,
        amount,
        payment_reference,
        status,
        reason
      ) values (
        expired_booking.id,
        expired_booking.renter_id,
        refund_amount,
        expired_booking.reservation_payment_reference,
        'pending_disbursement',
        'Booking automatically cancelled after 48 hours without action'
      )
      on conflict (booking_id) do update set
        amount = excluded.amount,
        payment_reference = excluded.payment_reference,
        status = 'pending_disbursement',
        reason = excluded.reason,
        requested_at = now(),
        updated_at = now();
    end if;

    insert into public.notifications (
      user_id,
      title,
      message,
      type,
      data,
      created_at
    ) values (
      expired_booking.renter_id,
      'Booking Auto-Cancelled',
      case
        when has_payment then
          format(
            'Your booking for %s was cancelled because it received no action within 48 hours. PHP %s is queued for refund review.',
            coalesce(nullif(expired_booking.vehicle_title, ''), 'your vehicle'),
            to_char(refund_amount, 'FM999G999G990D00')
          )
        else
          format(
            'Your booking for %s was cancelled because it received no action within 48 hours.',
            coalesce(nullif(expired_booking.vehicle_title, ''), 'your vehicle')
          )
      end,
      'booking_auto_cancelled',
      jsonb_build_object(
        'booking_id', expired_booking.id,
        'status', 'cancelled',
        'refund_status', case when has_payment then 'refund_needed' else 'not_required' end,
        'refund_amount', refund_amount
      ),
      now()
    );

    responsible_user_id := case
      when expired_booking.vehicle_owner_role = 'partner'
        then expired_booking.vehicle_owner_id
      else expired_booking.operator_id
    end;

    if responsible_user_id is not null then
      insert into public.notifications (
        user_id,
        title,
        message,
        type,
        data,
        created_at
      ) values (
        responsible_user_id,
        'Booking Expired',
        format(
          'Booking #%s was automatically cancelled after 48 hours without action.',
          upper(left(expired_booking.id::text, 8))
        ),
        'booking_auto_cancelled',
        jsonb_build_object(
          'booking_id', expired_booking.id,
          'status', 'cancelled',
          'refund_required', has_payment
        ),
        now()
      );
    elsif expired_booking.vehicle_owner_role <> 'partner' then
      insert into public.notifications (
        user_id,
        title,
        message,
        type,
        data,
        created_at
      )
      select
        u.id,
        'Booking Expired',
        format(
          'Booking #%s was automatically cancelled after 48 hours without action.',
          upper(left(expired_booking.id::text, 8))
        ),
        'booking_auto_cancelled',
        jsonb_build_object(
          'booking_id', expired_booking.id,
          'status', 'cancelled',
          'refund_required', has_payment
        ),
        now()
      from public.users u
      where lower(coalesce(u.role, '')) in ('operator', 'admin');
    end if;

    processed_count := processed_count + 1;
  end loop;

  return processed_count;
end;
$$;

grant execute on function public.process_expired_pending_bookings()
  to anon, authenticated, service_role;

-- Supabase projects normally expose pg_cron. If it is unavailable, the app
-- also invokes the same idempotent function when booking screens refresh.
do $$
declare
  existing_job_id bigint;
begin
  create extension if not exists pg_cron with schema extensions;

  select jobid into existing_job_id
  from cron.job
  where jobname = 'expire-unattended-bookings'
  limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'expire-unattended-bookings',
    '*/15 * * * *',
    'select public.process_expired_pending_bookings();'
  );
exception
  when others then
    raise notice 'Could not schedule unattended booking cleanup: %', sqlerrm;
end;
$$;
