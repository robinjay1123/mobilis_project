-- Vehicle ratings use the vehicle UUID as target_user_id. The original
-- constraint only allowed user target roles and the foreign key only allowed
-- users.id, causing the renter's vehicle-rating step to fail.

alter table public.trip_ratings
  drop constraint if exists trip_ratings_target_role_check;

alter table public.trip_ratings
  add constraint trip_ratings_target_role_check
  check (target_role in ('renter', 'driver', 'partner', 'operator', 'vehicle'));

alter table public.trip_ratings
  drop constraint if exists trip_ratings_target_user_id_fkey;
