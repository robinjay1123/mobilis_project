-- Testing-phase access. This migration is separate because the original
-- partner document migration may already be recorded on the remote database.

alter table public.partner_vehicle_documents disable row level security;
grant select, insert, update, delete on public.partner_vehicle_documents
  to authenticated;
