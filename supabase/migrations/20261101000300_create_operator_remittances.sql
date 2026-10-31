-- Create operator_remittances table to track platform commission remittances from operators to admin
create table if not exists public.operator_remittances (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  booking_reference text not null,
  operator_id text not null,
  operator_name text default '',
  vehicle_name text default '',
  rental_gross_amount numeric(12,2) default 0.00,
  commission_rate numeric(5,2) default 5.00,
  commission_amount numeric(12,2) not null default 0.00,
  remittance_type text not null default 'digital', -- 'cash' or 'digital'
  proof_image_url text not null, -- photo of actual money or digital transfer receipt
  reference_number text default '', -- GCash ref # or Handover recipient name
  operator_notes text default '',
  status text not null default 'pending_review', -- 'pending_review', 'remitted', 'rejected'
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by text,
  rejection_reason text,
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_operator_remittances_booking unique (booking_id)
);

-- Indexing for fast queries
create index if not exists idx_operator_remittances_operator on public.operator_remittances(operator_id);
create index if not exists idx_operator_remittances_status on public.operator_remittances(status);
create index if not exists idx_operator_remittances_booking on public.operator_remittances(booking_id);
create index if not exists idx_operator_remittances_submitted on public.operator_remittances(submitted_at desc);

-- Add tracking columns to bookings table if not present
alter table public.bookings 
  add column if not exists operator_remittance_status text default 'unremitted',
  add column if not exists operator_remitted_at timestamptz;

-- Disable RLS for smooth role-based client operations
alter table public.operator_remittances disable row level security;
grant select, insert, update, delete on public.operator_remittances to authenticated;
grant all on public.operator_remittances to service_role;

