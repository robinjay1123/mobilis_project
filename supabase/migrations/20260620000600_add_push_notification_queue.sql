create table if not exists public.push_notification_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  push_token text not null,
  platform text not null,
  title text not null,
  message text not null,
  type text not null default 'general',
  payload jsonb,
  status text not null default 'pending',
  error_message text,
  created_at timestamptz not null default timezone('utc', now()),
  sent_at timestamptz
);

create index if not exists push_notification_queue_status_idx
  on public.push_notification_queue(status, created_at);

create index if not exists push_notification_queue_user_id_idx
  on public.push_notification_queue(user_id);

alter table public.push_notification_queue enable row level security;

create policy "Only privileged users can read push queue"
on public.push_notification_queue
for select
to authenticated
using (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role in ('admin', 'operator')
  )
);
