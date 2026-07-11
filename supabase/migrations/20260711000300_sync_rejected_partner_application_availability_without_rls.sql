-- Keep the partner-side "Car Posted" source synchronized for existing rows.
-- No RLS policies are added or changed.
update public.partner_vehicle_applications
set is_available = false,
    updated_at = now()
where application_status = 'rejected' or status = 'rejected';

