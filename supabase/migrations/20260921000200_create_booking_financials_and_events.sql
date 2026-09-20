-- Migration: 20260921000200_create_booking_financials_and_events.sql
-- Goal: 1. Create booking_financials satellite for fee breakdowns.
--       2. Create booking_events append-only timeline table.
--       3. Backfill historical financials, events, and metadata.
--       4. Contract 15 redundant columns from public.bookings down to 31 columns.

-- ============================================================================
-- 1. CREATE SATELLITE: booking_financials
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.booking_financials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  rental_subtotal NUMERIC(12, 2) DEFAULT 0.00,
  delivery_fee NUMERIC(12, 2) DEFAULT 0.00,
  driver_fee NUMERIC(12, 2) DEFAULT 0.00,
  total_cost NUMERIC(12, 2) DEFAULT 0.00,
  reservation_payment_type TEXT,
  reservation_payment_status TEXT,
  final_payment_status TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_booking_financials_booking_id UNIQUE (booking_id)
);

-- ============================================================================
-- 2. CREATE APPEND-ONLY TIMELINE: booking_events
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.booking_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_role TEXT,
  notes TEXT,
  event_payload JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.booking_financials DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_events DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_renter_documents DISABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE public.booking_financials TO authenticated, anon, service_role;
GRANT ALL ON TABLE public.booking_events TO authenticated, anon, service_role;
GRANT ALL ON TABLE public.booking_renter_documents TO authenticated, anon, service_role;

-- ============================================================================
-- 3. BACKFILL HISTORICAL FINANCIALS & EVENTS
-- ============================================================================

-- Backfill booking_financials
INSERT INTO public.booking_financials (
  booking_id,
  rental_subtotal,
  delivery_fee,
  driver_fee,
  total_cost,
  reservation_payment_type,
  reservation_payment_status,
  final_payment_status,
  created_at,
  updated_at
)
SELECT
  b.id,
  COALESCE(b.rental_subtotal, 0.00),
  COALESCE(b.delivery_fee, 0.00),
  COALESCE(b.driver_fee, 0.00),
  COALESCE(b.total_cost, 0.00),
  b.reservation_payment_type,
  b.reservation_payment_status,
  b.final_payment_status,
  COALESCE(b.created_at::timestamptz, now()),
  COALESCE(b.updated_at::timestamptz, now())
FROM public.bookings b
ON CONFLICT (booking_id) DO UPDATE SET
  rental_subtotal = EXCLUDED.rental_subtotal,
  delivery_fee = EXCLUDED.delivery_fee,
  driver_fee = EXCLUDED.driver_fee,
  total_cost = EXCLUDED.total_cost,
  reservation_payment_type = EXCLUDED.reservation_payment_type,
  reservation_payment_status = EXCLUDED.reservation_payment_status,
  final_payment_status = EXCLUDED.final_payment_status,
  updated_at = now();

-- Backfill created events
INSERT INTO public.booking_events (booking_id, event_type, actor_id, actor_role, created_at)
SELECT b.id, 'created', b.renter_id, 'renter', COALESCE(b.created_at::timestamptz, now())
FROM public.bookings b;

-- Backfill approved events
INSERT INTO public.booking_events (booking_id, event_type, actor_id, actor_role, notes, created_at)
SELECT b.id, 'approved', b.operator_id, 'operator', b.operator_notes, b.approved_at::timestamptz
FROM public.bookings b
WHERE b.approved_at IS NOT NULL;

-- Backfill rejected events
INSERT INTO public.booking_events (booking_id, event_type, actor_id, actor_role, notes, created_at)
SELECT b.id, 'rejected', b.operator_id, 'operator', b.rejection_reason, b.rejected_at::timestamptz
FROM public.bookings b
WHERE b.rejected_at IS NOT NULL;

-- Backfill driver_assigned events
INSERT INTO public.booking_events (booking_id, event_type, actor_id, actor_role, created_at)
SELECT b.id, 'driver_assigned', b.driver_id, 'driver', b.driver_assigned_at::timestamptz
FROM public.bookings b
WHERE b.driver_assigned_at IS NOT NULL;

-- Backfill picked_up events
INSERT INTO public.booking_events (booking_id, event_type, actor_id, actor_role, created_at)
SELECT b.id, 'picked_up', b.renter_id, 'renter', b.picked_up_at
FROM public.bookings b
WHERE b.picked_up_at IS NOT NULL;

-- Backfill returned events
INSERT INTO public.booking_events (booking_id, event_type, actor_id, actor_role, created_at)
SELECT b.id, 'returned', b.renter_id, 'renter', b.returned_at
FROM public.bookings b
WHERE b.returned_at IS NOT NULL;

-- Backfill completed events
INSERT INTO public.booking_events (booking_id, event_type, actor_id, actor_role, created_at)
SELECT b.id, 'completed', b.operator_id, 'operator', b.completed_at
FROM public.bookings b
WHERE b.completed_at IS NOT NULL;

-- Backfill metadata for operator_notes, conversation_created, rejection_reason
UPDATE public.bookings
SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
  'operator_notes', operator_notes,
  'conversation_created', conversation_created,
  'rejection_reason', rejection_reason,
  'approved_at', approved_at,
  'rejected_at', rejected_at,
  'driver_assigned_at', driver_assigned_at
))
WHERE (
  operator_notes IS NOT NULL OR
  conversation_created IS NOT NULL OR
  rejection_reason IS NOT NULL OR
  approved_at IS NOT NULL OR
  rejected_at IS NOT NULL OR
  driver_assigned_at IS NOT NULL
);

-- ============================================================================
-- 4. HARDEN process_expired_pending_bookings() (Avoid refund_status column)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.process_expired_pending_bookings()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
declare
  expired_booking record;
  responsible_user_id uuid;
  refund_amount numeric(12, 2);
  has_payment boolean;
  payment_rec record;
  processed_count integer := 0;
begin
  for expired_booking in
    select
      b.*,
      v.owner_id as vehicle_owner_id,
      lower(coalesce(owner_user.role, '')) as vehicle_owner_role,
      trim(concat_ws(' ', v.brand, v.model)) as vehicle_title
    from public.bookings b
    left join public.vehicles v on v.id = b.vehicle_id
    left join public.users owner_user on owner_user.id = v.owner_id
    where lower(coalesce(b.status, 'pending')) = 'pending'
      and coalesce(
        (b.metadata->>'action_deadline')::timestamptz,
        b.created_at::timestamptz + interval '48 hours'
      ) <= now()
    for update of b skip locked
  loop
    select * into payment_rec
    from public.payments
    where booking_id = expired_booking.id
      and lower(coalesce(status, '')) in ('verified', 'completed', 'submitted', 'paid')
    order by created_at desc
    limit 1;

    has_payment := (payment_rec.id is not null) 
      or (coalesce(expired_booking.total_paid_amount, 0) > 0)
      or (lower(coalesce(expired_booking.payment_status, '')) in ('paid', 'partially_paid', 'submitted'));

    refund_amount := case
      when not has_payment then 0
      when payment_rec.amount is not null and payment_rec.amount > 0 then payment_rec.amount
      when coalesce(expired_booking.total_paid_amount, 0) > 0 then expired_booking.total_paid_amount
      else coalesce(expired_booking.total_price, 0)
    end;

    update public.bookings
    set
      status = 'cancelled',
      metadata = jsonb_set(
        jsonb_set(
          coalesce(metadata, '{}'::jsonb),
          '{auto_cancelled_at}',
          to_jsonb(now()::text)
        ),
        '{auto_cancel_reason}',
        '"No operator or partner action within 48 hours"'
      ),
      updated_at = now()
    where id = expired_booking.id;

    update public.conversations
    set status = 'closed', updated_at = now()
    where booking_id = expired_booking.id;

    -- Record event in timeline
    insert into public.booking_events (
      booking_id,
      event_type,
      actor_role,
      notes,
      event_payload,
      created_at
    ) values (
      expired_booking.id,
      'auto_cancelled',
      'system',
      'No operator or partner action within 48 hours',
      jsonb_build_object('refund_required', has_payment, 'refund_amount', refund_amount),
      now()
    );

    if has_payment and refund_amount > 0 then
      insert into public.booking_refunds (
        booking_id,
        renter_id,
        amount,
        payment_reference,
        status,
        reason
      ) values (
        expired_booking.id,
        expired_booking.renter_id,
        refund_amount,
        coalesce(payment_rec.reference_number, 'AUTO_CANCEL_REF'),
        'pending_disbursement',
        'Booking automatically cancelled after 48 hours without action'
      )
      on conflict (booking_id) do update set
        amount = excluded.amount,
        payment_reference = excluded.payment_reference,
        status = 'pending_disbursement',
        reason = excluded.reason,
        requested_at = now(),
        updated_at = now();
    end if;

    insert into public.notifications (
      user_id,
      title,
      message,
      type,
      data,
      created_at
    ) values (
      expired_booking.renter_id,
      'Booking Auto-Cancelled',
      case
        when has_payment then
          format(
            'Your booking for %s was cancelled because it received no action within 48 hours. PHP %s is queued for refund review.',
            coalesce(nullif(expired_booking.vehicle_title, ''), 'your vehicle'),
            to_char(refund_amount, 'FM999G999G990D00')
          )
        else
          format(
            'Your booking for %s was cancelled because it received no action within 48 hours.',
            coalesce(nullif(expired_booking.vehicle_title, ''), 'your vehicle')
          )
      end,
      'booking_auto_cancelled',
      jsonb_build_object(
        'booking_id', expired_booking.id,
        'status', 'cancelled',
        'refund_required', has_payment,
        'refund_amount', refund_amount
      ),
      now()
    );

    responsible_user_id := case
      when expired_booking.vehicle_owner_role = 'partner'
        then expired_booking.vehicle_owner_id
      else expired_booking.operator_id
    end;

    if responsible_user_id is not null then
      insert into public.notifications (
        user_id,
        title,
        message,
        type,
        data,
        created_at
      ) values (
        responsible_user_id,
        'Booking Expired',
        format(
          'Booking #%s was automatically cancelled after 48 hours without action.',
          upper(left(expired_booking.id::text, 8))
        ),
        'booking_auto_cancelled',
        jsonb_build_object(
          'booking_id', expired_booking.id,
          'status', 'cancelled',
          'refund_required', has_payment
        ),
        now()
      );
    elsif expired_booking.vehicle_owner_role <> 'partner' then
      insert into public.notifications (
        user_id,
        title,
        message,
        type,
        data,
        created_at
      )
      select
        u.id,
        'Booking Expired',
        format(
          'Booking #%s was automatically cancelled after 48 hours without action.',
          upper(left(expired_booking.id::text, 8))
        ),
        'booking_auto_cancelled',
        jsonb_build_object(
          'booking_id', expired_booking.id,
          'status', 'cancelled',
          'refund_required', has_payment
        ),
        now()
      from public.users u
      where lower(coalesce(u.role, '')) in ('operator', 'admin');
    end if;

    processed_count := processed_count + 1;
  end loop;

  return processed_count;
end;
$$;

-- Re-define fn_sync_payment_to_booking to safely sync booking rollups and booking_financials
CREATE OR REPLACE FUNCTION public.fn_sync_payment_to_booking()
RETURNS TRIGGER AS $$
DECLARE
  v_booking_id UUID;
  v_total_paid NUMERIC(12, 2) := 0.00;
  v_latest_id UUID;
  v_latest_at TIMESTAMPTZ;
  v_booking_total NUMERIC(12, 2) := 0.00;
  v_res_status TEXT;
BEGIN
  -- Prevent infinite recursion
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

  -- Update bookings rollup safely
  UPDATE public.bookings
  SET
    total_paid_amount = v_total_paid,
    last_payment_id = v_latest_id,
    last_payment_at = v_latest_at,
    payment_status = CASE
      WHEN v_total_paid >= v_booking_total AND v_booking_total > 0 THEN 'paid'
      WHEN v_total_paid > 0 THEN 'partially_paid'
      ELSE payment_status
    END
  WHERE id = v_booking_id;

  -- Also sync reservation_payment_status into booking_financials
  SELECT status
  INTO v_res_status
  FROM public.payments
  WHERE booking_id = v_booking_id
    AND payment_type IN ('reservation', 'full_payment')
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_res_status IS NOT NULL THEN
    UPDATE public.booking_financials
    SET
      reservation_payment_status = v_res_status,
      updated_at = now()
    WHERE booking_id = v_booking_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. RE-CREATE VIEWS WITHOUT DROPPED COLUMNS
-- ============================================================================

DROP VIEW IF EXISTS public.renter_bookings_view CASCADE;
DROP VIEW IF EXISTS public.driver_bookings_view CASCADE;
DROP VIEW IF EXISTS public.partner_bookings_view CASCADE;

CREATE VIEW public.renter_bookings_view AS
SELECT
  b.id,
  b.renter_id,
  b.vehicle_id,
  b.status,
  b.start_date,
  b.end_date,
  b.rental_period,
  b.pickup_location,
  b.dropoff_location,
  b.total_price,
  b.with_driver,
  b.driver_id,
  b.created_at,
  b.updated_at,
  b.metadata
FROM public.bookings b
WHERE (auth.uid() IS NULL OR b.renter_id = auth.uid());

GRANT SELECT ON public.renter_bookings_view TO authenticated;

CREATE VIEW public.driver_bookings_view AS
SELECT
  b.id,
  b.vehicle_id,
  b.status,
  b.start_date,
  b.end_date,
  b.rental_period,
  b.pickup_location,
  b.dropoff_location,
  b.driver_id,
  b.created_at,
  b.updated_at
FROM public.bookings b
WHERE (auth.uid() IS NULL OR b.driver_id = auth.uid());

GRANT SELECT ON public.driver_bookings_view TO authenticated;

CREATE VIEW public.partner_bookings_view AS
SELECT
  b.id,
  b.vehicle_id,
  b.status,
  b.start_date,
  b.end_date,
  b.rental_period,
  b.total_price,
  b.created_at,
  b.updated_at
FROM public.bookings b
JOIN public.vehicles v ON v.id = b.vehicle_id
WHERE (auth.uid() IS NULL OR v.owner_id = auth.uid());

GRANT SELECT ON public.partner_bookings_view TO authenticated;

-- ============================================================================
-- 6. CONTRACT 15 REDUNDANT COLUMNS FROM public.bookings (DOWN TO 31)
-- ============================================================================

ALTER TABLE public.bookings
  DROP COLUMN IF EXISTS rental_subtotal,
  DROP COLUMN IF EXISTS delivery_fee,
  DROP COLUMN IF EXISTS driver_fee,
  DROP COLUMN IF EXISTS total_cost,
  DROP COLUMN IF EXISTS reservation_payment_type,
  DROP COLUMN IF EXISTS reservation_payment_status,
  DROP COLUMN IF EXISTS final_payment_status,
  DROP COLUMN IF EXISTS refund_status,
  DROP COLUMN IF EXISTS commission_status,
  DROP COLUMN IF EXISTS approved_at,
  DROP COLUMN IF EXISTS rejected_at,
  DROP COLUMN IF EXISTS rejection_reason,
  DROP COLUMN IF EXISTS driver_assigned_at,
  DROP COLUMN IF EXISTS conversation_created,
  DROP COLUMN IF EXISTS operator_notes;

-- ============================================================================
-- 7. PERFORMANCE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_booking_financials_booking_id ON public.booking_financials(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id ON public.booking_events(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_events_event_type ON public.booking_events(event_type);
CREATE INDEX IF NOT EXISTS idx_booking_events_created_at ON public.booking_events(created_at);

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
