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

      final response = await supabase
          .from('partners')
          .insert({
            'user_id': userId,
            'business_name': businessName,
            'business_address': businessAddress,
            'business_phone': businessPhone,
            'verification_status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

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
          .from('partner_vehicle_applications')
          .select()
          .eq('partner_id', partnerId)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} vehicle applications');
      return List<Map<String, dynamic>>.from(
        response.map((app) {
          final map = Map<String, dynamic>.from(app);
          map['status'] = map['application_status'] ?? map['status'];
          return map;
        }),
      );
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
          .from('partner_vehicle_applications')
          .select()
          .eq('partner_id', partnerId)
          .eq('application_status', status)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} $status applications');
      return List<Map<String, dynamic>>.from(
        response.map((app) {
          final map = Map<String, dynamic>.from(app);
          map['status'] = map['application_status'] ?? map['status'];
          return map;
        }),
      );
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

      final response = await supabase
          .from('partner_vehicle_applications')
          .insert({
            'partner_id': partnerId,
            'brand': brand,
            'model': model,
            'year': year,
            'plate_number': plateNumber,
            'price_per_day': pricePerDay,
            'price_per_hour': pricePerHour,
            'application_status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

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
          .from('partner_vehicle_applications')
          .select('id')
          .eq('partner_id', partnerId)
          .eq('application_status', 'pending')
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
        final status = app['application_status'] as String?;
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

  // ================== APPLICATION APPROVAL (ADMIN) ==================

  /// Approve vehicle application (called by admin)
  Future<void> approveVehicleApplication(
    String applicationId,
    String notes,
  ) async {
    try {
      debugPrint('Approving vehicle application: $applicationId');
      await supabase
          .from('partner_vehicle_applications')
          .update({'application_status': 'approved'})
          .eq('id', applicationId);

      debugPrint('Vehicle application approved');
    } on PostgrestException catch (e) {
      debugPrint('Database error approving vehicle application: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error approving vehicle application: $e');
      rethrow;
    }
  }

  /// Reject vehicle application (called by admin)
  Future<void> rejectVehicleApplication(
    String applicationId,
    String reason,
  ) async {
    try {
      debugPrint('Rejecting vehicle application: $applicationId');
      await supabase
          .from('partner_vehicle_applications')
          .update({
            'application_status': 'rejected',
            'rejection_reason': reason,
          })
          .eq('id', applicationId);

      debugPrint('Vehicle application rejected');
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting vehicle application: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error rejecting vehicle application: $e');
      rethrow;
    }
  }

  // ================== VEHICLE EXPIRY VALIDATION ==================

  /// Validate vehicle documents (check expiry dates)
  Future<Map<String, dynamic>> validateVehicleDocuments(
    String vehicleId,
  ) async {
    try {
      debugPrint('Validating documents for vehicle: $vehicleId');

      final docs = await supabase
          .from('vehicle_documents')
          .select('*')
          .eq('vehicle_id', vehicleId);

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

      // Check for required documents
      final requiredDocs = ['insurance', 'registration'];
      final uploadedTypes = docs.map((d) => d['document_type']).toSet();

      for (var required in requiredDocs) {
        if (!uploadedTypes.contains(required)) {
          validation['missing_required'].add(required);
          validation['valid'] = false;
        }
      }

      return validation;
    } catch (e) {
      debugPrint('Error validating vehicle documents: $e');
      return {'valid': false, 'error': e.toString()};
    }
  }

  /// Get expiring vehicle documents
  Future<List<Map<String, dynamic>>> getExpiringVehicleDocuments(
    String vehicleId, {
    int daysThreshold = 90,
  }) async {
    try {
      final docs = await supabase
          .from('vehicle_documents')
          .select('*')
          .eq('vehicle_id', vehicleId);

      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      final expiringDocs = (docs as List).where((doc) {
        final expiryDate = doc['expiry_date'] as String?;
        if (expiryDate == null) return false;

        final expiry = DateTime.parse(expiryDate);
        return expiry.isBefore(thresholdDate) && expiry.isAfter(now);
      }).toList();

      return List<Map<String, dynamic>>.from(expiringDocs);
    } catch (e) {
      debugPrint('Error getting expiring documents: $e');
      return [];
    }
  }

  // ================== SEARCH & FILTER ==================

  /// Filter vehicle applications by criteria
  Future<List<Map<String, dynamic>>> filterVehicleApplications(
    String partnerId, {
    String? status,
    DateTime? afterDate,
    DateTime? beforeDate,
  }) async {
    try {
      debugPrint('Filtering vehicle applications for partner: $partnerId');

      var query = supabase
          .from('partner_vehicle_applications')
          .select('*')
          .eq('partner_id', partnerId);

      if (status != null) {
        query = query.eq('application_status', status);
      }

      if (afterDate != null) {
        query = query.gte('created_at', afterDate.toIso8601String());
      }

      if (beforeDate != null) {
        query = query.lte('created_at', beforeDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error filtering applications: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error filtering applications: $e');
      return [];
    }
  }

  /// Search partner bookings with filters
  Future<List<Map<String, dynamic>>> searchPartnerBookings(
    String partnerId, {
    String? status,
    DateTime? afterDate,
    DateTime? beforeDate,
  }) async {
    try {
      debugPrint('Searching bookings for partner: $partnerId');

      // Get partner's vehicles
      final vehicles = await supabase
          .from('vehicles')
          .select('id')
          .eq('owner_id', partnerId);

      if (vehicles.isEmpty) return [];

      final vehicleIds = vehicles.map((v) => v['id']).cast<String>().toList();

      var query = supabase
          .from('bookings')
          .select(
            'id, renter_id, vehicle_id, start_date, end_date, status, total_price, created_at, vehicles(brand, model), users(full_name, email)',
          )
          .inFilter('vehicle_id', vehicleIds);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (afterDate != null) {
        query = query.gte('start_date', afterDate.toIso8601String());
      }

      if (beforeDate != null) {
        query = query.lte('end_date', beforeDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error searching bookings: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error searching bookings: $e');
      return [];
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
