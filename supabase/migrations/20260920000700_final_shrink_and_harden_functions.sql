-- Migration: 20260920000700_final_shrink_and_harden_functions.sql
-- Goal: Harden database functions against missing columns, remove broken triggers,
--       backfill sparse metadata, and contract redundant columns from public.bookings.

-- ============================================================================
-- 1. DROP OBSOLETE SYNC TRIGGER ON bookings & RE-DEFINE fn_sync_payment_to_booking
-- ============================================================================

-- trg_sync_booking_to_payment was a legacy backward sync trigger that accessed
-- columns dropped in Batch 2 (reservation_payment_reference, etc.). Drop it now.
DROP TRIGGER IF EXISTS trg_sync_booking_to_payment ON public.bookings;
DROP FUNCTION IF EXISTS public.fn_sync_booking_to_payment();

-- Re-define fn_sync_payment_to_booking on payments table to only touch valid core columns
CREATE OR REPLACE FUNCTION public.fn_sync_payment_to_booking()
RETURNS TRIGGER AS $$
DECLARE
  v_booking_id UUID;
  v_total_paid NUMERIC(12, 2) := 0.00;
  v_latest_id UUID;
  v_latest_at TIMESTAMPTZ;
  v_booking_total NUMERIC(12, 2) := 0.00;
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

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 2. HARDEN & RE-DEFINE process_expired_pending_bookings()
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
    -- Check if payment exists in public.payments or booking totals
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
      else coalesce(expired_booking.total_price, expired_booking.total_cost, 0)
    end;

    -- Update booking status and record auto_cancelled metadata
    update public.bookings
    set
      status = 'cancelled',
      refund_status = case
        when has_payment then 'refund_needed'
        else 'not_required'
      end,
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
        'refund_status', case when has_payment then 'refund_needed' else 'not_required' end,
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

GRANT ALL ON FUNCTION public.process_expired_pending_bookings() TO anon;
GRANT ALL ON FUNCTION public.process_expired_pending_bookings() TO authenticated;
GRANT ALL ON FUNCTION public.process_expired_pending_bookings() TO service_role;

-- ============================================================================
-- 3. TEMPORARILY DROP VIEWS THAT SELECT driver_requested
-- ============================================================================

DROP VIEW IF EXISTS public.renter_bookings_view CASCADE;
DROP VIEW IF EXISTS public.driver_bookings_view CASCADE;
DROP VIEW IF EXISTS public.partner_bookings_view CASCADE;

-- ============================================================================
-- 4. BACKFILL HISTORICAL SPARSE VALUES INTO metadata jsonb
-- ============================================================================

UPDATE public.bookings
SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
  'partner_booking_confirmed_at', partner_booking_confirmed_at,
  'partner_booking_confirmed_by', partner_booking_confirmed_by,
  'partner_booking_rejected_at', partner_booking_rejected_at,
  'partner_booking_rejection_reason', partner_booking_rejection_reason,
  'operator_trip_confirmed_at', operator_trip_confirmed_at,
  'partner_trip_confirmed_at', partner_trip_confirmed_at,
  'driver_trip_confirmed_at', driver_trip_confirmed_at,
  'return_confirmed_at', return_confirmed_at,
  'return_confirmed_by', return_confirmed_by,
  'payment_verified_at', payment_verified_at,
  'payment_verified_by', payment_verified_by,
  'payment_verification_notes', payment_verification_notes,
  'payment_verified', payment_verified,
  'original_start_at', original_start_at,
  'original_end_at', original_end_at,
  'late_return_days', late_return_days,
  'late_return_hours', late_return_hours,
  'late_return_fee', late_return_fee,
  'cancellation_fee_retained', cancellation_fee_retained,
  'renter_return_payment_submitted', renter_return_payment_submitted,
  'renter_return_payment_amount', renter_return_payment_amount,
  'principal_total_price', principal_total_price,
  'security_deposit_return_eligible', security_deposit_return_eligible,
  'security_deposit_status', security_deposit_status
))
WHERE (
  partner_booking_confirmed_at IS NOT NULL OR
  partner_booking_confirmed_by IS NOT NULL OR
  partner_booking_rejected_at IS NOT NULL OR
  partner_booking_rejection_reason IS NOT NULL OR
  operator_trip_confirmed_at IS NOT NULL OR
  partner_trip_confirmed_at IS NOT NULL OR
  driver_trip_confirmed_at IS NOT NULL OR
  return_confirmed_at IS NOT NULL OR
  return_confirmed_by IS NOT NULL OR
  payment_verified_at IS NOT NULL OR
  payment_verified_by IS NOT NULL OR
  payment_verification_notes IS NOT NULL OR
  payment_verified IS NOT NULL OR
  original_start_at IS NOT NULL OR
  original_end_at IS NOT NULL OR
  late_return_days IS NOT NULL OR
  late_return_hours IS NOT NULL OR
  late_return_fee IS NOT NULL OR
  cancellation_fee_retained IS NOT NULL OR
  renter_return_payment_submitted IS NOT NULL OR
  renter_return_payment_amount IS NOT NULL OR
  principal_total_price IS NOT NULL OR
  security_deposit_return_eligible IS NOT NULL OR
  security_deposit_status IS NOT NULL
);

-- ============================================================================
-- 5. DROP REDUNDANT & UNREFERENCED COLUMNS FROM public.bookings
-- ============================================================================

ALTER TABLE public.bookings
  DROP COLUMN IF EXISTS actual_return_time,
  DROP COLUMN IF EXISTS overtime_fee,
  DROP COLUMN IF EXISTS driver_requested,
  DROP COLUMN IF EXISTS cancellation_fee_retained,
  DROP COLUMN IF EXISTS payment_verified_at,
  DROP COLUMN IF EXISTS payment_verified_by,
  DROP COLUMN IF EXISTS payment_verification_notes,
  DROP COLUMN IF EXISTS payment_verified,
  DROP COLUMN IF EXISTS partner_booking_rejection_reason,
  DROP COLUMN IF EXISTS return_confirmed_at,
  DROP COLUMN IF EXISTS return_confirmed_by,
  DROP COLUMN IF EXISTS original_start_at,
  DROP COLUMN IF EXISTS original_end_at,
  DROP COLUMN IF EXISTS late_return_days,
  DROP COLUMN IF EXISTS late_return_hours,
  DROP COLUMN IF EXISTS late_return_fee,
  DROP COLUMN IF EXISTS renter_return_payment_submitted,
  DROP COLUMN IF EXISTS renter_return_payment_amount,
  DROP COLUMN IF EXISTS principal_total_price,
  DROP COLUMN IF EXISTS partner_booking_confirmed_at,
  DROP COLUMN IF EXISTS partner_booking_confirmed_by,
  DROP COLUMN IF EXISTS partner_booking_rejected_at,
  DROP COLUMN IF EXISTS operator_trip_confirmed_at,
  DROP COLUMN IF EXISTS partner_trip_confirmed_at,
  DROP COLUMN IF EXISTS driver_trip_confirmed_at,
  DROP COLUMN IF EXISTS security_deposit_return_eligible,
  DROP COLUMN IF EXISTS security_deposit_status;

-- ============================================================================
-- 6. RE-CREATE CLEAN ROLE-SCOPED VIEWS
-- ============================================================================

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
  b.total_cost,
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
  b.driver_assigned_at,
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

-- Re-notify PostgREST schema cache reload
NOTIFY pgrst, 'reload schema';
