import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PartnerVerificationService {
  static final PartnerVerificationService _instance =
      PartnerVerificationService._internal();

  factory PartnerVerificationService() {
    return _instance;
  }

  PartnerVerificationService._internal();

  final supabase = Supabase.instance.client;

  // ==================== PARTNER VERIFICATION ====================

  /// Get partner verification status (simple ID verification, like renter)
  Future<Map<String, dynamic>?> getPartnerVerification(String userId) async {
    try {
      debugPrint('Fetching partner verification for user: $userId');

      final response = await supabase
          .from('user_verifications')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching partner verification: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error fetching partner verification: $e');
      return null;
    }
  }

  /// Submit partner identity verification (ID ONLY - Simple)
  /// This is the ONLY requirement for becoming a partner
  /// Vehicle documents (OR/CR) come LATER when adding vehicles
  /// No face photo needed - keep it simple!
  Future<Map<String, dynamic>> submitPartnerVerification({
    required String userId,
    required String idDocumentUrl,
  }) async {
    try {
      debugPrint('Submitting partner verification for user: $userId');

      final response = await supabase
          .from('user_verifications')
          .upsert({
            'user_id': userId,
            'id_document_url': idDocumentUrl,
            'verification_status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id')
          .select()
          .single();

      debugPrint('Partner verification submitted successfully');
      return {
        'success': true,
        'message': 'Partner verification submitted for admin review',
        'data': response,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error submitting verification: ${e.message}');
      return {
        'success': false,
        'message': 'Failed to submit verification: ${e.message}',
        'data': null,
      };
    } catch (e) {
      debugPrint('Error submitting verification: $e');
      return {
        'success': false,
        'message': 'Failed to submit verification: $e',
        'data': null,
      };
    }
  }

  /// Skip partner verification (basic partner without verification)
  /// Can still be a partner but with restrictions
  Future<bool> skipPartnerVerification(String userId) async {
    try {
      debugPrint('Skipping partner verification for user: $userId');

      await supabase
          .from('users')
          .update({'id_verified': false, 'application_status': 'approved'})
          .eq('id', userId);

      debugPrint('Partner verification skipped');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error skipping verification: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error skipping verification: $e');
      return false;
    }
  }

  // ==================== UTILITIES ====================

  /// Check if partner is verified
  Future<bool> isPartnerVerified(String userId) async {
    try {
      final verification = await getPartnerVerification(userId);
      return verification?['verification_status']?.toString().toLowerCase() ==
          'verified';
    } catch (e) {
      debugPrint('Error checking partner verification: $e');
      return false;
    }
  }

  /// Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
