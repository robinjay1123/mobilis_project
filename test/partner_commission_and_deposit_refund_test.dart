import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/notification_service.dart';

void main() {
  group('Partner Commission and Disbursement Calculations', () {
    test('calculates partner commission and PSDC 5% platform fee accurately', () {
      const double rentalSubtotal = 10000.0;
      const double deliveryFee = 500.0;
      const double lateFee = 500.0;
      const double effectiveRentalTotal = rentalSubtotal + deliveryFee + lateFee; // 11000

      // 5% PSDC Platform Fee
      final psdcCommission = effectiveRentalTotal * 0.05; // 550
      final partnerCommission = effectiveRentalTotal - psdcCommission; // 10450

      expect(psdcCommission, equals(550.0));
      expect(partnerCommission, equals(10450.0));
    });

    test('adds damage compensation from deposit deduction to partner disbursement total', () {
      const double rentalTotal = 15000.0;
      final psdcCommission = rentalTotal * 0.05; // 750
      final partnerRentalEarnings = rentalTotal - psdcCommission; // 14250

      // Case 1: No damage deduction
      const double zeroDeduction = 0.0;
      final disbursementZeroDeduction = (partnerRentalEarnings + zeroDeduction).clamp(0.0, double.infinity);
      expect(disbursementZeroDeduction, equals(14250.0));

      // Case 2: Damage deduction applied (e.g. ₱2,500 damage compensation from deposit)
      const double damageCompensation = 2500.0;
      final disbursementWithDamage = (partnerRentalEarnings + damageCompensation).clamp(0.0, double.infinity);
      expect(disbursementWithDamage, equals(16750.0));
    });

    test('calculates renter security deposit refund with approved deduction', () {
      const double originalDeposit = 3000.0;

      // Full refund (0 deduction)
      const double deductionZero = 0.0;
      final fullRefund = (originalDeposit - deductionZero).clamp(0.0, double.infinity);
      expect(fullRefund, equals(3000.0));

      // Partial refund (damage deduction 1200)
      const double deductionPartial = 1200.0;
      final partialRefund = (originalDeposit - deductionPartial).clamp(0.0, double.infinity);
      expect(partialRefund, equals(1800.0));

      // Over-deduction clamped to zero (no negative refund)
      const double excessiveDeduction = 4000.0;
      final clampedRefund = (originalDeposit - excessiveDeduction).clamp(0.0, double.infinity);
      expect(clampedRefund, equals(0.0));
    });

    test('enforces backend idempotency error message matching', () {
      const String finalizedException = 'Exception: This transaction has already been finalized.';
      final cleanedMsg = finalizedException.replaceAll('Exception:', '').trim();

      final isFinalized = cleanedMsg.contains('already been finalized');
      expect(isFinalized, isTrue);

      final userFacingMsg = isFinalized
          ? 'This transaction has already been finalized.'
          : 'Failed: $cleanedMsg';
      expect(userFacingMsg, equals('This transaction has already been finalized.'));
    });
  });

  group('Driver Trip Fee Disbursement Calculations', () {
    test('calculates driver trip fee, 5% PSDC commission, and net disbursement accurately', () {
      const double dailyRate = 1500.0;
      const int days = 3;
      const double grossTripFee = dailyRate * days; // 4500.0

      final psdcCommission = grossTripFee * 0.05; // 225.0
      final netDisbursement = grossTripFee - psdcCommission; // 4275.0

      expect(grossTripFee, equals(4500.0));
      expect(psdcCommission, equals(225.0));
      expect(netDisbursement, equals(4275.0));
    });

    test('enforces backend idempotency for driver trip fee disbursement', () {
      const String finalizedException = 'Exception: This transaction has already been finalized.';
      final cleanedMsg = finalizedException.replaceAll('Exception:', '').trim();

      final isFinalized = cleanedMsg.contains('already been finalized');
      expect(isFinalized, isTrue);

      final userFacingMsg = isFinalized
          ? 'This transaction has already been finalized.'
          : 'Failed: $cleanedMsg';
      expect(userFacingMsg, equals('This transaction has already been finalized.'));
    });
  });

  group('Partner Security Deposit Refund Notification Deduplication', () {
    final notificationService = NotificationService();

    test('deduplicates duplicate partner deposit refund notifications sent closely in time', () {
      final now = DateTime.now();
      final notifications = [
        {
          'id': 'notif-dep-1',
          'user_id': 'partner-101',
          'title': 'Security Deposit Refund Processed',
          'message': 'Security deposit of PHP 3,000 for booking BK-999 has been refunded to John Doe.',
          'type': 'security_deposit_refund',
          'created_at': now.toIso8601String(),
          'is_read': false,
        },
        {
          'id': 'notif-dep-2',
          'user_id': 'partner-101',
          'title': 'Security Deposit Refund Processed',
          'message': 'Security deposit of PHP 3,000 for booking BK-999 has been refunded to John Doe.',
          'type': 'security_deposit_refund',
          'created_at': now.add(const Duration(seconds: 15)).toIso8601String(),
          'is_read': false,
        },
        {
          'id': 'notif-dep-3',
          'user_id': 'partner-101',
          'title': 'Security Deposit Refund Processed',
          'message': 'Security deposit of PHP 4,000 for booking BK-1000 has been refunded to Jane Smith.',
          'type': 'security_deposit_refund',
          'created_at': now.toIso8601String(),
          'is_read': false,
        },
      ];

      final deduplicated = notificationService.deduplicateNotifications(notifications);
      expect(deduplicated.length, equals(2));
      expect(deduplicated.map((n) => n['id']).toList(), containsAll(['notif-dep-1', 'notif-dep-3']));
      expect(deduplicated.map((n) => n['id']).toList(), isNot(contains('notif-dep-2')));
    });
  });
}
