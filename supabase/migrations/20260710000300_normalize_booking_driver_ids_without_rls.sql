-- Testing-phase cleanup: bookings.driver_id must store drivers.user_id because
-- the existing foreign key points to public.drivers(user_id).

update public.bookings b
set driver_id = d.user_id,
    updated_at = now()
from public.drivers d
where b.driver_id = d.id;

update public.driver_job_assignments a
set driver_id = d.user_id,
    updated_at = now()
from public.drivers d
where a.driver_id = d.id;

update public.bookings b
set driver_id = null,
    driver_assigned_at = null,
    updated_at = now()
where b.driver_id is not null
  and not exists (
    select 1
    from public.drivers d
    where d.user_id = b.driver_id
  );

update public.driver_job_assignments a
set status = 'cancelled',
    updated_at = now()
where a.driver_id is not null
  and not exists (
    select 1
    from public.drivers d
    where d.user_id = a.driver_id
  );
