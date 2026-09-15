import 'package:flutter/services.dart';

/// Normalizes a person's name for storage (for example, "robin jay banaag"
/// becomes "Robin Jay Banaag").
String toTitleCaseName(String value) {
  final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.isEmpty) return '';

  var capitalizeNext = true;
  final buffer = StringBuffer();
  for (final rune in compact.runes) {
    final character = String.fromCharCode(rune);
    if (character == ' ' || character == '-' || character == "'") {
      buffer.write(character);
      capitalizeNext = true;
      continue;
    }
    buffer.write(
      capitalizeNext ? character.toUpperCase() : character.toLowerCase(),
    );
    capitalizeNext = false;
  }
  return buffer.toString();
}

/// Formats user-facing labels while preserving common vehicle and system
/// acronyms. This is display-only and does not alter stored records.
String toProfessionalTitleCase(String value) {
  final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.isEmpty) return '';

  const preservedWords = <String, String>{
    'psdc': 'PSDC',
    'suv': 'SUV',
    'mpv': 'MPV',
    'ev': 'EV',
    'bmw': 'BMW',
    'id': 'ID',
    'n/a': 'N/A',
  };

  return compact
      .split(' ')
      .map((word) {
        final preserved = preservedWords[word.toLowerCase()];
        if (preserved != null) return preserved;
        return word
            .split('-')
            .map((part) {
              final preservedPart = preservedWords[part.toLowerCase()];
              if (preservedPart != null) return preservedPart;
              if (part.isEmpty || RegExp(r'^\d').hasMatch(part)) return part;
              return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
            })
            .join('-');
      })
      .join(' ');
}

String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

String normalizePhilippineMobile(String value) {
  final digits = digitsOnly(value);
  if (digits.length == 12 && digits.startsWith('639')) {
    return '0${digits.substring(2)}';
  }
  return digits;
}

List<TextInputFormatter> get philippineMobileInputFormatters => [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(11),
];

/// Formats Philippine PhilSys National ID (16 digits) as XXXX-XXXX-XXXX-XXXX.
class NationalIdInputFormatter extends TextInputFormatter {
  const NationalIdInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip non-digits and cap at 16 digits
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limitedDigits = digits.length > 16 ? digits.substring(0, 16) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < limitedDigits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write('-');
      }
      buffer.write(limitedDigits[i]);
    }
    final formatted = buffer.toString();

    final cursorIndex = newValue.selection.end.clamp(0, newValue.text.length);
    final rawDigitsBeforeCursor = newValue.text
        .substring(0, cursorIndex)
        .replaceAll(RegExp(r'\D'), '')
        .length
        .clamp(0, limitedDigits.length);

    int newCursorPos = 0;
    int digitCount = 0;
    while (newCursorPos < formatted.length && digitCount < rawDigitsBeforeCursor) {
      if (formatted[newCursorPos] != '-') {
        digitCount++;
      }
      newCursorPos++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }
}

/// Formats Philippine Driver's License as XXX-XX-XXXXXX (e.g. N23-45-123456).
/// 11 alphanumeric characters (uppercase varchar) with fixed dash separators.
class DriverLicenseInputFormatter extends TextInputFormatter {
  const DriverLicenseInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Keep alphanumeric and uppercase, max 11 characters
    final clean = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final limited = clean.length > 11 ? clean.substring(0, 11) : clean;

    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 3 || i == 5) {
        buffer.write('-');
      }
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();

    final cursorIndex = newValue.selection.end.clamp(0, newValue.text.length);
    final rawCharsBeforeCursor = newValue.text
        .substring(0, cursorIndex)
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .length
        .clamp(0, limited.length);

    int newCursorPos = 0;
    int charCount = 0;
    while (newCursorPos < formatted.length && charCount < rawCharsBeforeCursor) {
      if (formatted[newCursorPos] != '-') {
        charCount++;
      }
      newCursorPos++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }
}

List<TextInputFormatter> get nationalIdInputFormatters => const [
  NationalIdInputFormatter(),
];

List<TextInputFormatter> get driverLicenseInputFormatters => const [
  DriverLicenseInputFormatter(),
];

String? validateRequiredText(
  String? value, {
  required String fieldName,
  int minLength = 1,
}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '$fieldName is required.';
  if (text.length < minLength) {
    return '$fieldName must be at least $minLength characters.';
  }
  return null;
}

String? validatePersonName(String? value, {String fieldName = 'Full name'}) {
  final requiredError = validateRequiredText(
    value,
    fieldName: fieldName,
    minLength: 2,
  );
  if (requiredError != null) return requiredError;

  final text = value!.trim();
  if (!RegExp(r"^[A-Za-z\u00C0-\u024F .'-]+$", unicode: true).hasMatch(text)) {
    return '$fieldName may only contain letters, spaces, apostrophes, and hyphens.';
  }
  return null;
}

String? validateEmailAddress(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Email address is required.';
  if (!RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  ).hasMatch(text)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validatePhilippineMobile(String? value, {bool required = true}) {
  final digits = normalizePhilippineMobile(value ?? '');
  if (digits.isEmpty) return required ? 'Mobile number is required.' : null;
  if (digits.length != 11) {
    return 'Mobile number must contain exactly 11 digits.';
  }
  if (!digits.startsWith('09')) return 'Mobile number must start with 09.';
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.length < 8) return 'Password must be at least 8 characters.';
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Password must include an uppercase letter.';
  }
  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Password must include a lowercase letter.';
  }
  if (!RegExp(r'\d').hasMatch(password)) {
    return 'Password must include a number.';
  }
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
    return 'Password must include a special character.';
  }
  return null;
}

String? validatePhilippineNationalId(String? value, {bool required = true}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return required ? 'National ID number is required.' : null;
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 16) {
    return 'National ID must contain exactly 16 digits (e.g. 1234-5678-9098-7654).';
  }
  return null;
}

String? validatePhilippineDriverLicense(String? value, {bool required = true}) {
  final text = value?.trim().toUpperCase() ?? '';
  if (text.isEmpty) return required ? "Driver's license number is required." : null;
  final clean = text.replaceAll('-', '');
  if (clean.length != 11 || !RegExp(r'^[A-Z0-9]{11}$').hasMatch(clean)) {
    return "Driver's license must be 11 alphanumeric characters (e.g. N23-45-123456).";
  }
  return null;
}

