String formatAmount(num value, {int decimalDigits = 2}) {
  final safeDigits = decimalDigits < 0 ? 0 : decimalDigits;
  final fixed = value.abs().toStringAsFixed(safeDigits);
  final parts = fixed.split('.');
  final digits = parts.first;
  final grouped = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      grouped.write(',');
    }
    grouped.write(digits[index]);
  }

  final sign = value < 0 ? '-' : '';
  if (safeDigits == 0) return '$sign$grouped';
  final decimals = parts.length > 1 ? parts[1] : ''.padRight(safeDigits, '0');
  return '$sign$grouped.$decimals';
}

String formatCurrency(num value, {String symbol = 'PHP ', int decimalDigits = 2}) {
  return '$symbol${formatAmount(value, decimalDigits: decimalDigits)}';
}

String formatPeso(num value, {int decimalDigits = 2}) {
  return '₱${formatAmount(value, decimalDigits: decimalDigits)}';
}

