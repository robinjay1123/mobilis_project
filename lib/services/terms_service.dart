import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TermsService {
  static const String rentalTermsKey = 'rental_terms';
  static const String termsOfServiceKey = 'terms_of_service';
  static const String privacyPolicyKey = 'privacy_policy';
  static const String rentalTermsPdfUrlKey = 'rental_terms_pdf_url';
  static const List<String> _pdfBucketCandidates = [
    'partner_documents',
    'driver_documents',
    'app_documents',
    'vehicle_images',
  ];
  static const String _pdfPath = 'rental_terms/rental_terms_agreement.pdf';


  static const String _missingSettingsTableMessage =
      'Settings storage is not set up yet. Apply the Supabase migration '
      'supabase/migrations/20260608000100_create_app_settings.sql, then try again.';

  static const String defaultRentalTerms = '''
By continuing with this booking or using Mobilis, the renter agrees to follow all vehicle rental policies, payment requirements, security deposit rules, pickup and return procedures, cancellation terms, damage responsibilities, and instructions provided by Mobilis.

1. RENTER RESPONSIBILITIES
Renters are required to maintain a valid driver's license, operate vehicles carefully, adhere to road traffic laws, and return vehicles on time in the condition received.

2. PAYMENT & RESERVATION FEES
All rates, reservation fees, delivery fees, and security deposits must be paid through approved payment channels. Security deposits are refundable upon safe vehicle return without damages or unpaid penalties.

3. LATE RETURNS & CANCELLATIONS
Late returns incur hourly fees according to vehicle seating capacity. Cancellations are subject to the Mobilis cancellation and refund timeline policies.
''';

  static const String defaultTermsOfService = '''
MOBILIS TERMS OF SERVICE

Effective date: June 8, 2026

These Terms of Service govern access to and use of the Mobilis platform, including its mobile applications, web portals, vehicle listings, communications, verification tools, booking features, payments, and support services. By creating an account or using Mobilis, you agree to follow these general platform rules.

1. ACCOUNT USE
Users must provide accurate, current, and complete information and keep their login credentials secure. Each account is personal to the registered user and must not be shared, sold, transferred, or used to impersonate another person.

2. USER RESPONSIBILITIES
Users are responsible for reviewing listing information, providing truthful documents, following applicable laws, responding to service requests, and keeping contact details up to date. Users must use the platform respectfully and cooperate with reasonable safety, verification, and support procedures.

3. PLATFORM USE
Mobilis may be used only for lawful transportation, vehicle rental, vehicle partnership, driver, operator, administrative, and related support purposes. Users must review information carefully before submitting requests, confirming transactions, or communicating with another user.

4. TRANSACTIONS AND PAYMENTS
Users are responsible for the accuracy of transaction details and for using only approved payment channels. Prices, fees, deposits, availability, cancellations, refunds, and rental-specific obligations may be governed by the applicable listing details and separate rental agreement.

5. PROHIBITED ACTIVITIES
Users must not submit false or stolen documents, misuse another account, bypass verification or security controls, interfere with the platform, upload harmful content, harvest data, attempt unauthorized access, conduct fraud, or use Mobilis for illegal, abusive, discriminatory, or unsafe activity.

6. CONTENT AND COMMUNICATIONS
Users must have the right to share information, images, and documents they upload. Communications must remain relevant, truthful, and respectful. Mobilis may review or restrict content when reasonably necessary for safety, legal compliance, fraud prevention, or service operation.

7. VERIFICATION, SAFETY, AND ENFORCEMENT
Mobilis may request identity, vehicle, license, or other supporting information. Access may be limited, suspended, or terminated when information is inaccurate, requirements are not met, policies are violated, or activity creates a safety, legal, security, or operational risk.

8. SEPARATE AGREEMENTS AND POLICIES
These Terms of Service are general system-wide rules. They do not replace or merge with a rental agreement, booking confirmation, vehicle-specific terms, payment terms, or other agreement that a user may be asked to review separately.

9. SERVICE AVAILABILITY
Mobilis may update, maintain, improve, suspend, or limit parts of the platform when necessary. We will make reasonable efforts to keep information and services available, but uninterrupted access cannot be guaranteed.

10. UPDATES AND CONTACT
Mobilis may update these Terms of Service to reflect changes in the platform, law, or safety practices. The current version published in the platform is the version that applies to future use. Questions or concerns may be raised through Mobilis Customer Support.
''';

  static const String defaultPrivacyPolicy = '''
Mobilis collects account, verification, booking, location, emergency-contact, and payment-related information only to operate rentals, protect users, and meet service requirements.

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

  Future<String> getTermsOfService() async {
    try {
      final response = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', termsOfServiceKey)
          .maybeSingle();

      final value = response?['value']?.toString().trim();
      if (value == null || value.isEmpty) {
        return defaultTermsOfService;
      }

      return value;
    } catch (e) {
      debugPrint('Unable to load terms of service, using fallback: $e');
      return defaultTermsOfService;
    }
  }

  Future<void> updateTermsOfService(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw Exception('Terms of Service cannot be empty.');
    }

    final userId = _supabase.auth.currentUser?.id;

    try {
      await _supabase.from('app_settings').upsert({
        'key': termsOfServiceKey,
        'value': trimmed,
        'description': 'General system-wide Terms of Service shown to users.',
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

  /// Returns the public URL of the uploaded rental terms PDF, or null if none.
  Future<String?> getRentalTermsPdfUrl() async {
    try {
      final response = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', rentalTermsPdfUrlKey)
          .maybeSingle();
      final value = response?['value']?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    } catch (e) {
      debugPrint('Unable to load rental terms PDF URL: $e');
      return null;
    }
  }

  /// Uploads [bytes] as the rental terms PDF and saves its public URL.
  Future<String> uploadRentalTermsPdf(Uint8List bytes) async {
    StorageException? lastStorageException;
    Object? lastError;
    String? successfulBucket;

    for (final bucket in _pdfBucketCandidates) {
      try {
        await _supabase.storage.from(bucket).uploadBinary(
          _pdfPath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
        successfulBucket = bucket;
        debugPrint('Successfully uploaded rental terms PDF to bucket: $bucket');
        break;
      } on StorageException catch (e) {
        lastStorageException = e;
        if (e.statusCode == '404' ||
            e.message.contains('Bucket not found') ||
            e.message.contains('not found')) {
          debugPrint('Bucket $bucket not found (404), trying next bucket...');
          continue;
        }
        rethrow;
      } catch (e) {
        lastError = e;
        debugPrint('Error uploading PDF to bucket $bucket: $e, trying next...');
        continue;
      }
    }

    if (successfulBucket == null) {
      if (lastStorageException != null) {
        throw lastStorageException;
      }
      throw lastError ??
          const StorageException(
            'No accessible storage bucket found for PDF upload.',
          );
    }

    final publicUrl =
        _supabase.storage.from(successfulBucket).getPublicUrl(_pdfPath);

    final userId = _supabase.auth.currentUser?.id;
    await _supabase.from('app_settings').upsert({
      'key': rentalTermsPdfUrlKey,
      'value': publicUrl,
      'description': 'Public URL of the rental terms & agreement PDF.',
      'updated_by': userId,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'key');

    return publicUrl;
  }

  /// Removes the uploaded PDF from storage and clears its URL from settings.
  Future<void> deleteRentalTermsPdf() async {
    for (final bucket in _pdfBucketCandidates) {
      try {
        await _supabase.storage.from(bucket).remove([_pdfPath]);
      } catch (e) {
        debugPrint('Could not remove PDF from bucket $bucket: $e');
      }
    }

    await _supabase
        .from('app_settings')
        .delete()
        .eq('key', rentalTermsPdfUrlKey);
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
