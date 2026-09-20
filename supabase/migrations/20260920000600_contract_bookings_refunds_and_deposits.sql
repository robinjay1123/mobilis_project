-- Migration: Contract Bookings Table Part 2 (Refunds, Deposits, Extensions, Payments)
-- Description:
-- 1. Backfills historical refund data into public.booking_refunds.
-- 2. Backfills historical payment receipts/methods into public.payments.
-- 3. Backfills extension details, terms snapshots, and review notes into metadata JSONB.
-- 4. Drops 56 redundant columns from public.bookings.

-- Step 1: Backfill historical refund records into public.booking_refunds
INSERT INTO public.booking_refunds (
  booking_id,
  renter_id,
  amount,
  payment_reference,
  status,
  reason,
  processed_at,
  created_at
)
SELECT
  b.id,
  b.renter_id,
  COALESCE(b.refund_amount, 0),
  COALESCE(b.refund_reference, b.refund_ref, 'LEGACY-REFUND'),
  COALESCE(b.refund_status, 'processed'),
  COALESCE(b.refund_reason, b.refund_notes, 'Historical refund processed'),
  COALESCE(b.refund_processed_at::timestamptz, b.created_at::timestamptz, now()),
  COALESCE(b.refunded_at::timestamptz, b.created_at::timestamptz, now())
FROM public.bookings b
WHERE (b.refund_amount IS NOT NULL AND b.refund_amount > 0)
  AND NOT EXISTS (
    SELECT 1 FROM public.booking_refunds br WHERE br.booking_id = b.id
  );

-- Step 2: Backfill historical payments into public.payments
INSERT INTO public.payments (
  booking_id,
  payer_user_id,
  amount,
  payment_type,
  payment_method,
  status,
  reference_number,
  created_at
)
SELECT
  b.id,
  b.renter_id,
  COALESCE(b.reservation_fee_amount, 0),
  'reservation',
  COALESCE(b.reservation_payment_method, 'gcash'),
  'paid',
  COALESCE(b.reservation_payment_reference, 'LEGACY-RES-PAYMENT'),
  COALESCE(b.reservation_payment_submitted_at::timestamptz, b.created_at::timestamptz, now())
FROM public.bookings b
WHERE (b.reservation_fee_amount IS NOT NULL AND b.reservation_fee_amount > 0)
  AND NOT EXISTS (
    SELECT 1 FROM public.payments p WHERE p.booking_id = b.id AND p.payment_type = 'reservation'
  );

-- Step 3: Backfill extension and security deposit details into metadata JSONB
UPDATE public.bookings
SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
  'extension_days', extension_days,
  'extension_additional_price', extension_additional_price,
  'extension_payment_method', extension_payment_method,
  'extension_payment_reference', extension_payment_reference,
  'extension_payment_status', extension_payment_status,
  'extension_rejection_reason', extension_rejection_reason,
  'extension_requested_at', extension_requested_at,
  'extension_requested_destination', extension_requested_destination,
  'extension_approved_at', extension_approved_at,
  'security_deposit_refund_amount', security_deposit_refund_amount,
  'security_deposit_refund_deduction', security_deposit_refund_deduction,
  'security_deposit_refund_method', security_deposit_refund_method,
  'security_deposit_refund_notes', security_deposit_refund_notes,
  'security_deposit_refund_ref', security_deposit_refund_ref,
  'security_deposit_refunded', security_deposit_refunded,
  'security_deposit_ineligibility_reason', security_deposit_ineligibility_reason,
  'deposit_forfeited', deposit_forfeited,
  'rental_terms_accepted_at', rental_terms_accepted_at,
  'action_deadline', action_deadline
))
WHERE (
  extension_days IS NOT NULL OR security_deposit_refund_amount IS NOT NULL OR
  rental_terms_accepted_at IS NOT NULL OR extension_requested_at IS NOT NULL
);

-- Step 4: Permanently DROP the 56 redundant columns from public.bookings
ALTER TABLE public.bookings
  -- 1. Refund columns (now in public.booking_refunds)
  DROP COLUMN IF EXISTS refund_amount,
  DROP COLUMN IF EXISTS refund_completed,
  DROP COLUMN IF EXISTS refund_method,
  DROP COLUMN IF EXISTS refund_notes,
  DROP COLUMN IF EXISTS refund_operator_id,
  DROP COLUMN IF EXISTS refund_phone,
  DROP COLUMN IF EXISTS refund_processed_at,
  DROP COLUMN IF EXISTS refund_reason,
  DROP COLUMN IF EXISTS refund_receipt_url,
  DROP COLUMN IF EXISTS refund_ref,
  DROP COLUMN IF EXISTS refund_reference,
  DROP COLUMN IF EXISTS refunded_at,
  DROP COLUMN IF EXISTS refunded_by,

  -- 2. Security Deposit columns (now in public.payments & metadata)
  DROP COLUMN IF EXISTS deposit_forfeited,
  DROP COLUMN IF EXISTS security_deposit_ineligibility_reason,
  DROP COLUMN IF EXISTS security_deposit_operator_reviewed_at,
  DROP COLUMN IF EXISTS security_deposit_operator_reviewed_by,
  DROP COLUMN IF EXISTS security_deposit_refund_amount,
  DROP COLUMN IF EXISTS security_deposit_refund_deduction,
  DROP COLUMN IF EXISTS security_deposit_refund_method,
  DROP COLUMN IF EXISTS security_deposit_refund_notes,
  DROP COLUMN IF EXISTS security_deposit_refund_receipt_url,
  DROP COLUMN IF EXISTS security_deposit_refund_ref,
  DROP COLUMN IF EXISTS security_deposit_refunded,
  DROP COLUMN IF EXISTS security_deposit_refunded_at,
  DROP COLUMN IF EXISTS security_deposit_refunded_by,

  -- 3. Extension details (now in metadata JSONB)
  DROP COLUMN IF EXISTS extension_additional_price,
  DROP COLUMN IF EXISTS extension_approved_at,
  DROP COLUMN IF EXISTS extension_conversation_id,
  DROP COLUMN IF EXISTS extension_days,
  DROP COLUMN IF EXISTS extension_finalized_at,
  DROP COLUMN IF EXISTS extension_finalized_by,
  DROP COLUMN IF EXISTS extension_payment_method,
  DROP COLUMN IF EXISTS extension_payment_proof_url,
  DROP COLUMN IF EXISTS extension_payment_reference,
  DROP COLUMN IF EXISTS extension_payment_rejection_reason,
  DROP COLUMN IF EXISTS extension_payment_status,
  DROP COLUMN IF EXISTS extension_payment_submitted_at,
  DROP COLUMN IF EXISTS extension_payment_verified_at,
  DROP COLUMN IF EXISTS extension_payment_verified_by,
  DROP COLUMN IF EXISTS extension_rejection_reason,
  DROP COLUMN IF EXISTS extension_requested_at,
  DROP COLUMN IF EXISTS extension_requested_destination,
  DROP COLUMN IF EXISTS extension_requested_end_at,

  -- 4. Reservation payment duplicates (now in public.payments)
  DROP COLUMN IF EXISTS reservation_fee_amount,
  DROP COLUMN IF EXISTS reservation_payment_covers_total,
  DROP COLUMN IF EXISTS reservation_payment_method,
  DROP COLUMN IF EXISTS reservation_payment_proof_url,
  DROP COLUMN IF EXISTS reservation_payment_reference,
  DROP COLUMN IF EXISTS reservation_payment_sender_phone,
  DROP COLUMN IF EXISTS reservation_payment_submitted_at,

  -- 5. Final payment duplicates (now in public.payments)
  DROP COLUMN IF EXISTS final_payment_confirmed_at,
  DROP COLUMN IF EXISTS final_payment_confirmed_by,
  DROP COLUMN IF EXISTS final_payment_method,
  DROP COLUMN IF EXISTS final_payment_proof_url,
  DROP COLUMN IF EXISTS final_payment_reference,

  -- 6. Terms & Redundant Snapshots (now in metadata JSONB)
  DROP COLUMN IF EXISTS rental_terms_accepted_at,
  DROP COLUMN IF EXISTS rental_terms_snapshot,
  DROP COLUMN IF EXISTS action_deadline,
  DROP COLUMN IF EXISTS commission_eligible_at;
