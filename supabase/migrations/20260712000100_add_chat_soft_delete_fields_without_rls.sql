-- Additive chat fields only. No RLS policies are created or changed.
alter table if exists public.messages
  add column if not exists is_deleted boolean not null default false,
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid;

create index if not exists idx_messages_deleted_by
  on public.messages(deleted_by)
  where deleted_by is not null;

