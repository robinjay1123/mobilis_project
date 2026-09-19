-- Migration: Create centralized payments table and bi-directional synchronization with bookings
-- File: 20260920000100_create_payments_table_and_sync.sql

-- 1. Create public.payments table
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  payer_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  payment_type TEXT NOT NULL DEFAULT 'reservation'
    CHECK (payment_type IN (
      'reservation',
      'full_payment',
      'balance',
      'desk_payment',
      'trip_extension',
      'security_deposit',
      'return_settlement',
      'late_fee',
      'damage_fee',
      'refund',
      'other'
    )),
  amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00
    CHECK (amount >= 0),
  payment_method TEXT NOT NULL DEFAULT 'gcash',
  reference_number TEXT,
  sender_phone TEXT,
  proof_url TEXT,
  proof_storage_path TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN (
      'pending',
      'pending_review',
      'verified',
      'approved',
      'paid',
      'rejected',
      'refunded',
      'voided',
      'failed'
    )),
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  rejection_reason TEXT,
  notes TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Performance indexes on public.payments
CREATE INDEX IF NOT EXISTS idx_payments_booking_id ON public.payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_payments_payer_user_id ON public.payments(payer_user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_payment_type ON public.payments(payment_type);
CREATE INDEX IF NOT EXISTS idx_payments_reference_number ON public.payments(reference_number);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON public.payments(created_at DESC);

-- 3. Add rollup and link columns to public.bookings
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS total_paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS last_payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS last_payment_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_bookings_total_paid_amount ON public.bookings(total_paid_amount);

-- 4. Permissions & Realtime
ALTER TABLE public.payments DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE public.payments TO anon, authenticated, service_role;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'payments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
  END IF;
END $$;

-- 5. Trigger Function: Sync payments -> bookings
CREATE OR REPLACE FUNCTION public.fn_sync_payment_to_booking()
RETURNS TRIGGER AS $$
DECLARE
  v_booking_id UUID;
  v_total_paid NUMERIC(12, 2) := 0.00;
  v_latest_id UUID;
  v_latest_at TIMESTAMPTZ;
  v_res_status TEXT;
  v_ext_status TEXT;
  v_booking_total NUMERIC(12, 2) := 0.00;
BEGIN
  -- Prevent infinite recursion between sync triggers
  IF pg_trigger_depth() > 1 THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  v_booking_id := COALESCE(NEW.booking_id, OLD.booking_id);
  IF v_booking_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Compute total verified / paid amount for this booking
  SELECT COALESCE(SUM(amount), 0.00)
  INTO v_total_paid
  FROM public.payments
  WHERE booking_id = v_booking_id
    AND status IN ('verified', 'approved', 'paid')
    AND payment_type != 'refund';

  -- Get latest payment timestamp and id
  SELECT id, created_at
  INTO v_latest_id, v_latest_at
  FROM public.payments
  WHERE booking_id = v_booking_id
  ORDER BY created_at DESC
  LIMIT 1;

  -- Get booking total_price
  SELECT COALESCE(total_price, 0.00)
  INTO v_booking_total
  FROM public.bookings
  WHERE id = v_booking_id;

  -- Derive reservation payment status
  SELECT status
  INTO v_res_status
  FROM public.payments
  WHERE booking_id = v_booking_id
    AND payment_type IN ('reservation', 'full_payment')
  ORDER BY created_at DESC
  LIMIT 1;

  -- Derive extension payment status
  SELECT status
  INTO v_ext_status
  FROM public.payments
  WHERE booking_id = v_booking_id
    AND payment_type = 'trip_extension'
  ORDER BY created_at DESC
  LIMIT 1;

  -- Update bookings rollup
  UPDATE public.bookings
  SET
    total_paid_amount = v_total_paid,
    last_payment_id = v_latest_id,
    last_payment_at = v_latest_at,
    reservation_payment_status = COALESCE(v_res_status, reservation_payment_status),
    extension_payment_status = COALESCE(v_ext_status, extension_payment_status),
    payment_status = CASE
      WHEN v_total_paid >= v_booking_total AND v_booking_total > 0 THEN 'paid'
      WHEN v_total_paid > 0 THEN 'partially_paid'
      ELSE payment_status
    END,
    payment_verified = CASE
      WHEN v_res_status IN ('verified', 'approved', 'paid') THEN TRUE
      ELSE payment_verified
    END
  WHERE id = v_booking_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_payment_to_booking ON public.payments;
CREATE TRIGGER trg_sync_payment_to_booking
  AFTER INSERT OR UPDATE OR DELETE ON public.payments
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_payment_to_booking();

-- 6. Trigger Function: Sync bookings -> payments (Backward compatibility for legacy writes)
CREATE OR REPLACE FUNCTION public.fn_sync_booking_to_payment()
RETURNS TRIGGER AS $$
DECLARE
  v_ref TEXT;
  v_method TEXT;
  v_proof TEXT;
  v_status TEXT;
  v_type TEXT;
  v_amount NUMERIC(12, 2);
  v_ext_ref TEXT;
  v_ext_amount NUMERIC(12, 2);
  v_final_ref TEXT;
  v_final_amount NUMERIC(12, 2);
BEGIN
  -- Prevent infinite recursion
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  -- A. Sync Reservation / Initial Payment
  v_ref := NULLIF(TRIM(COALESCE(NEW.reservation_payment_reference, '')), '');
  v_proof := NULLIF(TRIM(COALESCE(NEW.reservation_payment_proof_url, '')), '');
  v_status := LOWER(TRIM(COALESCE(NEW.reservation_payment_status, 'pending')));
  v_method := LOWER(TRIM(COALESCE(NEW.reservation_payment_method, 'gcash')));
  v_type := CASE
    WHEN LOWER(TRIM(COALESCE(NEW.reservation_payment_type, ''))) = 'full_payment' OR NEW.reservation_payment_covers_total = TRUE
      THEN 'full_payment'
    ELSE 'reservation'
  END;

  IF v_type = 'full_payment' THEN
    v_amount := COALESCE(NEW.total_price, NEW.reservation_fee_amount, 1000.00);
  ELSE
    v_amount := COALESCE(NEW.reservation_fee_amount, 1000.00);
  END IF;

  -- Only record if there's payment proof/reference or status is active
  IF (v_ref IS NOT NULL OR v_proof IS NOT NULL OR v_status IN ('submitted', 'pending_review', 'verified', 'approved', 'paid')) THEN
    INSERT INTO public.payments (
      booking_id,
      payer_user_id,
      payment_type,
      amount,
      payment_method,
      reference_number,
      sender_phone,
      proof_url,
      status,
      submitted_at,
      verified_at,
      verified_by
    )
    VALUES (
      NEW.id,
      NEW.renter_id,
      v_type,
      v_amount,
      v_method,
      v_ref,
      NEW.reservation_payment_sender_phone,
      v_proof,
      CASE
        WHEN v_status IN ('verified', 'approved', 'paid') THEN 'verified'
        WHEN v_status IN ('rejected', 'forfeited') THEN 'rejected'
        WHEN v_status = 'refunded' THEN 'refunded'
        WHEN v_status IN ('submitted', 'pending_review') THEN 'pending_review'
        ELSE 'pending'
      END,
      COALESCE(NEW.reservation_payment_submitted_at, now()),
      NEW.payment_verified_at,
      NEW.payment_verified_by
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  -- B. Sync Extension Payment
  v_ext_ref := NULLIF(TRIM(COALESCE(NEW.extension_payment_reference, '')), '');
  IF v_ext_ref IS NOT NULL OR NEW.extension_payment_proof_url IS NOT NULL THEN
    v_ext_amount := COALESCE(NEW.extension_cost, 0.00);
    INSERT INTO public.payments (
      booking_id,
      payer_user_id,
      payment_type,
      amount,
      payment_method,
      reference_number,
      proof_url,
      status,
      submitted_at,
      verified_at,
      verified_by,
      rejection_reason
    )
    VALUES (
      NEW.id,
      NEW.renter_id,
      'trip_extension',
      v_ext_amount,
      COALESCE(NEW.extension_payment_method, 'gcash'),
      v_ext_ref,
      NEW.extension_payment_proof_url,
      CASE
        WHEN LOWER(COALESCE(NEW.extension_payment_status, '')) IN ('verified', 'paid', 'approved') THEN 'verified'
        WHEN LOWER(COALESCE(NEW.extension_payment_status, '')) IN ('rejected') THEN 'rejected'
        ELSE 'pending_review'
      END,
      COALESCE(NEW.extension_payment_submitted_at, now()),
      NEW.extension_payment_verified_at,
      NEW.extension_payment_verified_by,
      NEW.extension_payment_rejection_reason
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  -- C. Sync Final Return Payment / Desk Settlement
  v_final_ref := NULLIF(TRIM(COALESCE(NEW.final_payment_reference, '')), '');
  IF v_final_ref IS NOT NULL OR NEW.final_payment_proof_url IS NOT NULL OR NEW.renter_return_payment_submitted = TRUE THEN
    v_final_amount := COALESCE(NEW.renter_return_payment_amount, 0.00);
    INSERT INTO public.payments (
      booking_id,
      payer_user_id,
      payment_type,
      amount,
      payment_method,
      reference_number,
      proof_url,
      status
    )
    VALUES (
      NEW.id,
      NEW.renter_id,
      'return_settlement',
      v_final_amount,
      COALESCE(NEW.final_payment_method, 'gcash'),
      v_final_ref,
      NEW.final_payment_proof_url,
      'verified'
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_booking_to_payment ON public.bookings;
CREATE TRIGGER trg_sync_booking_to_payment
  AFTER INSERT OR UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_booking_to_payment();

-- 7. Backfill historical payments from reservation_payment_receipts
INSERT INTO public.payments (
  booking_id,
  payer_user_id,
  payment_type,
  amount,
  payment_method,
  reference_number,
  proof_url,
  proof_storage_path,
  status,
  submitted_at,
  created_at,
  updated_at
)
SELECT
  r.booking_id,
  r.renter_id,
  CASE
    WHEN r.payment_type = 'full_payment' THEN 'full_payment'
    ELSE 'reservation'
  END,
  r.amount,
  COALESCE(r.payment_method, 'psdc_qr_payment'),
  r.reference_number,
  r.proof_url,
  r.proof_storage_path,
  CASE
    WHEN r.status = 'approved' THEN 'verified'
    WHEN r.status = 'rejected' THEN 'rejected'
    WHEN r.status = 'refunded' THEN 'refunded'
    ELSE 'pending_review'
  END,
  r.submitted_at,
  r.created_at,
  r.updated_at
FROM public.reservation_payment_receipts r
WHERE EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = r.booking_id)
ON CONFLICT (id) DO NOTHING;

-- 8. Backfill remaining payments directly from bookings table
INSERT INTO public.payments (
  booking_id,
  payer_user_id,
  payment_type,
  amount,
  payment_method,
  reference_number,
  sender_phone,
  proof_url,
  status,
  submitted_at,
  created_at
)
SELECT
  b.id,
  b.renter_id,
  CASE
    WHEN b.reservation_payment_type = 'full_payment' OR b.reservation_payment_covers_total = TRUE THEN 'full_payment'
    ELSE 'reservation'
  END,
  CASE
    WHEN b.reservation_payment_type = 'full_payment' OR b.reservation_payment_covers_total = TRUE THEN COALESCE(b.total_price, b.reservation_fee_amount, 1000.00)
    ELSE COALESCE(b.reservation_fee_amount, 1000.00)
  END,
  COALESCE(b.reservation_payment_method, 'gcash'),
  b.reservation_payment_reference,
  b.reservation_payment_sender_phone,
  b.reservation_payment_proof_url,
  CASE
    WHEN LOWER(COALESCE(b.reservation_payment_status, '')) IN ('verified', 'paid', 'approved') THEN 'verified'
    WHEN LOWER(COALESCE(b.reservation_payment_status, '')) IN ('rejected', 'forfeited') THEN 'rejected'
    WHEN LOWER(COALESCE(b.reservation_payment_status, '')) = 'refunded' THEN 'refunded'
    WHEN LOWER(COALESCE(b.reservation_payment_status, '')) IN ('submitted', 'pending_review') THEN 'pending_review'
    ELSE 'pending'
  END,
  COALESCE(b.reservation_payment_submitted_at, b.created_at),
  COALESCE(b.created_at, now())
FROM public.bookings b
WHERE (
  NULLIF(TRIM(COALESCE(b.reservation_payment_reference, '')), '') IS NOT NULL
  OR NULLIF(TRIM(COALESCE(b.reservation_payment_proof_url, '')), '') IS NOT NULL
  OR LOWER(COALESCE(b.reservation_payment_status, '')) IN ('verified', 'paid', 'approved', 'submitted')
)
AND NOT EXISTS (
  SELECT 1 FROM public.payments p
  WHERE p.booking_id = b.id
    AND p.payment_type IN ('reservation', 'full_payment')
);

-- 9. Update initial total_paid_amount on bookings
UPDATE public.bookings b
SET total_paid_amount = COALESCE((
  SELECT SUM(p.amount)
  FROM public.payments p
  WHERE p.booking_id = b.id
    AND p.status IN ('verified', 'approved', 'paid')
    AND p.payment_type != 'refund'
), 0.00);
