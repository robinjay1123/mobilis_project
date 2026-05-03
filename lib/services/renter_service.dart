import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class RenterService {
  static final RenterService _instance = RenterService._internal();

  factory RenterService() {
    return _instance;
  }

  RenterService._internal();

  final supabase = Supabase.instance.client;

  // ================== RENTER PROFILE ==================

  /// Get renter profile by user ID
  Future<Map<String, dynamic>?> getRenterProfile(String userId) async {
    try {
      debugPrint('Fetching renter profile for user: $userId');
      final response = await supabase
          .from('renters')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching renter profile: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error fetching renter profile: $e');
      return null;
    }
  }

  /// Create renter profile for new renter
  Future<Map<String, dynamic>> createRenterProfile(String userId) async {
    try {
      debugPrint('Creating renter profile for user: $userId');
      final response = await supabase.from('renters').insert({
        'user_id': userId,
        'verification_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      return response.first;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating renter profile: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error creating renter profile: $e');
      rethrow;
    }
  }

  /// Update renter profile details
  Future<void> updateRenterProfile(
    String renterId,
    Map<String, dynamic> updates,
  ) async {
    try {
      debugPrint('Updating renter profile: $renterId');
      await supabase.from('renters').update(updates).eq('id', renterId);

      debugPrint('Renter profile updated');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating renter profile: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating renter profile: $e');
      rethrow;
    }
  }

  // ================== VERIFICATION DOCUMENTS ==================

  /// Upload verification document (ID, address proof, etc.)
  Future<Map<String, dynamic>> uploadVerificationDocument(
    String userId,
    String documentType,
    String fileUrl, {
    String? expiryDate,
  }) async {
    try {
      debugPrint('Uploading verification document for user: $userId');

      // Get renter ID first
      final renterProfile = await getRenterProfile(userId);
      if (renterProfile == null) {
        throw Exception('Renter profile not found. Create profile first.');
      }

      final response =
          await supabase.from('renter_verification_documents').insert({
            'user_id': userId,
            'renter_id': renterProfile['id'],
            'document_type': documentType,
            'file_url': fileUrl,
            'expiry_date': expiryDate,
            'upload_date': DateTime.now().toIso8601String(),
            'status': 'pending',
          }).select();

      debugPrint('Verification document uploaded');
      return response.first;
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error uploading verification document: ${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('Error uploading verification document: $e');
      rethrow;
    }
  }

  /// Get all verification documents for a renter
  Future<List<Map<String, dynamic>>> getVerificationDocuments(
    String userId,
  ) async {
    try {
      debugPrint('Fetching verification documents for user: $userId');
      final response = await supabase
          .from('renter_verification_documents')
          .select('*')
          .eq('user_id', userId)
          .order('upload_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error fetching verification documents: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint('Error fetching verification documents: $e');
      return [];
    }
  }

  /// Get specific document type
  Future<Map<String, dynamic>?> getDocumentByType(
    String userId,
    String documentType,
  ) async {
    try {
      debugPrint('Fetching $documentType document for user: $userId');
      final response = await supabase
          .from('renter_verification_documents')
          .select('*')
          .eq('user_id', userId)
          .eq('document_type', documentType)
          .maybeSingle();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching document: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error fetching document: $e');
      return null;
    }
  }

  /// Delete verification document
  Future<void> deleteVerificationDocument(String documentId) async {
    try {
      debugPrint('Deleting verification document: $documentId');
      await supabase
          .from('renter_verification_documents')
          .delete()
          .eq('id', documentId);

      debugPrint('Verification document deleted');
    } on PostgrestException catch (e) {
      debugPrint('Database error deleting verification document: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error deleting verification document: $e');
      rethrow;
    }
  }

  // ================== VERIFICATION STATUS ==================

  /// Get current verification status
  Future<String?> getVerificationStatus(String userId) async {
    try {
      debugPrint('Fetching verification status for user: $userId');
      final response = await supabase
          .from('users')
          .select('id_verified, verification_status')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      // If id_verified is true, they're verified
      if (response['id_verified'] == true) {
        return 'verified';
      }

      // Otherwise check verification_status
      return response['verification_status'] as String?;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching verification status: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error fetching verification status: $e');
      return null;
    }
  }

  /// Submit verification for admin review
  Future<void> submitVerificationForReview(String userId) async {
    try {
      debugPrint('Submitting verification for review: $userId');
      await supabase
          .from('users')
          .update({'verification_status': 'pending_review'})
          .eq('id', userId);

      debugPrint('Verification submitted for review');
    } on PostgrestException catch (e) {
      debugPrint('Database error submitting verification: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error submitting verification: $e');
      rethrow;
    }
  }

  /// Skip verification (mark as basic/unverified renter)
  /// Renter can still rent but with restrictions
  Future<void> skipVerification(String userId) async {
    try {
      debugPrint('Skipping verification for user: $userId');
      await supabase
          .from('users')
          .update({'id_verified': false, 'verification_status': 'skipped'})
          .eq('id', userId);

      debugPrint('Verification skipped, user marked as basic renter');
    } on PostgrestException catch (e) {
      debugPrint('Database error skipping verification: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error skipping verification: $e');
      rethrow;
    }
  }

  /// Complete verification (called by admin after approval)
  Future<void> completeVerification(String userId) async {
    try {
      debugPrint('Completing verification for user: $userId');
      await supabase
          .from('users')
          .update({'id_verified': true, 'verification_status': 'verified'})
          .eq('id', userId);

      debugPrint('Verification completed');
    } on PostgrestException catch (e) {
      debugPrint('Database error completing verification: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error completing verification: $e');
      rethrow;
    }
  }

  // ================== BOOKING HISTORY ==================

  /// Get booking history for renter
  Future<List<Map<String, dynamic>>> getBookingHistory(
    String userId, {
    int limit = 50,
    String? status,
  }) async {
    try {
      debugPrint('Fetching booking history for user: $userId');

      var query = supabase
          .from('bookings')
          .select(
            'id, vehicle_id, start_date, end_date, status, total_price, created_at, vehicles(brand, model, year, plate_number, price_per_day), users(full_name, email)',
          )
          .eq('renter_id', userId);

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching booking history: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching booking history: $e');
      return [];
    }
  }

  /// Get specific booking details
  Future<Map<String, dynamic>?> getBookingById(String bookingId) async {
    try {
      debugPrint('Fetching booking details: $bookingId');
      final response = await supabase
          .from('bookings')
          .select(
            'id, renter_id, vehicle_id, start_date, end_date, status, total_price, pickup_location, dropoff_location, created_at, vehicles(*), users(id, full_name, email, phone)',
          )
          .eq('id', bookingId)
          .maybeSingle();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching booking: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error fetching booking: $e');
      return null;
    }
  }

  /// Get active bookings (not completed/cancelled)
  Future<List<Map<String, dynamic>>> getActiveBookings(String userId) async {
    try {
      debugPrint('Fetching active bookings for user: $userId');
      final response = await supabase
          .from('bookings')
          .select(
            'id, vehicle_id, start_date, end_date, status, total_price, created_at, vehicles(brand, model, year, plate_number)',
          )
          .eq('renter_id', userId)
          .inFilter('status', ['pending', 'approved', 'confirmed', 'active'])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching active bookings: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching active bookings: $e');
      return [];
    }
  }

  /// Check if renter can book vehicles
  /// Returns false if basic/unverified or suspended
  Future<bool> canRentVehicles(String userId) async {
    try {
      debugPrint('Checking rental eligibility for user: $userId');
      final userResponse = await supabase
          .from('users')
          .select('id_verified, is_active')
          .eq('id', userId)
          .maybeSingle();

      if (userResponse == null) {
        debugPrint('User not found');
        return false;
      }

      final isVerified = userResponse['id_verified'] as bool? ?? false;
      final isActive = userResponse['is_active'] as bool? ?? true;

      debugPrint(
        'Rental eligibility - Verified: $isVerified, Active: $isActive',
      );
      return isVerified && isActive;
    } on PostgrestException catch (e) {
      debugPrint('Database error checking rental eligibility: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error checking rental eligibility: $e');
      return false;
    }
  }

  /// Get renter statistics
  Future<Map<String, dynamic>> getRenterStats(String userId) async {
    try {
      debugPrint('Fetching renter stats for user: $userId');

      // Total bookings
      final totalBookingsResponse = await supabase
          .from('bookings')
          .select('id')
          .eq('renter_id', userId);

      // Completed bookings
      final completedResponse = await supabase
          .from('bookings')
          .select('id')
          .eq('renter_id', userId)
          .eq('status', 'completed');

      // Total spent
      final spentResponse = await supabase
          .from('bookings')
          .select('total_price')
          .eq('renter_id', userId)
          .eq('status', 'completed');

      double totalSpent = 0;
      for (var booking in spentResponse) {
        totalSpent += (booking['total_price'] as num?)?.toDouble() ?? 0;
      }

      return {
        'total_bookings': totalBookingsResponse.length,
        'completed_bookings': completedResponse.length,
        'total_spent': totalSpent,
        'booking_rate': totalBookingsResponse.length > 0
            ? (completedResponse.length / totalBookingsResponse.length * 100)
                  .toStringAsFixed(1)
            : '0',
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching renter stats: ${e.message}');
      return {
        'total_bookings': 0,
        'completed_bookings': 0,
        'total_spent': 0,
        'booking_rate': '0',
      };
    } catch (e) {
      debugPrint('Error fetching renter stats: $e');
      return {
        'total_bookings': 0,
        'completed_bookings': 0,
        'total_spent': 0,
        'booking_rate': '0',
      };
    }
  }

  // ================== DOCUMENT EXPIRY VALIDATION ==================

  /// Validate renter verification documents
  Future<Map<String, dynamic>> validateDocuments(String userId) async {
    try {
      debugPrint('Validating verification documents for user: $userId');

      final docs = await getVerificationDocuments(userId);
      final now = DateTime.now();

      Map<String, dynamic> validation = {
        'valid': true,
        'expiring_soon': [],
        'expired': [],
        'missing_required': [],
      };

      // Check each document
      for (var doc in docs) {
        final expiryDate = doc['expiry_date'] as String?;
        final docType = doc['document_type'] as String?;

        if (expiryDate != null) {
          final expiry = DateTime.parse(expiryDate);
          final daysUntilExpiry = expiry.difference(now).inDays;

          if (daysUntilExpiry < 0) {
            validation['expired'].add({
              'type': docType,
              'expiry_date': expiryDate,
              'days_overdue': daysUntilExpiry.abs(),
            });
            validation['valid'] = false;
          } else if (daysUntilExpiry < 90) {
            validation['expiring_soon'].add({
              'type': docType,
              'expiry_date': expiryDate,
              'days_remaining': daysUntilExpiry,
            });
          }
        }
      }

      debugPrint('Document validation result: ${validation['valid']}');
      return validation;
    } catch (e) {
      debugPrint('Error validating documents: $e');
      return {'valid': false, 'error': e.toString()};
    }
  }

  /// Get expiring verification documents
  Future<List<Map<String, dynamic>>> getExpiringDocuments(
    String userId, {
    int daysThreshold = 90,
  }) async {
    try {
      debugPrint(
        'Fetching expiring documents for user: $userId (within $daysThreshold days)',
      );

      final docs = await getVerificationDocuments(userId);
      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      final expiringDocs = docs.where((doc) {
        final expiryDate = doc['expiry_date'] as String?;
        if (expiryDate == null) return false;

        final expiry = DateTime.parse(expiryDate);
        return expiry.isBefore(thresholdDate) && expiry.isAfter(now);
      }).toList();

      return List<Map<String, dynamic>>.from(expiringDocs);
    } catch (e) {
      debugPrint('Error fetching expiring documents: $e');
      return [];
    }
  }

  // ================== DOCUMENT RENEWAL ==================

  /// Renew an expired/expiring renter verification document
  Future<Map<String, dynamic>?> renewDocument({
    required String documentId,
    required String newFileUrl,
    required DateTime? newExpiryDate,
  }) async {
    try {
      debugPrint('Renewing renter verification document: $documentId');

      // Get the old document
      final oldDoc = await supabase
          .from('renter_verification_documents')
          .select()
          .eq('id', documentId)
          .maybeSingle();

      if (oldDoc == null) {
        throw Exception('Document not found: $documentId');
      }

      // Update the document with new file and expiry
      final updated = await supabase
          .from('renter_verification_documents')
          .update({
            'file_url': newFileUrl,
            if (newExpiryDate != null)
              'expiry_date': newExpiryDate.toIso8601String(),
            'status': 'pending',
            'updated_at': DateTime.now().toIso8601String(),
            'renewal_count': (oldDoc['renewal_count'] ?? 0) + 1,
          })
          .eq('id', documentId)
          .select()
          .maybeSingle();

      debugPrint('Document renewed successfully: $documentId');
      return updated;
    } on PostgrestException catch (e) {
      debugPrint('Database error renewing document: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error renewing document: $e');
      rethrow;
    }
  }

  /// Get documents pending renewal for a renter
  Future<List<Map<String, dynamic>>> getDocumentsPendingRenewal({
    required String userId,
    int daysThreshold = 7,
  }) async {
    try {
      debugPrint(
        'Getting documents pending renewal for renter: $userId (within $daysThreshold days)',
      );

      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      final docs = await supabase
          .from('renter_verification_documents')
          .select()
          .eq('user_id', userId);

      final pendingRenewal = docs.where((doc) {
        final expiryDate = doc['expiry_date'] as String?;
        if (expiryDate == null) return false;

        final expiry = DateTime.parse(expiryDate);
        return expiry.isBefore(thresholdDate);
      }).toList();

      return List<Map<String, dynamic>>.from(pendingRenewal);
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error getting documents pending renewal: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint('Error getting documents pending renewal: $e');
      return [];
    }
  }

  // ================== HELPER METHODS ==================

  /// Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
