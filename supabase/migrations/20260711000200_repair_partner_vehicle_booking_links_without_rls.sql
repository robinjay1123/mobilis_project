-- Testing-phase data repair only. This migration does not enable or add RLS.

-- Rejected applications must never leave either vehicle copy rentable.
update public.partner_vehicles pv
set status = 'disabled',
    is_available = false,
    updated_at = now()
from public.partner_vehicle_applications pva
where (pva.application_status = 'rejected' or pva.status = 'rejected')
  and (
    pva.partner_vehicle_id = pv.id
    or (
      pva.plate_number is not null
      and upper(trim(pva.plate_number)) = upper(trim(pv.plate_number))
    )
  );

update public.vehicles v
set status = 'inactive',
    is_available = false,
    is_posted = false
from public.partner_vehicle_applications pva
where v.owner_role = 'partner'
  and (pva.application_status = 'rejected' or pva.status = 'rejected')
  and (
    pva.created_vehicle_id = v.id
    or (
      pva.plate_number is not null
      and upper(trim(pva.plate_number)) = upper(trim(v.plate_number))
    )
  );

-- Older approvals created only partner_vehicles rows. Backfill the canonical
-- vehicles row required by bookings.vehicle_id and link all related records.
do $$
declare
  item record;
  canonical_vehicle_id uuid;
begin
  for item in
    select distinct on (pv.id)
      pv.*,
      p.user_id as owner_user_id,
      p.address as partner_address,
      pva.id as application_id
    from public.partner_vehicles pv
    join public.partners p on p.id = pv.partner_id
    join public.partner_vehicle_applications pva
      on pva.partner_vehicle_id = pv.id
      or (
        pva.plate_number is not null
        and upper(trim(pva.plate_number)) = upper(trim(pv.plate_number))
      )
    where (pva.application_status = 'approved' or pva.status = 'approved')
      and not (pva.application_status = 'rejected' or pva.status = 'rejected')
    order by pv.id, pva.reviewed_at desc nulls last, pva.created_at desc
  loop
    canonical_vehicle_id := item.vehicle_id;

    if canonical_vehicle_id is null then
      select v.id
      into canonical_vehicle_id
      from public.vehicles v
      where v.owner_role = 'partner'
        and v.owner_id = item.owner_user_id
        and upper(trim(v.plate_number)) = upper(trim(item.plate_number))
      order by v.created_at desc
      limit 1;
    end if;

    if canonical_vehicle_id is null then
      insert into public.vehicles (
        owner_id,
        owner_role,
        vehicle_name,
        brand,
        model,
        year,
        plate_number,
        price_per_day,
        price_per_hour,
        status,
        is_available,
        is_posted,
        seats,
        fuel_type,
        transmission,
        location,
        owner_is_driver
      ) values (
        item.owner_user_id,
        'partner',
        trim(concat(coalesce(item.brand, ''), ' ', coalesce(item.model, ''))),
        item.brand,
        item.model,
        item.year,
        item.plate_number,
        item.price_per_day,
        item.price_per_hour,
        'available',
        item.is_available,
        true,
        coalesce(item.seats, 5),
        coalesce(item.fuel_type, 'Gasoline'),
        coalesce(item.transmission, 'Manual'),
        item.partner_address,
        coalesce(item.owner_is_driver, false)
      ) returning id into canonical_vehicle_id;
    else
      update public.vehicles
      set status = 'available',
          is_posted = true,
          is_available = item.is_available
      where id = canonical_vehicle_id;
    end if;

    update public.partner_vehicles
    set vehicle_id = canonical_vehicle_id
    where id = item.id;

    update public.partner_vehicle_applications
    set partner_vehicle_id = item.id,
        created_vehicle_id = canonical_vehicle_id
    where id = item.application_id;

    update public.vehicle_images
    set vehicle_id = canonical_vehicle_id
    where partner_vehicle_id = item.id
      and vehicle_id is null;
  end loop;
end $$;
