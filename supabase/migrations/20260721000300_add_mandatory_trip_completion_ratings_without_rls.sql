-- Testing-phase completion workflow. Access is intentionally not restricted
-- with RLS so every participating role can exercise the end-to-end flow.
alter table public.bookings
  add column if not exists completion_stage text not null default 'not_started',
  add column if not exists final_payment_status text not null default 'pending',
  add column if not exists final_payment_confirmed_at timestamptz,
  add column if not exists final_payment_confirmed_by uuid,
  add column if not exists completion_rating_average numeric(3,2),
  add column if not exists completion_rating_count integer not null default 0,
  add column if not exists commission_status text not null default 'not_ready',
  add column if not exists commission_eligible_at timestamptz;

create index if not exists idx_bookings_completion_stage
  on public.bookings(completion_stage);

create index if not exists idx_bookings_final_payment_status
  on public.bookings(final_payment_status);

alter table public.trip_ratings disable row level security;

-- Existing fully-paid reservations should not be asked to pay a second time.
update public.bookings
set
  final_payment_status = 'paid',
  final_payment_confirmed_at = coalesce(
    final_payment_confirmed_at,
    reservation_payment_submitted_at,
    updated_at,
    created_at
  )
where reservation_payment_covers_total = true
  and lower(coalesce(reservation_payment_status, '')) in (
    'approved',
    'confirmed',
    'paid',
    'verified'
  )
  and final_payment_status <> 'paid';

-- Keep historical completed records as completed. New returns pass through
-- the mandatory payment and rating workflow managed by the application.
update public.bookings
set completion_stage = 'completed'
where lower(coalesce(status, '')) in ('completed', 'successful', 'success')
  and completion_stage = 'not_started';
