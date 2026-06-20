create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  token text not null unique,
  platform text not null,
  role text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz not null default timezone('utc', now())
);

create index if not exists user_push_tokens_user_id_idx
  on public.user_push_tokens(user_id);

create index if not exists user_push_tokens_platform_idx
  on public.user_push_tokens(platform);

alter table public.user_push_tokens enable row level security;

create policy "Users can manage their own push tokens"
on public.user_push_tokens
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
