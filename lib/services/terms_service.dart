import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TermsService {
  static const String rentalTermsKey = 'rental_terms';
  static const String privacyPolicyKey = 'privacy_policy';

  static const String _missingSettingsTableMessage =
      'Settings storage is not set up yet. Apply the Supabase migration '
      'supabase/migrations/20260608000100_create_app_settings.sql, then try again.';

  static const String defaultRentalTerms = '''
By continuing with this booking or using Mobilis by PSDC, the renter agrees to follow all vehicle rental policies, payment requirements, security deposit rules, pickup and return procedures, cancellation terms, damage responsibilities, and instructions provided by Mobilis by PSDC.

1. RENTER RESPONSIBILITIES
Renters are required to maintain a valid driver's license, operate vehicles carefully, adhere to road traffic laws, and return vehicles on time in the condition received.

2. PAYMENT & RESERVATION FEES
All rates, reservation fees, delivery fees, and security deposits must be paid through approved payment channels. Security deposits are refundable upon safe vehicle return without damages or unpaid penalties.

3. LATE RETURNS & CANCELLATIONS
Late returns incur hourly fees according to vehicle seating capacity. Cancellations are subject to the Mobilis cancellation and refund timeline policies.
''';

  static const String defaultPrivacyPolicy = '''
Mobilis by PSDC collects account, verification, booking, location, emergency-contact, and payment-related information only to operate rentals, protect users, and meet service requirements.

1. DATA COLLECTION & USE
We collect personal details, identity verification documents, contact numbers, and rental transactions strictly to provide vehicle rental services, process payments, and ensure safety.

2. ACCESS & CONFIDENTIALITY
Identity documents and live trip locations are limited to authorized workflows. They should only be viewed by people responsible for identity verification, active trip tracking, emergency response, or customer support.

3. SECURITY & DISCLOSURE
Profile and booking information is protected and must not be shared outside Mobilis without a valid service or safety reason. Contact Customer Service to report incorrect information, request assistance, or raise a privacy concern.
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

  Future<String> getPrivacyPolicy() async {
    try {
      final response = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', privacyPolicyKey)
          .maybeSingle();

      final value = response?['value']?.toString().trim();
      if (value == null || value.isEmpty) {
        return defaultPrivacyPolicy;
      }

      return value;
    } catch (e) {
      debugPrint('Unable to load privacy policy, using fallback: $e');
      return defaultPrivacyPolicy;
    }
  }

  Future<void> updatePrivacyPolicy(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw Exception('Privacy policy cannot be empty.');
    }

    final userId = _supabase.auth.currentUser?.id;

    try {
      await _supabase.from('app_settings').upsert({
        'key': privacyPolicyKey,
        'value': trimmed,
        'description': 'Privacy policy shown to users.',
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
