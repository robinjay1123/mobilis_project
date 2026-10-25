import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobilis_by_psdc_app/utils/input_validation.dart';
import 'package:mobilis_by_psdc_app/services/auth_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://zmaudwpinfdnlvplzovx.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InptYXVkd3BpbmZkbmx2cGx6b3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyMjY3MjAsImV4cCI6MjA4ODgwMjcyMH0.M9ilQpchddyUELFHBf2Touor_fi4_hjlDGij28F1kQc',
      );
    } catch (_) {}
  });

  group('Auth Password Validation Rules', () {
    test('enforces minimum 8 characters', () {
      expect(validatePassword('Ab1!'), 'Password must be at least 8 characters.');
    });

    test('enforces uppercase letter', () {
      expect(validatePassword('abcdef1!'), 'Password must include an uppercase letter.');
    });

    test('enforces lowercase letter', () {
      expect(validatePassword('ABCDEF1!'), 'Password must include a lowercase letter.');
    });

    test('enforces number', () {
      expect(validatePassword('Abcdefg!'), 'Password must include a number.');
    });

    test('enforces special character', () {
      expect(validatePassword('Abcdefg1'), 'Password must include a special character.');
    });

    test('accepts valid complex password', () {
      expect(validatePassword('Mobilis@2026!'), isNull);
    });
  });

  group('Auth Email Validation Rules', () {
    test('rejects empty email', () {
      expect(validateEmailAddress(''), 'Email address is required.');
      expect(validateEmailAddress('   '), 'Email address is required.');
    });

    test('rejects malformed email addresses', () {
      expect(validateEmailAddress('plainaddress'), 'Enter a valid email address.');
      expect(validateEmailAddress('@missingusername.com'), 'Enter a valid email address.');
      expect(validateEmailAddress('user@domain'), 'Enter a valid email address.');
    });

    test('accepts valid email addresses', () {
      expect(validateEmailAddress('renter@gmail.com'), isNull);
      expect(validateEmailAddress('admin@psdc.org.ph'), isNull);
      expect(validateEmailAddress('user.name+tag@example.com'), isNull);
    });
  });

  group('Philippine Driver License & National ID Formatters', () {
    test('validates driver license format N23-45-123456', () {
      expect(validatePhilippineDriverLicense('N23-45-123456'), isNull);
      expect(validatePhilippineDriverLicense('A01-12-345678'), isNull);
      expect(validatePhilippineDriverLicense('123'), isNotNull);
    });

    test('validates PhilSys National ID format 16 digits', () {
      expect(validatePhilippineNationalId('1234-5678-9098-7654'), isNull);
      expect(validatePhilippineNationalId('1234567890987654'), isNull);
      expect(validatePhilippineNationalId('1234-5678'), isNotNull);
    });
  });

  group('AuthService Error Message Humanization', () {
    test('humanizes invalid login credentials', () {
      final authService = AuthService();
      final msg = authService.getErrorMessage('Invalid login credentials');
      expect(msg, 'Invalid email or password');
    });

    test('humanizes unconfirmed email', () {
      final authService = AuthService();
      final msg = authService.getErrorMessage('Email not confirmed');
      expect(msg, 'Email not confirmed');
    });

    test('humanizes existing user error', () {
      final authService = AuthService();
      final msg = authService.getErrorMessage('User already registered');
      expect(msg, 'This email is already registered');
    });
  });
}
