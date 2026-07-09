import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'booking_service.dart';
import 'notification_service.dart';
import 'user_restriction_service.dart';

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
    String? licenseUrl,
    String? nbiFileUrl,
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
            'nbi_verified': false,
            if (licenseUrl != null && licenseUrl.isNotEmpty)
              'license_url': licenseUrl,
            if (nbiFileUrl != null && nbiFileUrl.isNotEmpty)
              'nbi_file_url': nbiFileUrl,
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

  /// Upload a driver document file to `driver_documents` bucket.
  Future<String> uploadToDriverDocumentsBucket({
    required String userId,
    required File file,
    required String documentType,
  }) async {
    final bytes = await file.readAsBytes();
    final extension = file.path.contains('.')
        ? file.path.split('.').last.toLowerCase()
        : 'jpg';
    final objectPath =
        '$userId/${documentType}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await supabase.storage
        .from('driver_documents')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from('driver_documents').getPublicUrl(objectPath);
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

      if (available) {
        final restriction = await UserRestrictionService().getUserRestriction(
          userId,
        );
        if (restriction.isBlocked || restriction.isAccountRestricted) {
          throw Exception(
            'Driver availability cannot be turned on while the account is restricted',
          );
        }
      }

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

  /// Get pending or newly assigned job offers for the current driver user.
  Future<List<Map<String, dynamic>>> getPendingOffers(String userId) async {
    try {
      debugPrint('Fetching pending offers for driver user: $userId');

      final driverProfile = await supabase
          .from('drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      final driverProfileId = driverProfile?['id']?.toString();
      if (driverProfileId == null || driverProfileId.isEmpty) {
        return [];
      }

      final response = await supabase
          .from('driver_job_assignments')
          .select('''
            *,
            bookings:booking_id (
              id,
              renter_id,
              status,
              start_date,
              end_date,
              start_at,
              end_at,
              total_price,
              total_cost,
              pickup_location,
              dropoff_location,
              vehicles:vehicle_id (
                id,
                brand,
                model,
                year,
                vehicle_name,
                plate_number
              ),
              renter:renter_id (
                id,
                full_name,
                email,
                phone
              )
            )
          ''')
          .eq('driver_id', driverProfileId)
          .inFilter('status', ['pending_offer', 'assigned'])
          .order('created_at', ascending: false);

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

      final earning = await supabase
          .from('driver_earnings')
          .select('driver_id, net_earnings')
          .eq('id', earningsId)
          .maybeSingle();
      final driverId = earning?['driver_id']?.toString();
      if (driverId != null && driverId.isNotEmpty) {
        await NotificationService().createNotification(
          userId: driverId,
          title: 'Driver Payout Released',
          message:
              'Your driver payout of PHP ${((earning?['net_earnings'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} has been released.',
          type: 'payment_release',
          data: {
            'earnings_id': earningsId,
            'amount': (earning?['net_earnings'] as num?)?.toDouble() ?? 0,
            'event': 'driver_payment_released',
          },
        );
      }

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
      final user = await supabase
          .from('users')
          .select(
            'id_verified, verification_status, application_status, is_available',
          )
          .eq('id', driverId)
          .maybeSingle();
      final userIsVerified = user?['id_verified'] == true;
      final userVerificationStatus = userIsVerified
          ? 'verified'
          : (user?['verification_status'] ?? 'pending');
      final userApplicationStatus = user?['application_status']
          ?.toString()
          .trim();

      if (profile == null) {
        return {
          'total_trips': 0,
          'rating': 0.0,
          'driver_tier': 'standard',
          'earnings': 0.0,
          'verification_status': userVerificationStatus,
          'application_status':
              userApplicationStatus == null || userApplicationStatus.isEmpty
              ? 'basic'
              : userApplicationStatus,
          'is_available': user?['is_available'] ?? false,
        };
      }

      final trips = await supabase
          .from('driver_trips')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'completed');

      final earnings = await getEarnings(driverId);

      return {
        'total_trips': (trips as List).length,
        'rating': profile['rating'] ?? 0.0,
        'driver_tier': profile['driver_tier'] ?? 'standard',
        'earnings': earnings,
        'verification_status': userIsVerified
            ? 'verified'
            : (profile['verification_status'] ??
                  user?['verification_status'] ??
                  'pending'),
        'application_status':
            profile['application_status'] ??
            (userApplicationStatus == null || userApplicationStatus.isEmpty
                ? 'basic'
                : userApplicationStatus),
        'is_available': user?['is_available'] ?? false,
      };
    } catch (e) {
      debugPrint('Error fetching driver stats: $e');
      return {
        'total_trips': 0,
        'rating': 0.0,
        'driver_tier': 'standard',
        'earnings': 0.0,
        'verification_status': 'pending',
        'application_status': 'basic',
        'is_available': false,
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

  /// Mark the logged-in driver's certification application as submitted.
  ///
  /// Basic drivers can still be assigned to trips when their identity is
  /// verified; this status only controls the Certified PSDC Driver application.
  Future<void> markDriverApplicationSubmitted(String userId) async {
    try {
      debugPrint('Marking driver certification application pending: $userId');

      await supabase
          .from('users')
          .update({'application_status': 'pending'})
          .eq('id', userId);

      final existingDriver = await getDriverProfile(userId);
      if (existingDriver == null) {
        await supabase.from('drivers').insert({
          'user_id': userId,
          'verification_status': 'pending',
          'driver_tier': 'standard',
        });
      } else {
        await updateDriverProfile(existingDriver['id'].toString(), {
          'verification_status': 'pending',
        });
      }
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error marking driver application pending: ${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('Error marking driver application pending: $e');
      rethrow;
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

      await NotificationService().notifyDriverApplicationApproved(
        driverId: driverId,
      );

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
            'id, booking_id, driver_id, trip_fee, status, created_at, bookings(id, start_date, end_date, total_price, pickup_location, dropoff_location, vehicles(brand, model), users:users!bookings_renter_id_fkey(full_name))',
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

  Future<List<Map<String, dynamic>>> getAssignedBookings(String userId) async {
    try {
      debugPrint('Fetching assigned bookings for driver: $userId');

      final driverProfile = await supabase
          .from('drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      final driverProfileId = driverProfile?['id']?.toString();
      if (driverProfileId == null || driverProfileId.isEmpty) {
        return [];
      }

      final response = await supabase
          .from('bookings')
          .select('''
            id,
            renter_id,
            vehicle_id,
            driver_id,
            status,
            start_at,
            end_at,
            start_date,
            end_date,
            total_price,
            total_cost,
            pickup_location,
            dropoff_location,
            picked_up_at,
            returned_at,
            vehicles:vehicle_id (
              id,
              brand,
              model,
              year,
              vehicle_name
            ),
            renter:renter_id (
              id,
              full_name,
              email,
              phone
            )
          ''')
          .eq('driver_id', driverProfileId)
          .inFilter('status', ['confirmed', 'approved', 'active'])
          .order('start_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching assigned bookings: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching assigned bookings: $e');
      return [];
    }
  }

  Future<void> markAssignedBookingPickedUp(String bookingId) {
    return BookingService().markBookingPickedUp(bookingId);
  }

  Future<double> completeAssignedBookingReturn({
    required String bookingId,
    required DateTime returnedAt,
  }) {
    return BookingService().completeBookingReturn(
      bookingId: bookingId,
      returnedAt: returnedAt,
    );
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

  // ==================== DRIVER VERIFICATION WORKFLOW ====================

  /// Upload driver license to storage and create document record
  Future<Map<String, dynamic>> uploadLicenseDocument({
    required String driverId,
    required String userId,
    required File licenseFile,
    required String licenseNumber,
    required DateTime issueDate,
    required DateTime expiryDate,
  }) async {
    try {
      debugPrint('Uploading driver license for driver: $driverId');

      // Upload file to storage
      final fileUrl = await uploadToDriverDocumentsBucket(
        userId: userId,
        file: licenseFile,
        documentType: 'license',
      );

      // Create document record
      final docRecord = await uploadDriverDocument(
        driverId: driverId,
        documentType: 'license',
        fileUrl: fileUrl,
        issueDate: issueDate,
        expiryDate: expiryDate,
      );

      // Update drivers table with license URL
      await updateDriverProfile(driverId, {'license_url': fileUrl});

      debugPrint('License document uploaded and recorded successfully');
      return {
        'success': true,
        'document_id': docRecord['id'],
        'file_url': fileUrl,
      };
    } catch (e) {
      debugPrint('Error uploading license document: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload NBI clearance to storage and create document record
  Future<Map<String, dynamic>> uploadNBIDocument({
    required String driverId,
    required String userId,
    required File nbiFile,
    required String nbiNumber,
    required DateTime issueDate,
    required DateTime expiryDate,
  }) async {
    try {
      debugPrint('Uploading NBI clearance for driver: $driverId');

      // Upload file to storage
      final fileUrl = await uploadToDriverDocumentsBucket(
        userId: userId,
        file: nbiFile,
        documentType: 'nbi',
      );

      // Create document record
      final docRecord = await uploadDriverDocument(
        driverId: driverId,
        documentType: 'nbi',
        fileUrl: fileUrl,
        issueDate: issueDate,
        expiryDate: expiryDate,
      );

      // Update drivers table with NBI URL
      await updateDriverProfile(driverId, {'nbi_file_url': fileUrl});

      debugPrint('NBI document uploaded and recorded successfully');
      return {
        'success': true,
        'document_id': docRecord['id'],
        'file_url': fileUrl,
      };
    } catch (e) {
      debugPrint('Error uploading NBI document: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Approve individual driver document (called by admin)
  Future<bool> approveDriverDocument(
    String documentId, {
    String? adminNotes,
  }) async {
    try {
      debugPrint('Approving driver document: $documentId');

      await supabase
          .from('driver_documents')
          .update({
            'status': 'verified',
            'verified_at': DateTime.now().toIso8601String(),
            if (adminNotes != null) 'admin_notes': adminNotes,
          })
          .eq('id', documentId);

      debugPrint('Document approved successfully');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error approving document: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error approving document: $e');
      return false;
    }
  }

  /// Reject individual driver document (called by admin)
  Future<bool> rejectDriverDocument(
    String documentId, {
    required String reason,
  }) async {
    try {
      debugPrint('Rejecting driver document: $documentId');

      await supabase
          .from('driver_documents')
          .update({
            'status': 'rejected',
            'admin_notes': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', documentId);

      debugPrint('Document rejected successfully');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting document: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error rejecting document: $e');
      return false;
    }
  }

  /// Complete driver verification - mark all documents as verified and update driver status
  Future<Map<String, dynamic>> completeDriverVerification({
    required String driverId,
    String? tier = 'standard',
    String? adminNotes,
  }) async {
    try {
      debugPrint('Completing driver verification for: $driverId');

      // Get all pending documents
      final docs = await supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'pending');

      // Mark all as verified
      for (var doc in docs) {
        await supabase
            .from('driver_documents')
            .update({
              'status': 'verified',
              'verified_at': DateTime.now().toIso8601String(),
              if (adminNotes != null) 'admin_notes': adminNotes,
            })
            .eq('id', doc['id']);
      }

      // Update driver profile
      await updateDriverProfile(driverId, {
        'verification_status': 'verified',
        'license_verified': true,
        'nbi_verified': true,
        'driver_tier': tier,
      });

      final driverProfile = await supabase
          .from('drivers')
          .select('user_id')
          .eq('id', driverId)
          .maybeSingle();
      final driverUserId = driverProfile?['user_id']?.toString();
      if (driverUserId != null && driverUserId.isNotEmpty) {
        await supabase
            .from('users')
            .update({
              'verification_status': 'verified',
              'id_verified': true,
              'is_available': true,
            })
            .eq('id', driverUserId);

        await NotificationService().notifyVerificationApproved(
          userId: driverUserId,
          role: 'driver',
        );
      }

      debugPrint('Driver verification completed successfully');
      return {
        'success': true,
        'message': 'Driver verified successfully',
        'documents_verified': docs.length,
      };
    } catch (e) {
      debugPrint('Error completing driver verification: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Reject driver verification - update driver status and reject all documents
  Future<Map<String, dynamic>> rejectDriverVerification({
    required String driverId,
    required String reason,
  }) async {
    try {
      debugPrint('Rejecting driver verification for: $driverId');

      // Get all pending documents
      final docs = await supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'pending');

      // Mark all as rejected
      for (var doc in docs) {
        await supabase
            .from('driver_documents')
            .update({
              'status': 'rejected',
              'admin_notes': reason,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', doc['id']);
      }

      // Update driver profile
      await updateDriverProfile(driverId, {'verification_status': 'rejected'});

      final driverProfile = await supabase
          .from('drivers')
          .select('user_id')
          .eq('id', driverId)
          .maybeSingle();
      final driverUserId = driverProfile?['user_id']?.toString();
      if (driverUserId != null && driverUserId.isNotEmpty) {
        await supabase
            .from('users')
            .update({'verification_status': 'rejected', 'id_verified': false})
            .eq('id', driverUserId);
      }

      debugPrint('Driver verification rejected successfully');
      return {
        'success': true,
        'message': 'Driver verification rejected',
        'documents_rejected': docs.length,
      };
    } catch (e) {
      debugPrint('Error rejecting driver verification: $e');
      return {'success': false, 'error': e.toString()};
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
