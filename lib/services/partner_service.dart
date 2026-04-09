import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PartnerService {
  static final PartnerService _instance = PartnerService._internal();

  factory PartnerService() {
    return _instance;
  }

  PartnerService._internal();

  final supabase = Supabase.instance.client;

  // Get partner profile by user ID
  Future<Map<String, dynamic>?> getPartnerProfile(String userId) async {
    try {
      debugPrint('Fetching partner profile for user: $userId');

      final response = await supabase
          .from('partners')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint('Partner profile fetched: ${response != null}');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching partner: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching partner: $e');
      rethrow;
    }
  }

  // Create partner profile
  Future<Map<String, dynamic>> createPartnerProfile({
    required String userId,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    try {
      debugPrint('Creating partner profile for user: $userId');

      final response = await supabase.from('partners').insert({
        'user_id': userId,
        'business_name': businessName,
        'business_address': businessAddress,
        'business_phone': businessPhone,
        'verification_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      debugPrint('Partner profile created successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating partner: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error creating partner: $e');
      rethrow;
    }
  }

  // Update partner profile
  Future<void> updatePartnerProfile(
    String partnerId,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('Updating partner profile: $partnerId');

      await supabase.from('partners').update(data).eq('id', partnerId);

      debugPrint('Partner profile updated successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating partner: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating partner: $e');
      rethrow;
    }
  }

  // Get vehicle applications for partner
  Future<List<Map<String, dynamic>>> getVehicleApplications(
    String partnerId,
  ) async {
    try {
      debugPrint('Fetching vehicle applications for partner: $partnerId');

      final response = await supabase
          .from('vehicle_applications')
          .select()
          .eq('partner_id', partnerId)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} vehicle applications');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching applications: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching applications: $e');
      rethrow;
    }
  }

  // Get vehicle applications by status
  Future<List<Map<String, dynamic>>> getVehicleApplicationsByStatus(
    String partnerId,
    String status,
  ) async {
    try {
      debugPrint('Fetching $status applications for partner: $partnerId');

      final response = await supabase
          .from('vehicle_applications')
          .select()
          .eq('partner_id', partnerId)
          .eq('status', status)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} $status applications');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching applications: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching applications: $e');
      rethrow;
    }
  }

  // Submit vehicle application
  Future<Map<String, dynamic>> submitVehicleApplication({
    required String partnerId,
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
    required int seats,
    required double pricePerDay,
    required double pricePerHour,
  }) async {
    try {
      debugPrint('Submitting vehicle application for partner: $partnerId');

      final response = await supabase.from('vehicle_applications').insert({
        'partner_id': partnerId,
        'brand': brand,
        'model': model,
        'year': year,
        'plate_number': plateNumber,
        'seats': seats,
        'price_per_day': pricePerDay,
        'price_per_hour': pricePerHour,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      debugPrint('Vehicle application submitted successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error submitting application: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error submitting application: $e');
      rethrow;
    }
  }

  // Check if partner has pending application
  Future<bool> hasPendingApplication(String partnerId) async {
    try {
      debugPrint('Checking pending applications for partner: $partnerId');

      final response = await supabase
          .from('vehicle_applications')
          .select('id')
          .eq('partner_id', partnerId)
          .eq('status', 'pending')
          .limit(1);

      final hasPending = response.isNotEmpty;
      debugPrint('Partner has pending application: $hasPending');
      return hasPending;
    } on PostgrestException catch (e) {
      debugPrint('Database error checking pending: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error checking pending: $e');
      rethrow;
    }
  }

  // Get partner verification status
  Future<String?> getVerificationStatus(String userId) async {
    try {
      final profile = await getPartnerProfile(userId);
      return profile?['verification_status'] as String?;
    } catch (e) {
      debugPrint('Error getting verification status: $e');
      return null;
    }
  }

  // Get application counts by status
  Future<Map<String, int>> getApplicationCounts(String partnerId) async {
    try {
      debugPrint('Fetching application counts for partner: $partnerId');

      final applications = await getVehicleApplications(partnerId);

      final counts = {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total': applications.length,
      };

      for (final app in applications) {
        final status = app['status'] as String?;
        if (status != null && counts.containsKey(status)) {
          counts[status] = counts[status]! + 1;
        }
      }

      debugPrint('Application counts: $counts');
      return counts;
    } catch (e) {
      debugPrint('Error getting application counts: $e');
      return {'pending': 0, 'approved': 0, 'rejected': 0, 'total': 0};
    }
  }

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
