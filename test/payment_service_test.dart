import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/payment_service.dart';

void main() {
  group('PaymentType', () {
    test('parses and serializes all payment types accurately', () {
      expect(PaymentType.fromString('reservation'), PaymentType.reservation);
      expect(PaymentType.fromString('full_payment'), PaymentType.fullPayment);
      expect(PaymentType.fromString('desk_payment'), PaymentType.deskPayment);
      expect(PaymentType.fromString('trip_extension'), PaymentType.tripExtension);
      expect(PaymentType.fromString('security_deposit'), PaymentType.securityDeposit);
      expect(PaymentType.fromString('return_settlement'), PaymentType.returnSettlement);
      expect(PaymentType.fromString('refund'), PaymentType.refund);
      expect(PaymentType.fromString('unknown_type'), PaymentType.other);

      expect(PaymentType.reservation.toDbString(), 'reservation');
      expect(PaymentType.fullPayment.toDbString(), 'full_payment');
      expect(PaymentType.tripExtension.toDbString(), 'trip_extension');
      expect(PaymentType.securityDeposit.toDbString(), 'security_deposit');
      expect(PaymentType.refund.toDbString(), 'refund');
    });
  });

  group('PaymentRecordStatus', () {
    test('correctly evaluates settled and pending statuses', () {
      expect(PaymentRecordStatus.fromString('verified'), PaymentRecordStatus.verified);
      expect(PaymentRecordStatus.fromString('approved'), PaymentRecordStatus.approved);
      expect(PaymentRecordStatus.fromString('paid'), PaymentRecordStatus.paid);
      expect(PaymentRecordStatus.fromString('pending_review'), PaymentRecordStatus.pendingReview);
      expect(PaymentRecordStatus.fromString('rejected'), PaymentRecordStatus.rejected);

      expect(PaymentRecordStatus.verified.isSettled, isTrue);
      expect(PaymentRecordStatus.approved.isSettled, isTrue);
      expect(PaymentRecordStatus.paid.isSettled, isTrue);
      expect(PaymentRecordStatus.pendingReview.isSettled, isFalse);
      expect(PaymentRecordStatus.pending.isSettled, isFalse);
      expect(PaymentRecordStatus.rejected.isSettled, isFalse);
    });
  });

  group('PaymentRecord JSON serialization', () {
    test('properly serializes and deserializes payment rows', () {
      final now = DateTime.now();
      final record = PaymentRecord(
        id: 'pay-123',
        bookingId: 'book-456',
        payerUserId: 'user-789',
        paymentType: PaymentType.reservation,
        amount: 1500.0,
        paymentMethod: 'gcash',
        referenceNumber: '1234567890123',
        senderPhone: '09171234567',
        proofUrl: 'https://example.com/receipt.jpg',
        status: PaymentRecordStatus.verified,
        verifiedAt: now,
        verifiedBy: 'operator-1',
        submittedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final json = record.toJson();
      expect(json['id'], 'pay-123');
      expect(json['payment_type'], 'reservation');
      expect(json['amount'], 1500.0);
      expect(json['reference_number'], '1234567890123');

      final reconstructed = PaymentRecord.fromJson(json);
      expect(reconstructed.id, record.id);
      expect(reconstructed.amount, record.amount);
      expect(reconstructed.status, PaymentRecordStatus.verified);
      expect(reconstructed.referenceNumber, '1234567890123');
    });
  });

  group('BookingPaymentSummary calculations', () {
    test('correctly calculates total paid, remaining balance, and fully paid state', () {
      final now = DateTime.now();
      final payments = [
        PaymentRecord(
          id: 'pay-1',
          bookingId: 'b-1',
          paymentType: PaymentType.reservation,
          amount: 1000.0,
          paymentMethod: 'gcash',
          status: PaymentRecordStatus.verified,
          submittedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        PaymentRecord(
          id: 'pay-2',
          bookingId: 'b-1',
          paymentType: PaymentType.deskPayment,
          amount: 2500.0,
          paymentMethod: 'cash',
          status: PaymentRecordStatus.paid,
          submittedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        PaymentRecord(
          id: 'pay-3',
          bookingId: 'b-1',
          paymentType: PaymentType.tripExtension,
          amount: 1200.0,
          paymentMethod: 'gcash',
          status: PaymentRecordStatus.pendingReview,
          submittedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Total booking price = 3500 (1000 reservation + 2500 balance)
      final summary = BookingPaymentSummary.fromPayments(
        payments: payments,
        bookingTotalPrice: 3500.0,
      );

      expect(summary.totalPaidAmount, 3500.0);
      expect(summary.totalPendingAmount, 1200.0);
      expect(summary.isFullyPaid, isTrue);
      expect(summary.remainingBalance, 0.0);
      expect(summary.totalTransactions, 3);
    });

    test('handles partial payments and pending amounts correctly', () {
      final now = DateTime.now();
      final payments = [
        PaymentRecord(
          id: 'pay-1',
          bookingId: 'b-2',
          paymentType: PaymentType.reservation,
          amount: 1000.0,
          paymentMethod: 'gcash',
          status: PaymentRecordStatus.verified,
          submittedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Total booking price = 5000. Paid: 1000. Balance: 4000
      final summary = BookingPaymentSummary.fromPayments(
        payments: payments,
        bookingTotalPrice: 5000.0,
      );

      expect(summary.totalPaidAmount, 1000.0);
      expect(summary.isFullyPaid, isFalse);
      expect(summary.remainingBalance, 4000.0);
    });

    test('deducts refunds into separate accounting bucket', () {
      final now = DateTime.now();
      final payments = [
        PaymentRecord(
          id: 'pay-1',
          bookingId: 'b-3',
          paymentType: PaymentType.reservation,
          amount: 1000.0,
          paymentMethod: 'gcash',
          status: PaymentRecordStatus.verified,
          submittedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        PaymentRecord(
          id: 'pay-2',
          bookingId: 'b-3',
          paymentType: PaymentType.refund,
          amount: 500.0,
          paymentMethod: 'bank_transfer',
          status: PaymentRecordStatus.paid,
          submittedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = BookingPaymentSummary.fromPayments(
        payments: payments,
        bookingTotalPrice: 1000.0,
      );

      expect(summary.totalPaidAmount, 1000.0);
      expect(summary.totalRefundedAmount, 500.0);
    });
  });
}
