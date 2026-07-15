import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/utils/currency_formatter.dart';

void main() {
  group('formatAmount', () {
    test('adds thousand separators', () {
      expect(formatAmount(1000, decimalDigits: 0), '1,000');
      expect(formatAmount(18967.22), '18,967.22');
    });

    test('preserves values below one thousand', () {
      expect(formatAmount(999, decimalDigits: 0), '999');
    });

    test('formats negative amounts', () {
      expect(formatAmount(-1234.5), '-1,234.50');
    });
  });
}
