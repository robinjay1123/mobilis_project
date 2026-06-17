import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TermsService {
  static const String rentalTermsKey = 'rental_terms';
  static const String _missingSettingsTableMessage =
      'Rental terms storage is not set up yet. Apply the Supabase migration '
      'supabase/migrations/20260608000100_create_app_settings.sql, then try again.';

  static const String defaultRentalTerms = '''
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

By continuing with this booking, the renter agrees to follow the vehicle rental policies, payment requirements, security deposit rules, pickup and return procedures, cancellation terms, damage responsibilities, and any additional instructions provided by Mobilis by PSDC.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer nec odio. Praesent libero. Sed cursus ante dapibus diam.
''';

  final SupabaseClient _supabase;

  TermsService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<String> getRentalTerms() async {
    try {
      final response = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', rentalTermsKey)
          .maybeSingle();

      final value = response?['value']?.toString().trim();
      if (value == null || value.isEmpty) {
        return defaultRentalTerms;
      }

      return value;
    } catch (e) {
      debugPrint('Unable to load rental terms, using fallback: $e');
      return defaultRentalTerms;
    }
  }

  Future<void> updateRentalTerms(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw Exception('Rental terms cannot be empty.');
    }

    final userId = _supabase.auth.currentUser?.id;

    try {
      await _supabase.from('app_settings').upsert({
        'key': rentalTermsKey,
        'value': trimmed,
        'description': 'Terms shown to renters before booking finalization.',
        'updated_by': userId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'key');
    } on PostgrestException catch (e) {
      if (_isMissingSettingsTable(e)) {
        throw const TermsConfigurationException(_missingSettingsTableMessage);
      }

      rethrow;
    }
  }

  bool _isMissingSettingsTable(PostgrestException e) {
    return e.code == 'PGRST205' ||
        e.message.contains('public.app_settings') ||
        e.message.contains('app_settings');
  }
}

class TermsConfigurationException implements Exception {
  final String message;

  const TermsConfigurationException(this.message);

  @override
  String toString() => message;
}
