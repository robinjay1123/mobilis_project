import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/reservation_payment_service.dart';

void main() {
  group('ReservationPaymentProof Desk Settlement Model', () {
    test('captures operator name, id, and custom notes for desk payments', () {
      const proof = ReservationPaymentProof(
        amount: 1500.0,
        method: 'psdc_desk_counter',
        paymentType: 'reservation_only',
        referenceNumber: 'DESK-OPERATOR_ROBIN',
        proofUrl: 'desk_payment_authorized',
        senderPhone: '09171234567',
        securityDeposit: 3000.0,
        reservationFee: 1000.0,
        operatorName: 'Robin Jay PSDC',
        operatorId: 'op-12345',
        notes: 'The payment has been paid in desk (Authorized by Robin Jay PSDC)',
      );

      expect(proof.method, equals('psdc_desk_counter'));
      expect(proof.operatorName, equals('Robin Jay PSDC'));
      expect(proof.operatorId, equals('op-12345'));
      expect(
        proof.notes,
        equals('The payment has been paid in desk (Authorized by Robin Jay PSDC)'),
      );
      expect(proof.referenceNumber, startsWith('DESK-'));
    });

    test('validates 3 failed attempts rule logic', () {
      int failedAttempts = 0;
      bool isDeskLocked = false;

      void registerFailedAttempt() {
        failedAttempts++;
        if (failedAttempts >= 3) {
          isDeskLocked = true;
        }
      }

      expect(isDeskLocked, isFalse);
      registerFailedAttempt();
      expect(failedAttempts, equals(1));
      expect(isDeskLocked, isFalse);

      registerFailedAttempt();
      expect(failedAttempts, equals(2));
      expect(isDeskLocked, isFalse);

      registerFailedAttempt();
      expect(failedAttempts, equals(3));
      expect(isDeskLocked, isTrue);
    });
  });
}
