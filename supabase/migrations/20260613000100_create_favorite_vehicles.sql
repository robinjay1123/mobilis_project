create table if not exists public.favorite_vehicles (
  user_id uuid not null references public.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, vehicle_id)
);

alter table public.favorite_vehicles enable row level security;

drop policy if exists "Users can view their favorite vehicles" on public.favorite_vehicles;
create policy "Users can view their favorite vehicles"
  on public.favorite_vehicles
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can add their favorite vehicles" on public.favorite_vehicles;
create policy "Users can add their favorite vehicles"
  on public.favorite_vehicles
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can remove their favorite vehicles" on public.favorite_vehicles;
create policy "Users can remove their favorite vehicles"
  on public.favorite_vehicles
  for delete
  using (auth.uid() = user_id);
