import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class DriverService {
  static final DriverService _instance = DriverService._internal();

  factory DriverService() {
    return _instance;
  }

  DriverService._internal();

  final supabase = Supabase.instance.client;

  // ==================== DRIVER PROFILE ====================

  /// Get driver profile by user ID
  Future<Map<String, dynamic>?> getDriverProfile(String userId) async {
    try {
      debugPrint('Fetching driver profile for user: $userId');

      final response = await supabase
          .from('drivers')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint('Driver profile fetched: ${response != null}');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching driver profile: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching driver profile: $e');
      rethrow;
    }
  }

  /// Create driver profile
  Future<Map<String, dynamic>> createDriverProfile({
    required String userId,
    required String licenseNumber,
    required DateTime licenseExpiry,
    required String nbiClearanceNumber,
    required DateTime nbiExpiry,
  }) async {
    try {
      debugPrint('Creating driver profile for user: $userId');

      final response = await supabase
          .from('drivers')
          .insert({
            'user_id': userId,
            'license_number': licenseNumber,
            'license_expiry': licenseExpiry.toIso8601String().split('T')[0],
            'license_verified': false,
            'nbi_clearance_number': nbiClearanceNumber,
            'nbi_expiry': nbiExpiry.toIso8601String().split('T')[0],
            'nbi_verified': false,
            'verification_status': 'pending',
            'driver_tier': 'standard',
            'rating': 0.0,
            'total_trips': 0,
          })
          .select()
          .single();

      debugPrint('Driver profile created successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating driver profile: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error creating driver profile: $e');
      rethrow;
    }
  }

  /// Update driver profile
  Future<void> updateDriverProfile(
    String driverId,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('Updating driver profile: $driverId');

      await supabase.from('drivers').update(data).eq('id', driverId);

      debugPrint('Driver profile updated successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating driver profile: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating driver profile: $e');
      rethrow;
    }
  }

  // ==================== DRIVER DOCUMENTS ====================

  /// Upload driver document
  Future<Map<String, dynamic>> uploadDriverDocument({
    required String driverId,
    required String documentType,
    required String fileUrl,
    required DateTime issueDate,
    required DateTime expiryDate,
  }) async {
    try {
      debugPrint('Uploading driver document: $documentType');

      final response = await supabase
          .from('driver_documents')
          .insert({
            'driver_id': driverId,
            'document_type': documentType,
            'file_url': fileUrl,
            'issue_date': issueDate.toIso8601String().split('T')[0],
            'expiry_date': expiryDate.toIso8601String().split('T')[0],
            'status': 'pending',
          })
          .select()
          .single();

      debugPrint('Driver document uploaded successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error uploading document: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error uploading document: $e');
      rethrow;
    }
  }

  /// Get driver documents
  Future<List<Map<String, dynamic>>> getDriverDocuments(String driverId) async {
    try {
      debugPrint('Fetching documents for driver: $driverId');

      final response = await supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} documents');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching documents: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching documents: $e');
      rethrow;
    }
  }

  /// Get document by type
  Future<Map<String, dynamic>?> getDocumentByType(
    String driverId,
    String documentType,
  ) async {
    try {
      debugPrint('Fetching $documentType for driver: $driverId');

      final response = await supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId)
          .eq('document_type', documentType)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching document: $e');
      return null;
    }
  }

  // ==================== AVAILABILITY ====================

  /// Set driver availability toggle
  Future<void> setAvailability(String userId, bool available) async {
    try {
      debugPrint('Setting availability for user: $userId to $available');

      await supabase
          .from('users')
          .update({'is_available': available})
          .eq('id', userId);

      debugPrint('Availability updated successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating availability: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating availability: $e');
      rethrow;
    }
  }

  /// Add availability schedule entry
  Future<Map<String, dynamic>> addScheduleEntry({
    required String driverId,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    DateTime? date,
    bool isAvailable = true,
  }) async {
    try {
      debugPrint('Adding schedule entry for driver: $driverId');

      final response = await supabase
          .from('driver_availability_schedule')
          .insert({
            'driver_id': driverId,
            'day_of_week': dayOfWeek,
            'start_time': startTime,
            'end_time': endTime,
            'date': date != null ? date.toIso8601String().split('T')[0] : null,
            'is_available': isAvailable,
          })
          .select()
          .single();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error adding schedule: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error adding schedule: $e');
      rethrow;
    }
  }

  /// Get driver schedule
  Future<List<Map<String, dynamic>>> getSchedule(String driverId) async {
    try {
      debugPrint('Fetching schedule for driver: $driverId');

      final response = await supabase
          .from('driver_availability_schedule')
          .select()
          .eq('driver_id', driverId)
          .order('day_of_week', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching schedule: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching schedule: $e');
      rethrow;
    }
  }

  // ==================== JOB ASSIGNMENTS ====================

  /// Create job assignment (offer)
  Future<Map<String, dynamic>> createJobAssignment({
    required String bookingId,
    required String driverId,
    required double tripFee,
  }) async {
    try {
      debugPrint(
        'Creating job assignment for booking: $bookingId, driver: $driverId',
      );

      final response = await supabase
          .from('driver_job_assignments')
          .insert({
            'booking_id': bookingId,
            'driver_id': driverId,
            'status': 'pending_offer',
            'trip_fee': tripFee,
          })
          .select()
          .single();

      debugPrint('Job assignment created successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating job assignment: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error creating job assignment: $e');
      rethrow;
    }
  }

  /// Get pending job offers for driver
  Future<List<Map<String, dynamic>>> getPendingOffers(String driverId) async {
    try {
      debugPrint('Fetching pending offers for driver: $driverId');

      final response = await supabase
          .from('driver_job_assignments')
          .select('''
            *,
            bookings:booking_id (
              *,
              vehicles:vehicle_id (brand, model, year, plate_number),
              renter:renter_id (full_name, phone)
            )
          ''')
          .eq('driver_id', driverId)
          .eq('status', 'pending_offer')
          .order('offered_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching offers: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching offers: $e');
      rethrow;
    }
  }

  /// Accept job offer
  Future<void> acceptJobOffer(String jobAssignmentId) async {
    try {
      debugPrint('Accepting job offer: $jobAssignmentId');

      await supabase
          .from('driver_job_assignments')
          .update({
            'status': 'accepted',
            'replied_at': DateTime.now().toIso8601String(),
          })
          .eq('id', jobAssignmentId);

      debugPrint('Job offer accepted');
    } on PostgrestException catch (e) {
      debugPrint('Database error accepting offer: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error accepting offer: $e');
      rethrow;
    }
  }

  /// Decline job offer
  Future<void> declineJobOffer(String jobAssignmentId) async {
    try {
      debugPrint('Declining job offer: $jobAssignmentId');

      await supabase
          .from('driver_job_assignments')
          .update({
            'status': 'rejected',
            'replied_at': DateTime.now().toIso8601String(),
          })
          .eq('id', jobAssignmentId);

      debugPrint('Job offer declined');
    } on PostgrestException catch (e) {
      debugPrint('Database error declining offer: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error declining offer: $e');
      rethrow;
    }
  }

  // ==================== TRIPS ====================

  /// Get active trips for driver
  Future<List<Map<String, dynamic>>> getActiveTrips(String driverId) async {
    try {
      debugPrint('Fetching active trips for driver: $driverId');

      final response = await supabase
          .from('driver_trips')
          .select('''
            *,
            bookings:booking_id (
              *,
              vehicles:vehicle_id (brand, model, year, plate_number),
              renter:renter_id (full_name, phone, location)
            )
          ''')
          .eq('driver_id', driverId)
          .eq('status', 'started')
          .order('pickup_time', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching active trips: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching active trips: $e');
      rethrow;
    }
  }

  /// Get completed trips for driver
  Future<List<Map<String, dynamic>>> getCompletedTrips(
    String driverId, {
    int limit = 50,
  }) async {
    try {
      debugPrint('Fetching completed trips for driver: $driverId');

      final response = await supabase
          .from('driver_trips')
          .select('''
            *,
            bookings:booking_id (
              *,
              vehicles:vehicle_id (brand, model, year),
              renter:renter_id (full_name)
            )
          ''')
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .order('dropoff_time', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching completed trips: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching completed trips: $e');
      rethrow;
    }
  }

  /// Create trip record
  Future<Map<String, dynamic>> createTrip({
    required String bookingId,
    required String driverId,
    required String pickupLocation,
    required String dropoffLocation,
  }) async {
    try {
      debugPrint('Creating trip for booking: $bookingId');

      final response = await supabase
          .from('driver_trips')
          .insert({
            'booking_id': bookingId,
            'driver_id': driverId,
            'pickup_location': pickupLocation,
            'dropoff_location': dropoffLocation,
            'status': 'pending',
            'pickup_time': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating trip: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error creating trip: $e');
      rethrow;
    }
  }

  /// Start trip
  Future<void> startTrip(String tripId) async {
    try {
      debugPrint('Starting trip: $tripId');

      await supabase
          .from('driver_trips')
          .update({
            'status': 'started',
            'pickup_time': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId);

      debugPrint('Trip started');
    } on PostgrestException catch (e) {
      debugPrint('Database error starting trip: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error starting trip: $e');
      rethrow;
    }
  }

  /// Complete trip
  Future<void> completeTrip(
    String tripId, {
    double? distanceKm,
    int? durationMinutes,
  }) async {
    try {
      debugPrint('Completing trip: $tripId');

      await supabase
          .from('driver_trips')
          .update({
            'status': 'completed',
            'dropoff_time': DateTime.now().toIso8601String(),
            'distance_km': distanceKm,
            'duration_minutes': durationMinutes,
          })
          .eq('id', tripId);

      debugPrint('Trip completed');
    } on PostgrestException catch (e) {
      debugPrint('Database error completing trip: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error completing trip: $e');
      rethrow;
    }
  }

  /// Rate trip (driver rates renter)
  Future<void> rateTrip(
    String tripId, {
    required double rating,
    required String comment,
  }) async {
    try {
      debugPrint('Rating trip: $tripId');

      await supabase
          .from('driver_trips')
          .update({'driver_comment': comment})
          .eq('id', tripId);

      debugPrint('Trip rated by driver');
    } on PostgrestException catch (e) {
      debugPrint('Database error rating trip: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error rating trip: $e');
      rethrow;
    }
  }

  // ==================== EARNINGS ====================

  /// Get driver earnings for period
  Future<double> getEarnings(
    String driverId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      debugPrint('Fetching earnings for driver: $driverId');

      var query = supabase
          .from('driver_earnings')
          .select('net_earnings')
          .eq('driver_id', driverId);

      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }
      if (toDate != null) {
        query = query.lte('created_at', toDate.toIso8601String());
      }

      final response = await query;
      final earnings = response as List;

      double total = 0;
      for (final earning in earnings) {
        total += (earning['net_earnings'] as num?)?.toDouble() ?? 0;
      }

      debugPrint('Total earnings: $total');
      return total;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching earnings: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching earnings: $e');
      rethrow;
    }
  }

  /// Get earnings history
  Future<List<Map<String, dynamic>>> getEarningsHistory(
    String driverId, {
    int limit = 100,
  }) async {
    try {
      debugPrint('Fetching earnings history for driver: $driverId');

      final response = await supabase
          .from('driver_earnings')
          .select('''
            *,
            driver_trips:trip_id (
              booking_id,
              renter:renter_id (full_name),
              distance_km,
              duration_minutes
            )
          ''')
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching earnings history: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching earnings history: $e');
      rethrow;
    }
  }

  /// Create earnings record
  Future<Map<String, dynamic>> createEarnings({
    required String driverId,
    String? tripId,
    required double tripFee,
    double commissionPercentage = 15,
  }) async {
    try {
      debugPrint('Creating earnings record for driver: $driverId');

      final commissionAmount = tripFee * (commissionPercentage / 100);
      final netEarnings = tripFee - commissionAmount;

      final response = await supabase
          .from('driver_earnings')
          .insert({
            'driver_id': driverId,
            'trip_id': tripId,
            'trip_fee': tripFee,
            'commission_percentage': commissionPercentage,
            'commission_amount': commissionAmount,
            'net_earnings': netEarnings,
            'payout_status': 'pending',
          })
          .select()
          .single();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating earnings: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error creating earnings: $e');
      rethrow;
    }
  }

  /// Mark earnings as paid
  Future<void> markEarningsAsPaid(String earningsId) async {
    try {
      debugPrint('Marking earnings as paid: $earningsId');

      await supabase
          .from('driver_earnings')
          .update({
            'payout_status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('id', earningsId);

      debugPrint('Earnings marked as paid');
    } on PostgrestException catch (e) {
      debugPrint('Database error marking as paid: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error marking as paid: $e');
      rethrow;
    }
  }

  // ==================== STATISTICS ====================

  /// Get driver stats
  Future<Map<String, dynamic>> getDriverStats(String driverId) async {
    try {
      debugPrint('Fetching stats for driver: $driverId');

      final profile = await getDriverProfile(driverId);

      if (profile == null) {
        return {
          'totalTrips': 0,
          'rating': 0.0,
          'tier': 'standard',
          'earnings': 0.0,
        };
      }

      final trips = await supabase
          .from('driver_trips')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'completed');

      final earnings = await getEarnings(driverId);

      return {
        'totalTrips': (trips as List).length,
        'rating': profile['rating'] ?? 0.0,
        'tier': profile['driver_tier'] ?? 'standard',
        'earnings': earnings,
        'verification': profile['verification_status'] ?? 'pending',
      };
    } catch (e) {
      debugPrint('Error fetching driver stats: $e');
      return {
        'totalTrips': 0,
        'rating': 0.0,
        'tier': 'standard',
        'earnings': 0.0,
      };
    }
  }

  // ==================== DRIVER APPLICATION (ADMIN) ====================

  /// Get driver's application status
  Future<String?> getApplicationStatus(String driverId) async {
    try {
      debugPrint('Fetching application status for driver: $driverId');
      final response = await supabase
          .from('users')
          .select('application_status')
          .eq('id', driverId)
          .maybeSingle();

      return response?['application_status'] as String?;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching application status: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error fetching application status: $e');
      return null;
    }
  }

  /// Approve driver application (called by admin)
  Future<void> approveDriverApplication(String driverId, String notes) async {
    try {
      debugPrint('Approving driver application: $driverId');
      await supabase
          .from('users')
          .update({'application_status': 'approved'})
          .eq('id', driverId);

      debugPrint('Driver application approved');
    } on PostgrestException catch (e) {
      debugPrint('Database error approving driver application: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error approving driver application: $e');
      rethrow;
    }
  }

  /// Reject driver application (called by admin)
  Future<void> rejectDriverApplication(String driverId, String reason) async {
    try {
      debugPrint('Rejecting driver application: $driverId');
      await supabase
          .from('users')
          .update({'application_status': 'rejected'})
          .eq('id', driverId);

      debugPrint('Driver application rejected');
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting driver application: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error rejecting driver application: $e');
      rethrow;
    }
  }

  // ==================== DOCUMENT VALIDATION ====================

  /// Validate driver documents (check expiry dates)
  Future<Map<String, dynamic>> validateDocuments(String driverId) async {
    try {
      debugPrint('Validating documents for driver: $driverId');

      final docs = await getDriverDocuments(driverId);
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
      final requiredDocs = ['license', 'nbi'];
      final uploadedTypes = docs.map((d) => d['document_type']).toSet();

      for (var required in requiredDocs) {
        if (!uploadedTypes.contains(required)) {
          validation['missing_required'].add(required);
          validation['valid'] = false;
        }
      }

      debugPrint('Document validation: ${validation['valid']}');
      return validation;
    } catch (e) {
      debugPrint('Error validating documents: $e');
      return {'valid': false, 'error': e.toString()};
    }
  }

  /// Get expiring documents (within N days)
  Future<List<Map<String, dynamic>>> getExpiringDocuments(
    String driverId, {
    int daysThreshold = 90,
  }) async {
    try {
      debugPrint(
        'Fetching expiring documents for driver: $driverId (within $daysThreshold days)',
      );

      final docs = await getDriverDocuments(driverId);
      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      final expiringDocs = docs.where((doc) {
        final expiryDate = doc['expiry_date'] as String?;
        if (expiryDate == null) return false;

        final expiry = DateTime.parse(expiryDate);
        return expiry.isBefore(thresholdDate) && expiry.isAfter(now);
      }).toList();

      debugPrint('Found ${expiringDocs.length} expiring documents');
      return List<Map<String, dynamic>>.from(expiringDocs);
    } catch (e) {
      debugPrint('Error fetching expiring documents: $e');
      return [];
    }
  }

  // ==================== SEARCH & FILTER ====================

  /// Filter job offers by criteria
  Future<List<Map<String, dynamic>>> filterJobOffers(
    String driverId, {
    String? status,
    DateTime? afterDate,
    DateTime? beforeDate,
    double? minTripFee,
    double? maxTripFee,
  }) async {
    try {
      debugPrint('Filtering job offers for driver: $driverId');

      var query = supabase
          .from('driver_job_assignments')
          .select(
            'id, booking_id, driver_id, trip_fee, status, created_at, bookings(id, start_date, end_date, total_price, pickup_location, dropoff_location, vehicles(brand, model), users(full_name))',
          )
          .eq('driver_id', driverId);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (afterDate != null) {
        query = query.gte('created_at', afterDate.toIso8601String());
      }

      if (beforeDate != null) {
        query = query.lte('created_at', beforeDate.toIso8601String());
      }

      if (minTripFee != null) {
        query = query.gte('trip_fee', minTripFee);
      }

      if (maxTripFee != null) {
        query = query.lte('trip_fee', maxTripFee);
      }

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error filtering job offers: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error filtering job offers: $e');
      return [];
    }
  }

  // ==================== DOCUMENT RENEWAL ====================

  /// Renew an expired/expiring driver document
  Future<Map<String, dynamic>?> renewDocument({
    required String documentId,
    required String newFileUrl,
    required DateTime newExpiryDate,
  }) async {
    try {
      debugPrint('Renewing driver document: $documentId');

      // Get the old document
      final oldDoc = await supabase
          .from('driver_documents')
          .select()
          .eq('id', documentId)
          .maybeSingle();

      if (oldDoc == null) {
        throw Exception('Document not found: $documentId');
      }

      // Update the document with new file and expiry
      final updated = await supabase
          .from('driver_documents')
          .update({
            'file_url': newFileUrl,
            'expiry_date': newExpiryDate.toIso8601String(),
            'status': 'pending', // Set to pending for admin review
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

  /// Bulk renew multiple documents for a driver
  Future<int> bulkRenewDocuments({
    required String driverId,
    required Map<String, dynamic>
    documentUpdates, // {documentId: {fileUrl, expiryDate}, ...}
  }) async {
    try {
      debugPrint('Bulk renewing documents for driver: $driverId');

      int renewedCount = 0;

      for (var docEntry in documentUpdates.entries) {
        try {
          final documentId = docEntry.key;
          final updates = docEntry.value as Map<String, dynamic>;
          final newFileUrl = updates['fileUrl'] as String;
          final newExpiryDate = DateTime.parse(updates['expiryDate'] as String);

          await renewDocument(
            documentId: documentId,
            newFileUrl: newFileUrl,
            newExpiryDate: newExpiryDate,
          );

          renewedCount++;
        } catch (e) {
          debugPrint('Failed to renew document: $e');
          continue;
        }
      }

      debugPrint(
        'Bulk renewal completed: $renewedCount/${documentUpdates.length} documents',
      );
      return renewedCount;
    } catch (e) {
      debugPrint('Error in bulk renewal: $e');
      return 0;
    }
  }

  /// Get documents pending renewal (expired or expiring within threshold)
  Future<List<Map<String, dynamic>>> getDocumentsPendingRenewal({
    required String driverId,
    int daysThreshold = 7,
  }) async {
    try {
      debugPrint(
        'Getting documents pending renewal for driver: $driverId (within $daysThreshold days)',
      );

      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      final docs = await supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId);

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

  /// Request document renewal notification to driver
  Future<bool> requestDocumentRenewal({
    required String driverId,
    required String documentType,
    String? reason,
  }) async {
    try {
      debugPrint(
        'Requesting document renewal for driver: $driverId (type: $documentType)',
      );

      // Log action
      await supabase.from('admin_audit_logs').insert({
        'entity_id': driverId,
        'entity_type': 'document_renewal_request',
        'action': 'renewal_requested',
        'notes':
            reason ?? 'Requested renewal of $documentType for driver $driverId',
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error requesting document renewal: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error requesting document renewal: $e');
      return false;
    }
  }

  // ==================== UTILITIES ====================

  /// Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
