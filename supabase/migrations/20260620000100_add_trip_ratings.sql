insert into storage.buckets (id, name, public)
values ('trip_review_images', 'trip_review_images', true)
on conflict (id) do update set public = excluded.public;

alter table public.users
  add column if not exists rating numeric(3,2) not null default 0,
  add column if not exists rating_count integer not null default 0;

alter table public.drivers
  add column if not exists rating_count integer not null default 0;

alter table public.partners
  add column if not exists rating numeric(3,2) not null default 0,
  add column if not exists rating_count integer not null default 0;

alter table public.renters
  add column if not exists rating numeric(3,2) not null default 0,
  add column if not exists rating_count integer not null default 0;

create table if not exists public.trip_ratings (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  reviewer_user_id uuid not null references public.users(id) on delete cascade,
  reviewer_role text not null,
  target_user_id uuid not null references public.users(id) on delete cascade,
  target_role text not null,
  rating numeric(2,1) not null,
  comment text not null default '',
  tags text[] not null default '{}',
  image_urls text[] not null default '{}',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint trip_ratings_rating_check check (rating >= 1 and rating <= 5),
  constraint trip_ratings_reviewer_role_check
    check (reviewer_role in ('renter', 'driver', 'partner', 'operator')),
  constraint trip_ratings_target_role_check
    check (target_role in ('renter', 'driver', 'partner', 'operator')),
  constraint trip_ratings_unique_review
    unique (booking_id, reviewer_user_id, target_user_id, target_role)
);

create index if not exists idx_trip_ratings_booking_id
  on public.trip_ratings(booking_id);

create index if not exists idx_trip_ratings_target_user_id
  on public.trip_ratings(target_user_id);

create index if not exists idx_trip_ratings_reviewer_user_id
  on public.trip_ratings(reviewer_user_id);

alter table public.trip_ratings enable row level security;

drop policy if exists "trip_ratings_select_related" on public.trip_ratings;
create policy "trip_ratings_select_related"
on public.trip_ratings
for select
to authenticated
using (
  reviewer_user_id = auth.uid()
  or target_user_id = auth.uid()
  or exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role in ('admin', 'operator')
  )
);

drop policy if exists "trip_ratings_insert_own" on public.trip_ratings;
create policy "trip_ratings_insert_own"
on public.trip_ratings
for insert
to authenticated
with check (reviewer_user_id = auth.uid());

drop policy if exists "trip_ratings_update_staff" on public.trip_ratings;
create policy "trip_ratings_update_staff"
on public.trip_ratings
for update
to authenticated
using (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role in ('admin', 'operator')
  )
)
with check (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role in ('admin', 'operator')
  )
);

drop policy if exists "trip_review_images_select_authenticated" on storage.objects;
create policy "trip_review_images_select_authenticated"
on storage.objects
for select
to authenticated
using (bucket_id = 'trip_review_images');

drop policy if exists "trip_review_images_insert_own_folder" on storage.objects;
create policy "trip_review_images_insert_own_folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'trip_review_images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "trip_review_images_update_own_folder" on storage.objects;
create policy "trip_review_images_update_own_folder"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'trip_review_images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'trip_review_images'
  and (storage.foldername(name))[1] = auth.uid()::text
);
