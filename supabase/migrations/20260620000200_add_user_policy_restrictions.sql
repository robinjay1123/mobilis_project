alter table public.users
  add column if not exists chat_restricted_until timestamp with time zone,
  add column if not exists account_restricted_until timestamp with time zone,
  add column if not exists restriction_reason text,
  add column if not exists restriction_level text,
  add column if not exists is_active boolean not null default true;
