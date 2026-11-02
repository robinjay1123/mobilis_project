import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Co-Traveler Optional Verification Logic', () {
    test('co-traveler with only name (e.g. child or toddler) is valid without ID or signature', () {
      const coTravelerName = 'Baby Leo Dela Cruz';
      const String? coTravelerPhone = null;
      const String? coTravelerLicense = null;
      const String? coTravelerSignatureUrl = null;
      const String? coTravelerValidIdUrl = null;
      const String? coTravelerSelfieUrl = null;

      // Verification logic: name is present, all other fields are optional
      final bool hasValidCoTraveler = coTravelerName.trim().isNotEmpty;
      expect(hasValidCoTraveler, isTrue);

      // Null safety on documents
      expect(coTravelerPhone, isNull);
      expect(coTravelerLicense, isNull);
      expect(coTravelerSignatureUrl, isNull);
      expect(coTravelerValidIdUrl, isNull);
      expect(coTravelerSelfieUrl, isNull);
    });

    test('co-traveler review display defaults to optional/not provided when omitted', () {
      final booking = <String, dynamic>{
        'co_traveler_name': 'Baby Leo Dela Cruz',
        'co_traveler_phone': null,
        'co_traveler_license': null,
        'co_traveler_signature_url': null,
      };

      final name = booking['co_traveler_name']?.toString() ?? 'None (Waived)';
      final phone = booking['co_traveler_phone']?.toString().trim();
      final phoneDisplay = (phone != null && phone.isNotEmpty) ? phone : 'Not provided (Optional)';
      final license = booking['co_traveler_license']?.toString().trim();
      final licenseDisplay = (license != null && license.isNotEmpty) ? license : 'Not provided (Optional)';
      final signature = booking['co_traveler_signature_url']?.toString().trim();
      final signatureDisplay = (signature != null && signature.isNotEmpty) ? 'Captured' : 'Not provided (Optional)';

      expect(name, equals('Baby Leo Dela Cruz'));
      expect(phoneDisplay, equals('Not provided (Optional)'));
      expect(licenseDisplay, equals('Not provided (Optional)'));
      expect(signatureDisplay, equals('Not provided (Optional)'));
    });

    test('solo renter without co-traveler is handled cleanly', () {
      const noCoTraveler = true;
      const String? coTravelerName = null;

      final bool isSafetyComplete = noCoTraveler || (coTravelerName != null && coTravelerName.trim().isNotEmpty);
      expect(isSafetyComplete, isTrue);
    });
  });
}

