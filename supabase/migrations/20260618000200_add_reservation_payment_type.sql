alter table public.bookings
add column if not exists reservation_payment_type text not null default 'reservation_only',
add column if not exists reservation_payment_covers_total boolean not null default false;
