-- Realtime transport for operator-facing data. This does not enable RLS or
-- create policies; it only publishes changes that the client already reads.
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'vehicles',
    'vehicle_images',
    'vehicle_applications',
    'partner_vehicles',
    'partner_vehicle_applications',
    'drivers',
    'tracking_locations'
  ]
  loop
    if to_regclass(format('public.%I', v_table)) is not null then
      execute format(
        'alter table public.%I replica identity full',
        v_table
      );

      if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = v_table
      ) then
        execute format(
          'alter publication supabase_realtime add table public.%I',
          v_table
        );
      end if;
    end if;
  end loop;
end
$$;
