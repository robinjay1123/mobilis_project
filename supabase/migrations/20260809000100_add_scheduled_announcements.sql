alter table if exists public.announcements
  add column if not exists announcement_type text not null default 'general',
  add column if not exists status text not null default 'active',
  add column if not exists scheduled_at timestamptz,
  add column if not exists published_at timestamptz,
  add column if not exists expires_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists updated_at timestamptz not null default timezone('utc', now()),
  add column if not exists notification_delivered_at timestamptz;

update public.announcements
set
  announcement_type = coalesce(nullif(announcement_type, ''), 'general'),
  status = coalesce(nullif(status, ''), 'active'),
  published_at = coalesce(published_at, created_at),
  updated_at = coalesce(updated_at, created_at, timezone('utc', now()))
where published_at is null
   or updated_at is null
   or announcement_type is null
   or status is null;

alter table if exists public.announcements
  drop constraint if exists announcements_type_check;

alter table if exists public.announcements
  add constraint announcements_type_check check (
    announcement_type in ('maintenance', 'general', 'system_update', 'emergency')
  );

alter table if exists public.announcements
  drop constraint if exists announcements_status_check;

alter table if exists public.announcements
  add constraint announcements_status_check check (
    status in ('scheduled', 'active', 'completed', 'cancelled')
  );

create index if not exists announcements_scheduled_status_idx
  on public.announcements(status, scheduled_at);

create index if not exists announcements_calendar_idx
  on public.announcements(coalesce(scheduled_at, published_at, created_at));

create or replace function public.process_scheduled_announcements()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  due_announcement public.announcements%rowtype;
  activated_count integer := 0;
begin
  update public.announcements
  set
    status = 'completed',
    completed_at = coalesce(completed_at, timezone('utc', now())),
    updated_at = timezone('utc', now())
  where status = 'active'
    and expires_at is not null
    and expires_at <= timezone('utc', now());

  for due_announcement in
    select *
    from public.announcements
    where status = 'scheduled'
      and scheduled_at is not null
      and scheduled_at <= timezone('utc', now())
    order by scheduled_at
    for update skip locked
  loop
    update public.announcements
    set
      status = 'active',
      published_at = coalesce(published_at, timezone('utc', now())),
      updated_at = timezone('utc', now())
    where id = due_announcement.id
      and status = 'scheduled';

    if found and due_announcement.notification_delivered_at is null then
      insert into public.notifications (
        user_id,
        title,
        message,
        type,
        data,
        is_read,
        created_at
      )
      select
        users.id,
        due_announcement.title,
        due_announcement.message,
        'announcement',
        jsonb_build_object(
          'announcement_id', due_announcement.id,
          'announcement_type', due_announcement.announcement_type,
          'target_role', due_announcement.target_role,
          'event', 'scheduled_announcement_published'
        ),
        false,
        timezone('utc', now())
      from public.users
      where due_announcement.target_role = 'all'
         or lower(coalesce(users.role, '')) = lower(due_announcement.target_role);

      insert into public.push_notification_queue (
        user_id,
        push_token,
        platform,
        title,
        message,
        type,
        payload,
        status,
        created_at
      )
      select
        tokens.user_id,
        tokens.token,
        tokens.platform,
        due_announcement.title,
        due_announcement.message,
        'announcement',
        jsonb_build_object(
          'announcement_id', due_announcement.id,
          'announcement_type', due_announcement.announcement_type,
          'target_role', due_announcement.target_role,
          'event', 'scheduled_announcement_published'
        ),
        'pending',
        timezone('utc', now())
      from public.user_push_tokens tokens
      join public.users users on users.id = tokens.user_id
      where tokens.is_active = true
        and (
          due_announcement.target_role = 'all'
          or lower(coalesce(users.role, '')) = lower(due_announcement.target_role)
        );

      update public.announcements
      set notification_delivered_at = timezone('utc', now())
      where id = due_announcement.id;
    end if;

    activated_count := activated_count + 1;
  end loop;

  return activated_count;
end;
$$;

grant execute on function public.process_scheduled_announcements()
  to authenticated, service_role;

do $$
declare
  existing_job_id bigint;
begin
  create extension if not exists pg_cron with schema extensions;

  select jobid into existing_job_id
  from cron.job
  where jobname = 'publish-scheduled-announcements'
  limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'publish-scheduled-announcements',
    '* * * * *',
    'select public.process_scheduled_announcements();'
  );
exception
  when others then
    raise notice 'Could not schedule announcement publication: %', sqlerrm;
end;
$$;
