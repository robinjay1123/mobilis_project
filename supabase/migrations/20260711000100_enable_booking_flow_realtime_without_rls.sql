-- Realtime publication only. This does not enable or add RLS policies.
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'bookings',
    'driver_job_assignments',
    'notifications',
    'conversations',
    'conversation_participants',
    'messages'
  ]
  loop
    if to_regclass(format('public.%I', v_table)) is not null
       and not exists (
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
  end loop;
end
$$;
