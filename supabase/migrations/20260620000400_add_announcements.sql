create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.users(id) on delete set null,
  title text not null,
  message text not null,
  target_role text not null default 'all',
  created_at timestamptz not null default timezone('utc', now())
);
