import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

class BookingSettlementAmounts {
  const BookingSettlementAmounts({
    required this.ownerServiceAmount,
    required this.partnerCommission,
    required this.partnerNet,
    required this.driverCommission,
    required this.driverNet,
    required this.grossAmount,
  });

  final double ownerServiceAmount;
  final double partnerCommission;
  final double partnerNet;
  final double driverCommission;
  final double driverNet;
  final double grossAmount;

  factory BookingSettlementAmounts.calculate({
    required double rentalAmount,
    required double deliveryAmount,
    required double lateFeeAmount,
    required double driverGross,
    required bool isPartnerVehicle,
  }) {
    final ownerServiceAmount = rentalAmount + deliveryAmount + lateFeeAmount;
    final partnerCommission = isPartnerVehicle ? ownerServiceAmount * 0.05 : 0.0;
    final driverCommission = driverGross * 0.05;
    return BookingSettlementAmounts(
      ownerServiceAmount: ownerServiceAmount,
      partnerCommission: partnerCommission,
      partnerNet: isPartnerVehicle
          ? (ownerServiceAmount - partnerCommission)
                .clamp(0.0, double.infinity)
                .toDouble()
          : 0.0,
      driverCommission: driverCommission,
      driverNet: (driverGross - driverCommission)
          .clamp(0.0, double.infinity)
          .toDouble(),
      // Commission is deducted from earnings, not added to what the renter
      // paid. Refundable security deposits are also excluded from revenue.
      grossAmount: ownerServiceAmount + driverGross,
    );
  }
}

class BookingSettlementService {
  BookingSettlementService({SupabaseClient? client})
    : supabase = client ?? Supabase.instance.client;

  final SupabaseClient supabase;

  double _number(dynamic value) => (value as num?)?.toDouble() ?? 0;

  bool _isFinalPaymentConfirmed(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';
    return <String>{
      'paid',
      'fully_paid',
      'full_paid',
      'verified',
      'settled',
      'released',
      'completed',
      'confirmed',
      'final_paid',
      'payment_verified',
    }.contains(status);
  }

  Future<List<Map<String, dynamic>>> getReleasedPayoutsForUser({
    required String userId,
    required String recipientRole,
  }) async {
    final response = await supabase
        .from('booking_payouts')
        .select()
        .eq('recipient_user_id', userId)
        .eq('recipient_role', recipientRole.trim().toLowerCase())
        .eq('status', 'released')
        .order('released_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Releases the internal accounting records exactly once. This records who
  /// earned each amount; an external wallet/bank transfer remains a separate
  /// payment-provider operation.
  Future<Map<String, dynamic>> releaseForCompletedBooking(
    String bookingId, {
    String? operatorFallbackUserId,
  }) async {
    final existing = await supabase
        .from('booking_settlements')
        .select()
        .eq('booking_id', bookingId)
        .maybeSingle();
    if (existing?['status']?.toString() == 'released') {
      return Map<String, dynamic>.from(existing!);
    }

    final booking = await supabase
        .from('bookings')
        .select('''
          id,
          status,
          final_payment_status,
          operator_id,
          driver_id,
          total_price,
          total_cost,
          rental_subtotal,
          delivery_fee,
          late_return_fee,
          vehicles:vehicle_id (
            id,
            owner_id,
            owner_role,
            operator_id
          ),
          job_assignments:driver_job_assignments!driver_job_assignments_booking_id_fkey (
            id,
            driver_id,
            status,
            trip_fee
          )
        ''')
        .eq('id', bookingId)
        .maybeSingle();
    if (booking == null) throw Exception('Booking not found for settlement');
    if (!_isFinalPaymentConfirmed(booking['final_payment_status'])) {
      throw Exception('The booking must be fully paid before releasing funds');
    }

    String? nonEmpty(dynamic value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    final vehicle = booking['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    final ownerRole = vehicle['owner_role']?.toString().trim().toLowerCase();
    final partnerId = ownerRole == 'partner'
        ? vehicle['owner_id']?.toString()
        : null;
    final operatorId =
        nonEmpty(booking['operator_id']) ??
        nonEmpty(vehicle['operator_id']) ??
        nonEmpty(operatorFallbackUserId);
    var rentalAmount = _number(booking['rental_subtotal']);
    final deliveryAmount = _number(booking['delivery_fee']);
    final lateFeeAmount = _number(booking['late_return_fee']);
    final recordedTotal = _number(
      booking['total_price'] ?? booking['total_cost'],
    );
    final assignments = booking['job_assignments'] is List
        ? List<Map<String, dynamic>>.from(booking['job_assignments'])
        : <Map<String, dynamic>>[];
    Map<String, dynamic>? acceptedAssignment;
    for (final assignment in assignments.reversed) {
      final status = assignment['status']?.toString().trim().toLowerCase();
      if (status == 'accepted' ||
          status == 'ongoing' ||
          status == 'awaiting_completion' ||
          status == 'completed') {
        acceptedAssignment = assignment;
        break;
      }
    }
    final driverId =
        acceptedAssignment?['driver_id']?.toString() ??
        booking['driver_id']?.toString();
    final driverGross = _number(acceptedAssignment?['trip_fee']);
    // Legacy bookings may predate rental_subtotal. Preserve their settlement
    // value instead of releasing a zero owner payout.
    if (rentalAmount <= 0 && recordedTotal > 0) {
      rentalAmount =
          (recordedTotal - deliveryAmount - lateFeeAmount - driverGross)
              .clamp(0.0, double.infinity)
              .toDouble();
    }
    final amounts = BookingSettlementAmounts.calculate(
      rentalAmount: rentalAmount,
      deliveryAmount: deliveryAmount,
      lateFeeAmount: lateFeeAmount,
      driverGross: driverGross,
      isPartnerVehicle: partnerId != null,
    );
    final ownerServiceAmount = amounts.ownerServiceAmount;
    final partnerCommission = amounts.partnerCommission;
    final driverCommission = amounts.driverCommission;
    final driverNet = amounts.driverNet;
    final partnerNet = amounts.partnerNet;
    final grossAmount = amounts.grossAmount;
    final releasedAt = DateTime.now().toUtc().toIso8601String();

    if (operatorId != null && nonEmpty(booking['operator_id']) == null) {
      try {
        await supabase
            .from('bookings')
            .update({'operator_id': operatorId, 'updated_at': releasedAt})
            .eq('id', bookingId);
      } catch (error) {
        debugPrint(
          'Could not backfill booking operator for settlement: $error',
        );
      }
    }

    final settlementPayload = <String, dynamic>{
      'booking_id': bookingId,
      'gross_amount': grossAmount,
      'rental_amount': rentalAmount,
      'delivery_amount': deliveryAmount,
      'late_fee_amount': lateFeeAmount,
      'platform_commission': partnerCommission + driverCommission,
      'partner_user_id': partnerId,
      'partner_amount': partnerNet,
      'operator_user_id': operatorId,
      'operator_managed_amount': partnerId == null ? ownerServiceAmount : 0,
      'driver_user_id': driverId,
      'driver_gross_amount': driverGross,
      'driver_commission_amount': driverCommission,
      'driver_amount': driverNet,
      'status': 'pending',
      'released_at': null,
      'details': {
        'partner_commission_rate': partnerId == null ? 0 : 10,
        'driver_commission_rate': driverId == null ? 0 : 15,
        'source_total': recordedTotal,
        'note': 'Internal payout ledger; external disbursement is separate.',
      },
      'updated_at': releasedAt,
    };
    await supabase
        .from('booking_settlements')
        .upsert(settlementPayload, onConflict: 'booking_id')
        .select('id')
        .single();

    if (partnerId != null && partnerId.isNotEmpty && partnerNet > 0) {
      await supabase.from('booking_payouts').upsert({
        'booking_id': bookingId,
        'recipient_user_id': partnerId,
        'recipient_role': 'partner',
        'gross_amount': ownerServiceAmount,
        'deductions': partnerCommission,
        'net_amount': partnerNet,
        'status': 'released',
        'released_at': releasedAt,
        'metadata': {'commission_rate': 10},
        'updated_at': releasedAt,
      }, onConflict: 'booking_id,recipient_user_id,recipient_role');
      await _notifyPayout(partnerId, bookingId, partnerNet, 'Partner');
    }

    if (driverId != null && driverId.isNotEmpty && driverGross > 0) {
      await supabase.from('booking_payouts').upsert({
        'booking_id': bookingId,
        'recipient_user_id': driverId,
        'recipient_role': 'driver',
        'gross_amount': driverGross,
        'deductions': driverCommission,
        'net_amount': driverNet,
        'status': 'released',
        'released_at': releasedAt,
        'metadata': {'commission_rate': 15},
        'updated_at': releasedAt,
      }, onConflict: 'booking_id,recipient_user_id,recipient_role');
      final earningPayload = <String, dynamic>{
        'booking_id': bookingId,
        'driver_id': driverId,
        'trip_fee': driverGross,
        'commission_percentage': 15,
        'commission_amount': driverCommission,
        'net_earnings': driverNet,
        'payout_status': 'paid',
        'paid_at': releasedAt,
      };
      final existingEarning = await supabase
          .from('driver_earnings')
          .select('id')
          .eq('booking_id', bookingId)
          .maybeSingle();
      if (existingEarning == null) {
        await supabase.from('driver_earnings').insert(earningPayload);
      } else {
        await supabase
            .from('driver_earnings')
            .update(earningPayload)
            .eq('id', existingEarning['id']);
      }
      await _notifyPayout(driverId, bookingId, driverNet, 'Driver');
    }

    // Preserve compatibility with the original aggregate transaction table.
    try {
      final transaction = await supabase
          .from('transactions')
          .select('id')
          .eq('booking_id', bookingId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final transactionPayload = {
        'booking_id': bookingId,
        'amount': grossAmount,
        'commission': partnerCommission + driverCommission,
        'partner_earnings': partnerNet,
        'operator_earnings': partnerId == null ? ownerServiceAmount : 0,
      };
      if (transaction == null) {
        await supabase.from('transactions').insert(transactionPayload);
      } else {
        await supabase
            .from('transactions')
            .update(transactionPayload)
            .eq('id', transaction['id']);
      }
    } catch (error) {
      debugPrint('Legacy transaction ledger update skipped: $error');
    }

    final settlement = await supabase
        .from('booking_settlements')
        .update({
          'status': 'released',
          'released_at': releasedAt,
          'updated_at': releasedAt,
        })
        .eq('booking_id', bookingId)
        .select()
        .single();

    return Map<String, dynamic>.from(settlement);
  }

  Future<void> _notifyPayout(
    String userId,
    String bookingId,
    double amount,
    String role,
  ) async {
    try {
      await NotificationService().createNotification(
        userId: userId,
        title: '$role Earnings Released',
        message:
            'PHP ${amount.toStringAsFixed(2)} was added to your completed-trip earnings.',
        type: 'booking_payout_released',
        data: {
          'booking_id': bookingId,
          'amount': amount,
          'role': role.toLowerCase(),
        },
      );
    } catch (error) {
      debugPrint('Payout notification skipped for $userId: $error');
    }
  }
}
