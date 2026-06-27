-- Testing-phase access. Avoid role-specific RLS conflicts while the application
-- and partner vehicle workflow are being tested.

alter table public.partner_vehicle_documents disable row level security;
grant select, insert, update, delete on public.partner_vehicle_documents
  to authenticated;
