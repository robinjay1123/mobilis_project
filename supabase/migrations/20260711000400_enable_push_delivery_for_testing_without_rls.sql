-- Testing-phase access only. Replace these grants with reviewed RLS policies
-- before production. The Edge Function still uses its service role to send FCM.

alter table if exists public.user_push_tokens disable row level security;
alter table if exists public.push_notification_queue disable row level security;

grant select, insert, update, delete on public.user_push_tokens
  to authenticated;
grant select, insert, update, delete on public.push_notification_queue
  to authenticated;
