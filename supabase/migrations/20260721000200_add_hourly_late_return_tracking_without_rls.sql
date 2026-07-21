alter table public.bookings
  add column if not exists late_return_hours integer not null default 0;

comment on column public.bookings.late_return_hours is
  'Started hours after the scheduled return time. Used with the PHP 300 hourly late-return fee.';
