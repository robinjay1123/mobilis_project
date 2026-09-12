-- Migration: 20260912000100_add_extension_rejection_reason_alias_columns.sql
-- Description: Ensure extension rejection reason columns exist on public.bookings.

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS extension_rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS extension_payment_rejection_reason TEXT;
