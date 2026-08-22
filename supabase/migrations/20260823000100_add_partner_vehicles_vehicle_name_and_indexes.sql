-- Ensure partner_vehicles table has vehicle_name column to maintain parity with vehicles table
-- and prevent 42703 (undefined_column) errors from legacy queries or unrefreshed client sessions.

alter table if exists public.partner_vehicles
  add column if not exists vehicle_name text;

-- Backfill vehicle_name from brand and model
update public.partner_vehicles
set vehicle_name = trim(concat(coalesce(brand, ''), ' ', coalesce(model, '')))
where vehicle_name is null or vehicle_name = '';

-- Auto-sync vehicle_name on insert/update of brand or model
create or replace function public.sync_partner_vehicle_name()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.vehicle_name is null or new.vehicle_name = '' then
    new.vehicle_name := trim(concat(coalesce(new.brand, ''), ' ', coalesce(new.model, '')));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_partner_vehicle_name on public.partner_vehicles;
create trigger trg_sync_partner_vehicle_name
before insert or update of brand, model, vehicle_name on public.partner_vehicles
for each row
execute function public.sync_partner_vehicle_name();

create index if not exists idx_partner_vehicles_vehicle_name
  on public.partner_vehicles using btree (vehicle_name);
