import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/utils/input_validation.dart';

void main() {
  group('name normalization', () {
    test('stores names in title case and removes extra spaces', () {
      expect(toTitleCaseName('  robin   jay banaag  '), 'Robin Jay Banaag');
    });

    test('capitalizes hyphenated and apostrophe-separated names', () {
      expect(toTitleCaseName("mary-jane o'brien"), "Mary-Jane O'Brien");
    });

    test('accepts letters with accents used in names', () {
      expect(validatePersonName('Jose Ni\u00f1o'), isNull);
    });
  });

  group('Philippine mobile validation', () {
    test('accepts an 11-digit mobile number beginning with 09', () {
      expect(validatePhilippineMobile('09171234567'), isNull);
    });

    test('normalizes a +63 mobile number to local format', () {
      expect(normalizePhilippineMobile('+639171234567'), '09171234567');
    });

    test('explains when the number is too short', () {
      expect(
        validatePhilippineMobile('0917123'),
        'Mobile number must contain exactly 11 digits.',
      );
    });
  });
}
