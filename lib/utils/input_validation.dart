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
