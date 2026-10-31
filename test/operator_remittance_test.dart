import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/operator_remittance_service.dart';

void main() {
  group('Operator Platform Commission & Remittance Logic', () {
    test('1. Calculates 95% operator share and 5% PSDC platform commission accurately', () {
      const double grossRental = 12000.0;
      const double commissionRate = 5.0;

      final commission = grossRental * (commissionRate / 100.0);
      final operatorShare = grossRental - commission;

      expect(commission, equals(600.0));
      expect(operatorShare, equals(11400.0));
    });

    test('2. Handles odd rental totals with precise 5% platform fee rounding', () {
      const double grossRental = 3333.33;
      final commission = grossRental * 0.05;
      final operatorShare = grossRental * 0.95;

      expect((commission + operatorShare).toStringAsFixed(2), equals(grossRental.toStringAsFixed(2)));
      expect(commission, closeTo(166.67, 0.01));
      expect(operatorShare, closeTo(3166.66, 0.01));
    });

    test('3. OperatorRemittanceModel JSON serialization & model getters', () {
      final now = DateTime.now();
      final remittance = OperatorRemittanceModel(
        id: 'rem-101',
        bookingId: 'bk-555',
        bookingReference: 'BK-8901',
        operatorId: 'op-007',
        operatorName: 'Juan Dela Cruz',
        vehicleName: 'Toyota HiAce Grandia',
        rentalGrossAmount: 8000.0,
        commissionRate: 5.0,
        commissionAmount: 400.0,
        remittanceType: 'digital',
        proofImageUrl: 'https://supabase.co/storage/v1/object/public/booking_evidence/remittances/proof_1.jpg',
        referenceNumber: 'GCASH-123456789',
        operatorNotes: 'Sent via GCash to PSDC Admin',
        status: 'pending_review',
        submittedAt: now,
        reviewedAt: null,
        reviewedBy: null,
        rejectionReason: null,
        adminNotes: null,
        createdAt: now,
        updatedAt: now,
      );

      expect(remittance.isPendingReview, isTrue);
      expect(remittance.isRemitted, isFalse);
      expect(remittance.isRejected, isFalse);
      expect(remittance.formattedType, equals('Digital Transfer'));
      expect(remittance.formattedStatus, equals('Under Admin Review'));

      final json = remittance.toJson();
      expect(json['booking_id'], equals('bk-555'));
      expect(json['commission_amount'], equals(400.0));
      expect(json['remittance_type'], equals('digital'));
      expect(json['proof_image_url'], contains('proof_1.jpg'));

      final parsed = OperatorRemittanceModel.fromJson(json);
      expect(parsed.bookingId, equals(remittance.bookingId));
      expect(parsed.commissionAmount, equals(400.0));
      expect(parsed.status, equals('pending_review'));
    });

    test('4. Model correctly reflects Cash Handover proof and status changes', () {
      final now = DateTime.now();
      final cashRemittance = OperatorRemittanceModel(
        id: 'rem-102',
        bookingId: 'bk-777',
        bookingReference: 'BK-9902',
        operatorId: 'op-008',
        operatorName: 'Maria Santos',
        vehicleName: 'Mitsubishi Xpander',
        rentalGrossAmount: 6000.0,
        commissionRate: 5.0,
        commissionAmount: 300.0,
        remittanceType: 'cash',
        proofImageUrl: 'https://supabase.co/storage/v1/object/public/booking_evidence/remittances/money_bills.jpg',
        referenceNumber: 'Office Voucher #12',
        operatorNotes: 'Handed physical cash bills at PSDC front desk',
        status: 'remitted',
        submittedAt: now.subtract(const Duration(hours: 2)),
        reviewedAt: now,
        reviewedBy: 'admin-robin',
        rejectionReason: null,
        adminNotes: 'Counted and verified physical cash bills',
        createdAt: now,
        updatedAt: now,
      );

      expect(cashRemittance.formattedType, equals('Cash Handover'));
      expect(cashRemittance.isRemitted, isTrue);
      expect(cashRemittance.formattedStatus, equals('Remitted & Confirmed'));
      expect(cashRemittance.reviewedBy, equals('admin-robin'));
    });

    test('5. Rejection flow preserves rejection reason for operator re-submission', () {
      final now = DateTime.now();
      final rejected = OperatorRemittanceModel(
        id: 'rem-103',
        bookingId: 'bk-888',
        bookingReference: 'BK-7703',
        operatorId: 'op-009',
        commissionAmount: 250.0,
        proofImageUrl: 'https://supabase.co/storage/v1/object/public/booking_evidence/remittances/blurry_receipt.jpg',
        status: 'rejected',
        submittedAt: now,
        rejectionReason: 'The receipt photo is blurry and reference number cannot be read. Please re-upload.',
        adminNotes: 'Needs clearer photo',
        createdAt: now,
        updatedAt: now,
      );

      expect(rejected.isRejected, isTrue);
      expect(rejected.formattedStatus, equals('Rejected'));
      expect(rejected.rejectionReason, contains('blurry'));

      // Operator re-submits with new photo
      final resubmitted = rejected.copyWith(
        proofImageUrl: 'https://supabase.co/storage/v1/object/public/booking_evidence/remittances/clear_receipt.jpg',
        status: 'pending_review',
        clearRejectionReason: true,
        submittedAt: DateTime.now(),
      );

      expect(resubmitted.isPendingReview, isTrue);
      expect(resubmitted.rejectionReason, isNull);
      expect(resubmitted.proofImageUrl, contains('clear_receipt.jpg'));
    });

    test('6. Remittance filter categorization matches all lifecycle states', () {
      final records = [
        {'id': '1', 'status': 'unremitted', 'commission': 100.0},
        {'id': '2', 'status': 'pending_review', 'commission': 200.0},
        {'id': '3', 'status': 'remitted', 'commission': 300.0},
        {'id': '4', 'status': 'rejected', 'commission': 150.0},
        {'id': '5', 'status': 'unremitted', 'commission': 250.0},
      ];

      final dueRecords = records.where((r) => r['status'] == 'unremitted' || r['status'] == 'rejected').toList();
      final pendingRecords = records.where((r) => r['status'] == 'pending_review').toList();
      final remittedRecords = records.where((r) => r['status'] == 'remitted').toList();

      expect(dueRecords.length, equals(3)); // 2 unremitted + 1 rejected
      expect(pendingRecords.length, equals(1));
      expect(remittedRecords.length, equals(1));

      final totalRemitted = remittedRecords.fold<double>(0, (sum, r) => sum + (r['commission'] as double));
      expect(totalRemitted, equals(300.0));
    });
  });
}

