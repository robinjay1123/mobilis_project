import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'chat_service.dart';
import 'notification_service.dart';
import 'user_restriction_service.dart';
import 'vehicle_service.dart';
import 'booking_inspection_service.dart';
import 'trip_rating_service.dart';
import 'loyalty_service.dart';
import 'vehicle_turnaround_service.dart';
import '../utils/pricing_policy.dart';
import '../utils/philippine_geocoding.dart';

class BookingService {
  static final BookingService _instance = BookingService._internal();

  factory BookingService() {
    return _instance;
  }

  BookingService._internal();

  final supabase = Supabase.instance.client;
  static const List<String> _bookingBlockingStatuses = [
    'pending',
    'Pending',
    'PENDING',
    'requested',
    'Requested',
    'REQUESTED',
    'reserved',
    'Reserved',
    'RESERVED',
    'approved',
    'Approved',
    'APPROVED',
    'confirmed',
    'Confirmed',
    'CONFIRMED',
    'active',
    'Active',
    'ACTIVE',
    'ongoing',
    'Ongoing',
    'ONGOING',
    'paid',
    'Paid',
    'PAID',
    'unpaid',
    'Unpaid',
    'UNPAID',
    'in_progress',
    'In_Progress',
    'IN_PROGRESS',
  ];

  static const Set<String> _nonBlockingStatuses = {
    'cancelled',
    'canceled',
    'rejected',
    'completed',
    'returned',
    'expired',
  };

  static bool _isBlockingStatus(String? status) {
    if (status == null) return false;
    final normalized = status.toString().trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return !_nonBlockingStatuses.contains(normalized);
  }

  static (DateTime, DateTime)? _bookingInterval(Map<String, dynamic> row) {
    final startAt = row['start_at']?.toString().trim() ?? '';
    final endAt = row['end_at']?.toString().trim() ?? '';
    if (startAt.isNotEmpty && endAt.isNotEmpty) {
      final start = DateTime.tryParse(startAt)?.toLocal();
      final end = DateTime.tryParse(endAt)?.toLocal();
      if (start != null && end != null && end.isAfter(start)) {
        return (start, end);
      }
    }

    final startDate = DateTime.tryParse(
      row['start_date']?.toString().trim() ?? '',
    );
    final endDate = DateTime.tryParse(row['end_date']?.toString().trim() ?? '');
    if (startDate == null || endDate == null) return null;
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final inclusiveEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(const Duration(days: 1));
    return (
      start,
      inclusiveEnd.isAfter(start)
          ? inclusiveEnd
          : start.add(const Duration(days: 1)),
    );
  }

  /// App-side fallback for projects where the scheduled database job is not
  /// available. The database function is idempotent and only touches overdue
  /// pending bookings.
  Future<int> processExpiredPendingBookings() async {
    try {
      final response = await supabase.rpc('process_expired_pending_bookings');
      if (response is int) return response;
      return int.tryParse(response?.toString() ?? '') ?? 0;
    } on PostgrestException catch (error) {
      final functionIsMissing =
          error.code == '42883' ||
          error.message.toLowerCase().contains(
            'process_expired_pending_bookings',
          );
      if (!functionIsMissing) {
        debugPrint('Could not process expired bookings: ${error.message}');
      }
      return 0;
    } catch (error) {
      debugPrint('Could not process expired bookings: $error');
      return 0;
    }
  }

  // Get bookings for a partner (via their vehicles)
  // Note: vehicles use owner_id which references users.id
  Future<List<Map<String, dynamic>>> getPartnerBookings(String userId) async {
    try {
      await processExpiredPendingBookings();
      debugPrint('Fetching bookings for owner: $userId');

      // First get owner's vehicles
      final vehicles = await supabase
          .from('vehicles')
          .select('id')
          .eq('owner_id', userId);

      if (vehicles.isEmpty) {
        debugPrint('No vehicles found for partner');
        return [];
      }

      final vehicleIds = vehicles.map((v) => v['id'] as String).toList();

      // Then get bookings for those vehicles
      final response = await supabase
          .from('bookings')
          .select(
            '*, vehicles(*), users:users!bookings_renter_id_fkey(*), '
            'driver:drivers!bookings_driver_id_fkey(id, user_id, '
            '  users!drivers_user_id_fkey(id, full_name, email, phone)), '
            'job_assignments:driver_job_assignments!driver_job_assignments_booking_id_fkey('
            '  id, driver_id, status, trip_fee, offered_at, replied_at, created_at, updated_at)',
          )
          .inFilter('vehicle_id', vehicleIds)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} bookings');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching partner bookings: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching partner bookings: $e');
      rethrow;
    }
  }

  // Get bookings for a partner by status
  Future<List<Map<String, dynamic>>> getPartnerBookingsByStatus(
    String userId,
    String status,
  ) async {
    try {
      await processExpiredPendingBookings();
      debugPrint('Fetching $status bookings for owner: $userId');

      // First get owner's vehicles
      final vehicles = await supabase
          .from('vehicles')
          .select('id')
          .eq('owner_id', userId);

      if (vehicles.isEmpty) {
        return [];
      }

      final vehicleIds = vehicles.map((v) => v['id'] as String).toList();

      // Then get bookings with status filter
      final response = await supabase
          .from('bookings')
          .select(
            '*, vehicles(*), users:users!bookings_renter_id_fkey(*), '
            'driver:drivers!bookings_driver_id_fkey(id, user_id, '
            '  users!drivers_user_id_fkey(id, full_name, email, phone)), '
            'job_assignments:driver_job_assignments!driver_job_assignments_booking_id_fkey('
            '  id, driver_id, status, trip_fee, offered_at, replied_at, created_at, updated_at)',
          )
          .inFilter('vehicle_id', vehicleIds)
          .eq('status', status)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} $status bookings');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching bookings by status: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching bookings by status: $e');
      rethrow;
    }
  }

  // Get bookings for a renter
  // Note: bookings use renter_id which references users.id
  Future<List<Map<String, dynamic>>> getRenterBookings(String userId) async {
    try {
      await processExpiredPendingBookings();
      debugPrint('Fetching bookings for renter: $userId');

      final response = await supabase
          .from('bookings')
          .select('''
            *,
            vehicles:vehicle_id (
              id,
              brand,
              model,
              year,
              owner_id,
              owner_role,
              operator_id,
              owner:owner_id (
                id,
                full_name,
                role
              ),
              vehicle_name,
              rating,
              price_per_day,
              vehicle_images(image_url, display_order)
            ),
            driver:drivers!bookings_driver_id_fkey (
              id,
              user_id,
              users!drivers_user_id_fkey (
                id,
                full_name,
                email,
                phone
              )
            ),
            job_assignments:driver_job_assignments!driver_job_assignments_booking_id_fkey (
              id,
              driver_id,
              status,
              trip_fee,
              created_at,
              updated_at
            ),
            trip_ratings(rating)
          ''')
          .eq('renter_id', userId)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} bookings');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching renter bookings: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching renter bookings: $e');
      rethrow;
    }
  }

  // Get booking by ID
  Future<Map<String, dynamic>?> getBookingById(String bookingId) async {
    try {
      debugPrint('Fetching booking: $bookingId');

      final response = await supabase
          .from('bookings')
          .select('*, vehicles(*, owner:owner_id(id, full_name, role))')
          .eq('id', bookingId)
          .maybeSingle();

      debugPrint('Booking fetched: ${response != null}');
      if (response == null) return null;

      final booking = Map<String, dynamic>.from(response);
      final renterId = booking['renter_id']?.toString();
      if (renterId != null && renterId.isNotEmpty) {
        booking['users'] = await _getUserById(renterId);
      }

      return booking;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching booking: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching booking: $e');
      rethrow;
    }
  }

  // Create a new booking
  Future<Map<String, dynamic>> createBooking({
    required String renterId,
    required String vehicleId,
    required DateTime startAt,
    required DateTime endAt,
    required double totalPrice,
    double? rentalSubtotal,
    double? discountAmount,
    String? appliedVoucher,
    double? deliveryDistanceKm,
    double? deliveryRatePerKm,
    double? deliveryFee,
    bool withDriver = false,
    double? driverFee,
    String? pickupLocation,
    String? dropoffLocation,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    DateTime? rentalTermsAcceptedAt,
    String? rentalTermsSnapshot,
    double? securityDeposit,
    double? reservationFeeAmount,
    String? reservationPaymentReference,
    String? reservationPaymentProofUrl,
    String? reservationPaymentMethod,
    String? reservationPaymentType,
    String? reservationPaymentSenderPhone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelationship,
    String? renterSignatureText,
    String? renterSignatureUrl,
    String? renterValidIdUrl,
    String? renterSelfieUrl,
    String? coTravelerName,
    String? coTravelerPhone,
    String? coTravelerLicense,
    String? coTravelerSignatureText,
    String? coTravelerSignatureUrl,
    String? coTravelerValidIdUrl,
    String? coTravelerSelfieUrl,
  }) async {
    try {
      debugPrint('Creating booking for renter: $renterId, vehicle: $vehicleId');

      if (renterSelfieUrl == null || renterSelfieUrl.trim().isEmpty) {
        throw Exception('A clear renter selfie is required before booking');
      }

      if (renterSignatureUrl == null || renterSignatureUrl.trim().isEmpty) {
        throw Exception('A drawn digital signature is required before booking');
      }

      if (renterValidIdUrl == null || renterValidIdUrl.trim().isEmpty) {
        throw Exception('A valid ID photo is required before booking');
      }

      final coTravelerFields = [
        coTravelerName?.trim() ?? '',
        coTravelerPhone?.trim() ?? '',
        coTravelerLicense?.trim() ?? '',
      ];
      if (coTravelerFields.any((value) => value.isEmpty)) {
        throw Exception(
          'Co-traveler name, phone number, and license number are required',
        );
      }

      if (coTravelerSignatureUrl == null ||
          coTravelerSignatureUrl.trim().isEmpty ||
          coTravelerValidIdUrl == null ||
          coTravelerValidIdUrl.trim().isEmpty ||
          coTravelerSelfieUrl == null ||
          coTravelerSelfieUrl.trim().isEmpty) {
        throw Exception(
          'Co-traveler signature, valid ID, and selfie are required',
        );
      }

      final cleanDestination = dropoffLocation?.trim() ?? '';
      if (cleanDestination.isEmpty) {
        throw Exception('Please select a trip destination before booking');
      }

      // Execute restriction check, vehicle state query, and overlapping bookings query concurrently
      final (
        restriction,
        vehicleState,
        overlappingBookings,
      ) = await (
        UserRestrictionService().getUserRestriction(renterId),
        supabase
            .from('vehicles')
            .select('id,owner_role,plate_number,is_available,is_posted,status')
            .eq('id', vehicleId)
            .maybeSingle(),
        supabase
            .from('bookings')
            .select('id,start_at,end_at,start_date,end_date,status')
            .eq('vehicle_id', vehicleId)
            .inFilter('status', _bookingBlockingStatuses),
      ).wait;

      if (restriction.isBlocked || restriction.isAccountRestricted) {
        throw Exception(
          'This renter account is restricted and cannot book vehicles right now',
        );
      }

      final vehicleStatus =
          vehicleState?['status']?.toString().trim().toLowerCase() ?? '';
      final vehicleCanBeBooked =
          vehicleState?['is_available'] == true &&
          vehicleState?['is_posted'] == true &&
          !{'inactive', 'archived', 'deleted'}.contains(vehicleStatus);
      if (!vehicleCanBeBooked) {
        throw Exception('This vehicle is currently unavailable for booking');
      }

      if (vehicleState?['owner_role']?.toString().toLowerCase() == 'partner') {
        final approvedAndListed = await VehicleService().isVehicleBookable(
          vehicleId,
        );
        if (!approvedAndListed) {
          throw Exception(
            'This partner vehicle is not approved for rental anymore',
          );
        }
      }

      for (final b in List<Map<String, dynamic>>.from(overlappingBookings)) {
        final status = b['status']?.toString();
        if (!_isBlockingStatus(status)) continue;
        final interval = _bookingInterval(b);
        if (interval == null) continue;
        final (existingStart, existingEnd) = interval;
        if (startAt.isBefore(existingEnd) && endAt.isAfter(existingStart)) {
          throw Exception(
            'Selected dates or hours overlap with an existing or pending booking.',
          );
        }
      }

      final bookingPayload = <String, dynamic>{
        'renter_id': renterId,
        'vehicle_id': vehicleId,
        'start_at': startAt.toIso8601String(),
        'end_at': endAt.toIso8601String(),
        // Keep legacy fields for existing screens/queries (date-only intent).
        'start_date': DateTime(
          startAt.toLocal().year,
          startAt.toLocal().month,
          startAt.toLocal().day,
        ).toIso8601String(),
        'end_date': DateTime(
          endAt.toLocal().year,
          endAt.toLocal().month,
          endAt.toLocal().day,
        ).toIso8601String(),
        'total_price': totalPrice,
        'rental_subtotal': rentalSubtotal ?? totalPrice,
        if (discountAmount != null && discountAmount > 0)
          'discount_amount': discountAmount,
        if (appliedVoucher != null && appliedVoucher.isNotEmpty)
          'applied_voucher': appliedVoucher,
        if (deliveryDistanceKm != null)
          'delivery_distance_km': deliveryDistanceKm,
        if (deliveryRatePerKm != null)
          'delivery_rate_per_km': deliveryRatePerKm,
        'delivery_fee': deliveryFee ?? 0,
        'with_driver': withDriver,
        if (driverFee != null && driverFee > 0) 'driver_fee': driverFee,
        'pickup_location': pickupLocation,
        'dropoff_location': cleanDestination,
        if (pickupLatitude != null) 'pickup_latitude': pickupLatitude,
        if (pickupLongitude != null) 'pickup_longitude': pickupLongitude,
        if (dropoffLatitude != null) 'dropoff_latitude': dropoffLatitude,
        if (dropoffLongitude != null) 'dropoff_longitude': dropoffLongitude,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      if (securityDeposit != null) {
        bookingPayload['security_deposit'] = securityDeposit;
      }

      if (reservationFeeAmount != null) {
        bookingPayload['reservation_fee_amount'] = reservationFeeAmount;
      }

      final cleanPaymentType = reservationPaymentType?.trim().toLowerCase();
      if (cleanPaymentType != null && cleanPaymentType.isNotEmpty) {
        bookingPayload['reservation_payment_type'] = cleanPaymentType;
        bookingPayload['reservation_payment_covers_total'] =
            cleanPaymentType == 'full_payment';
      }

      if (reservationPaymentReference != null &&
          reservationPaymentReference.trim().isNotEmpty) {
        bookingPayload['reservation_payment_reference'] =
            reservationPaymentReference.trim();
        bookingPayload['reservation_payment_status'] = 'pending_review';
        bookingPayload['reservation_payment_submitted_at'] = DateTime.now()
            .toIso8601String();
      }

      if (reservationPaymentProofUrl != null &&
          reservationPaymentProofUrl.trim().isNotEmpty) {
        bookingPayload['reservation_payment_proof_url'] =
            reservationPaymentProofUrl.trim();
      }

      if (reservationPaymentMethod != null &&
          reservationPaymentMethod.trim().isNotEmpty) {
        bookingPayload['reservation_payment_method'] = reservationPaymentMethod
            .trim();
      }

      if (reservationPaymentSenderPhone != null &&
          reservationPaymentSenderPhone.trim().isNotEmpty) {
        final cleanSenderPhone = reservationPaymentSenderPhone.trim();
        bookingPayload['reservation_payment_sender_phone'] = cleanSenderPhone;
      }

      if (rentalTermsAcceptedAt != null) {
        bookingPayload['rental_terms_accepted_at'] = rentalTermsAcceptedAt
            .toIso8601String();
      }

      if (rentalTermsSnapshot != null) {
        bookingPayload['rental_terms_snapshot'] = rentalTermsSnapshot;
      }

      if (emergencyContactName != null &&
          emergencyContactName.trim().isNotEmpty) {
        bookingPayload['emergency_contact_name'] = emergencyContactName.trim();
      }

      if (emergencyContactPhone != null &&
          emergencyContactPhone.trim().isNotEmpty) {
        bookingPayload['emergency_contact_phone'] = emergencyContactPhone
            .trim();
      }

      if (emergencyContactRelationship != null &&
          emergencyContactRelationship.trim().isNotEmpty) {
        bookingPayload['emergency_contact_relationship'] =
            emergencyContactRelationship.trim();
      }

      if (renterSignatureText != null &&
          renterSignatureText.trim().isNotEmpty) {
        bookingPayload['renter_signature_text'] = renterSignatureText.trim();
      }

      bookingPayload['renter_signature_url'] = renterSignatureUrl.trim();

      bookingPayload['renter_valid_id_url'] = renterValidIdUrl.trim();

      bookingPayload['renter_selfie_url'] = renterSelfieUrl.trim();

      if (coTravelerName != null && coTravelerName.trim().isNotEmpty) {
        bookingPayload['co_traveler_name'] = coTravelerName.trim();
      }

      if (coTravelerPhone != null && coTravelerPhone.trim().isNotEmpty) {
        bookingPayload['co_traveler_phone'] = coTravelerPhone.trim();
      }

      if (coTravelerLicense != null && coTravelerLicense.trim().isNotEmpty) {
        bookingPayload['co_traveler_license'] = coTravelerLicense.trim();
      }

      if (coTravelerSignatureText != null &&
          coTravelerSignatureText.trim().isNotEmpty) {
        bookingPayload['co_traveler_signature_text'] = coTravelerSignatureText
            .trim();
      }

      bookingPayload['co_traveler_signature_url'] = coTravelerSignatureUrl
          .trim();
      bookingPayload['co_traveler_valid_id_url'] = coTravelerValidIdUrl.trim();
      bookingPayload['co_traveler_selfie_url'] = coTravelerSelfieUrl.trim();

      Map<String, dynamic> response;
      var currentPayload = Map<String, dynamic>.from(bookingPayload);
      int retryCount = 0;

      while (true) {
        try {
          response = await supabase
              .from('bookings')
              .insert(currentPayload)
              .select()
              .single();
          break;
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST204' ||
              e.message.toLowerCase().contains('column') ||
              e.message.toLowerCase().contains('schema cache')) {
            retryCount++;
            if (retryCount > 8) {
              rethrow;
            }

            debugPrint(
              'Schema column mismatch when inserting booking ($e). Dynamically stripping missing column and retrying...',
            );

            // Extract the missing column name from the error message
            final match = RegExp(r"'(?:public\.)?(?:bookings\.)?([a-zA-Z0-9_]+)'\s*column|column\s*'(?:public\.)?(?:bookings\.)?([a-zA-Z0-9_]+)'|find the '([a-zA-Z0-9_]+)' column", caseSensitive: false).firstMatch(e.message);
            final missingCol = match?.group(1) ?? match?.group(2) ?? match?.group(3);

            if (missingCol != null && currentPayload.containsKey(missingCol)) {
              final val = currentPayload.remove(missingCol);
              debugPrint('Stripped missing column: $missingCol (value: $val)');
              if (val != null && val.toString().isNotEmpty) {
                final note = '[$missingCol: $val]';
                final existingNotes = currentPayload['operator_notes']?.toString() ?? '';
                currentPayload['operator_notes'] = existingNotes.isNotEmpty
                    ? '$existingNotes | $note'
                    : note;
              }
            } else {
              // Fallback stripping of newer optional columns
              final optionalCols = [
                'reservation_payment_sender_phone',
                'reservation_payment_type',
                'reservation_payment_covers_total',
                'reservation_payment_reference',
                'reservation_payment_proof_url',
                'reservation_payment_method',
                'reservation_payment_status',
                'reservation_payment_submitted_at',
                'applied_voucher',
                'discount_amount',
                'rental_terms_snapshot',
                'refund_phone',
              ];
              bool removedAny = false;
              for (final col in optionalCols) {
                if (currentPayload.containsKey(col)) {
                  currentPayload.remove(col);
                  removedAny = true;
                  break;
                }
              }
              if (!removedAny) {
                rethrow;
              }
            }
          } else if (e.message.toLowerCase().contains('unavailable')) {
            throw Exception('Selected dates are unavailable for bookings');
          } else {
            rethrow;
          }
        }
      }

      final bookingId = response['id']?.toString();
      if (bookingId != null && bookingId.isNotEmpty) {
        unawaited(
          Future<void>(() async {
            final createdBooking = await getBookingById(bookingId) ?? response;
            final vehicle = createdBooking['vehicles'] as Map<String, dynamic>?;
            final vehicleTitle = _vehicleTitle(vehicle);
            final renter = createdBooking['users'] as Map<String, dynamic>?;
            final renterName =
                renter?['full_name']?.toString().trim().isNotEmpty == true
                ? renter!['full_name'].toString().trim()
                : 'A renter';
            await NotificationService().notifyOperatorsNewBooking(
              bookingId: bookingId,
              vehicleTitle: vehicleTitle,
              renterName: renterName,
              withDriver: withDriver,
            );
          }).timeout(const Duration(seconds: 8)).catchError((e) {
            debugPrint(
              'Booking created but operator notification timed out/failed: $e',
            );
          }),
        );
      }

      debugPrint('Booking created successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating booking: ${e.message}');
      if (e.message.toLowerCase().contains('unavailable')) {
        throw Exception('Selected dates are unavailable for bookings');
      }
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error creating booking: $e');
      rethrow;
    }
  }

  // Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      debugPrint('Updating booking $bookingId status to: $status');
      final normalizedStatus = status.trim().toLowerCase();

      // Get booking details before updating
      final booking = await getBookingById(bookingId);
      if (booking == null) {
        throw Exception('Booking not found: $bookingId');
      }

      if (normalizedStatus == 'cancelled') {
        final currentStatus =
            booking['status']?.toString().trim().toLowerCase() ?? '';
        const cancellableStatuses = {'pending', 'approved', 'confirmed'};
        if (!cancellableStatuses.contains(currentStatus)) {
          throw Exception(
            'Only pending, approved, or confirmed bookings can be cancelled before the trip starts',
          );
        }

        final createdAtStr = booking['created_at']?.toString();
        final createdAt = createdAtStr == null
            ? null
            : DateTime.tryParse(createdAtStr);
        if (createdAt == null) {
          throw Exception('Booking cancellation window could not be verified');
        }

        if (DateTime.now().isAfter(createdAt.add(const Duration(hours: 24)))) {
          throw Exception(
            'Cancellation window has passed. Bookings can only be cancelled within 24 hours after request.',
          );
        }
      }

      await supabase
          .from('bookings')
          .update({
            'status': normalizedStatus,
            if (normalizedStatus == 'cancelled')
              'refund_status': 'refund_needed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      debugPrint('Booking status updated');

      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final vehicleTitle = vehicle != null
          ? '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
          : 'Your rental vehicle';

      // ✅ Send notifications based on status change
      if (normalizedStatus == 'approved') {
        // Notify renter of approval
        final renterId = booking['renter_id']?.toString();
        if (renterId != null && renterId.isNotEmpty) {
          await NotificationService().notifyBookingApproved(
            renterId: renterId,
            bookingId: bookingId,
            vehicleTitle: vehicleTitle,
          );
        }
      } else if (normalizedStatus == 'rejected') {
        // Notify renter of rejection
        if (booking['renter_id'] != null) {
          try {
            await supabase.from('notifications').insert({
              'user_id': booking['renter_id'],
              'title': '❌ Booking Rejected',
              'message': 'Your booking for $vehicleTitle has been rejected.',
              'type': 'booking',
              'data': {'booking_id': bookingId, 'status': normalizedStatus},
              'created_at': DateTime.now().toIso8601String(),
            });
            debugPrint('✅ Rejection notification sent to renter');
          } catch (e) {
            debugPrint('⚠️ Error sending rejection notification: $e');
          }
        }
      } else if (normalizedStatus == 'cancelled') {
        final reservationReference = booking['reservation_payment_reference']
            ?.toString()
            .trim();
        final hasReservationPayment =
            reservationReference != null && reservationReference.isNotEmpty;

        if (hasReservationPayment) {
          try {
            final operators = await supabase
                .from('users')
                .select('id')
                .eq('role', 'operator');

            final notifications = List<Map<String, dynamic>>.from(operators)
                .map(
                  (operator) => {
                    'user_id': operator['id'],
                    'title': 'Refund Needed for Cancelled Booking',
                    'message':
                        '$vehicleTitle was cancelled after reservation payment. Reference: $reservationReference. Please review refund processing.',
                    'type': 'booking_refund',
                    'data': {
                      'booking_id': bookingId,
                      'status': normalizedStatus,
                      'reservation_payment_reference': reservationReference,
                      'refund_status': 'refund_needed',
                    },
                    'created_at': DateTime.now().toIso8601String(),
                  },
                )
                .toList();

            if (notifications.isNotEmpty) {
              await supabase.from('notifications').insert(notifications);
            }
          } catch (e) {
            debugPrint('Error notifying operators for refund: $e');
          }
        }
        // 🔴 Notify operator/owner when renter cancels (within 24 hours)
        if (vehicle?['owner_id'] != null) {
          try {
            final renter = booking['users'] as Map<String, dynamic>?;
            final renterName = renter?['full_name'] ?? 'Renter';

            await supabase.from('notifications').insert({
              'user_id': vehicle?['owner_id'],
              'title': '🔴 Booking Cancelled by Renter',
              'message':
                  '$renterName has cancelled their booking for $vehicleTitle.',
              'type': 'booking',
              'data': {
                'booking_id': bookingId,
                'status': normalizedStatus,
                'cancelled_by': 'renter',
              },
              'created_at': DateTime.now().toIso8601String(),
            });

            debugPrint('✅ Cancellation notification sent to operator');
          } catch (e) {
            debugPrint(
              '⚠️ Error sending cancellation notification to operator: $e',
            );
          }
        }
      }

      const conversationStatuses = {
        'approved',
        'confirmed',
        'active',
        'ongoing',
      };
      const terminalStatuses = {
        'completed',
        'successful',
        'cancelled',
        'canceled',
        'rejected',
      };

      if (conversationStatuses.contains(normalizedStatus)) {
        try {
          final updatedBooking = await getBookingById(bookingId) ?? booking;
          await _ensureBookingGroupChatAndSummary(
            booking: updatedBooking,
            vehicleTitle: vehicleTitle,
            summaryTitle: 'Booking Confirmed',
          );
        } catch (e) {
          debugPrint('Error creating booking group chat summary: $e');
        }
      } else if (terminalStatuses.contains(normalizedStatus)) {
        try {
          await ChatService().closeConversation(bookingId);
        } catch (e) {
          debugPrint('Error closing booking group chat: $e');
        }
      }
    } on PostgrestException catch (e) {
      debugPrint('Database error updating booking status: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating booking status: $e');
      rethrow;
    }
  }

  Map<String, dynamic> getTripCompletionState(Map<String, dynamic> booking) {
    final vehicleValue = booking['vehicles'] ?? booking['vehicle'];
    final vehicle = vehicleValue is Map<String, dynamic>
        ? Map<String, dynamic>.from(vehicleValue)
        : <String, dynamic>{};
    final owner = vehicle['owner'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(vehicle['owner'])
        : <String, dynamic>{};
    final rawStatus =
        (booking['rawStatus']?.toString() ??
                booking['status']?.toString() ??
                '')
            .toLowerCase();
    final hasDriver =
        booking['with_driver'] == true ||
        booking['withDriver'] == true ||
        (booking['driver_id']?.toString().trim().isNotEmpty == true) ||
        booking['driver'] != null;
    final ownerRole = (vehicle['owner_role'] ?? owner['role'])
        ?.toString()
        .trim()
        .toLowerCase();
    final ownerId = (vehicle['owner_id'] ?? owner['id'])?.toString().trim();
    final operatorId =
        booking['operator_id']?.toString().trim().isNotEmpty == true
        ? booking['operator_id']?.toString().trim()
        : vehicle['operator_id']?.toString().trim();
    final requiresPartner =
        ownerRole == 'partner' ||
        (ownerId != null &&
            ownerId.isNotEmpty &&
            operatorId != null &&
            operatorId.isNotEmpty &&
            ownerId != operatorId);

    final operatorConfirmed = _hasTripConfirmation(
      booking['operator_trip_confirmed_at'],
    );
    final partnerConfirmed = _hasTripConfirmation(
      booking['partner_trip_confirmed_at'],
    );
    final driverConfirmed = _hasTripConfirmation(
      booking['driver_trip_confirmed_at'],
    );
    final renterConfirmed = _hasTripConfirmation(
      booking['renter_trip_confirmed_at'],
    );

    final completionStage =
        booking['completion_stage']?.toString().trim().toLowerCase() ??
        'not_started';
    final finalPaymentStatus =
        booking['final_payment_status']?.toString().trim().toLowerCase() ??
        'pending';
    final firstReviewerRole = requiresPartner ? 'partner' : 'operator';
    final pendingRoles = <String>[
      if (requiresPartner && !partnerConfirmed) 'partner',
      if (!requiresPartner && !operatorConfirmed) 'operator',
      if (hasDriver && !driverConfirmed) 'driver',
      if (!renterConfirmed) 'renter',
    ];

    return {
      'status': rawStatus,
      'completionStage': completionStage,
      'finalPaymentStatus': finalPaymentStatus,
      'isFullyPaid': finalPaymentStatus == 'paid',
      'firstReviewerRole': firstReviewerRole,
      'hasDriver': hasDriver,
      'requiresPartner': requiresPartner,
      'operatorConfirmed': operatorConfirmed,
      'partnerConfirmed': partnerConfirmed,
      'driverConfirmed': driverConfirmed,
      'renterConfirmed': renterConfirmed,
      'pendingRoles': pendingRoles,
      'allNonRenterConfirmed':
          (requiresPartner ? partnerConfirmed : operatorConfirmed) &&
          (!hasDriver || driverConfirmed),
      'renterCanConfirm':
          completionStage == 'renter_rating' && !renterConfirmed,
      'canConfirmPayment': completionStage == 'awaiting_payment',
      'canRate': <String, bool>{
        'operator':
            completionStage == 'operator_rating' ||
            (operatorConfirmed == false &&
                (rawStatus == 'completed' ||
                    rawStatus == 'returned' ||
                    rawStatus == 'ongoing')),
        'partner':
            completionStage == 'partner_rating' ||
            (partnerConfirmed == false &&
                (rawStatus == 'completed' || rawStatus == 'returned')),
        'driver':
            completionStage == 'driver_rating' ||
            (driverConfirmed == false &&
                (rawStatus == 'completed' || rawStatus == 'returned')),
        'renter':
            completionStage == 'renter_rating' ||
            (renterConfirmed == false &&
                (rawStatus == 'completed' ||
                    rawStatus == 'returned' ||
                    rawStatus == 'ongoing')),
      },
    };
  }

  /// Confirms that the final rental balance and late-return charges have been
  /// settled. The responsible operator handles PSDC vehicles, while the
  /// vehicle owner handles partner vehicles.
  Future<Map<String, dynamic>> confirmFinalPayment({
    required String bookingId,
    required String actorId,
    required String actorRole,
  }) async {
    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    final state = getTripCompletionState(booking);
    final finalPaymentStatus = (booking['final_payment_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (finalPaymentStatus == 'paid' || state['isFullyPaid'] == true) {
      return booking;
    }

    final expectedRole = state['firstReviewerRole']?.toString() ?? 'operator';
    final normalizedRole = actorRole.trim().toLowerCase();
    if (normalizedRole != expectedRole &&
        normalizedRole != 'operator' &&
        normalizedRole != 'admin') {
      throw Exception(
        expectedRole == 'partner'
            ? 'Only the vehicle partner can confirm this final payment'
            : 'Only the PSDC operator can confirm this final payment',
      );
    }
    final stage = state['completionStage']?.toString().toLowerCase() ?? '';
    final status = (booking['status'] ?? '').toString().toLowerCase();
    final hasAfterInspection = await _hasAfterInspection(bookingId);

    const validPaymentStages = {
      'awaiting_payment',
      'operator_rating',
      'partner_rating',
      'driver_rating',
      'renter_rating',
      'awaiting_completion',
      'completed',
    };

    if (!validPaymentStages.contains(stage) &&
        !hasAfterInspection &&
        status != 'completed' &&
        status != 'returned') {
      throw Exception('The vehicle return checklist is not ready for payment');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    final updateData = <String, dynamic>{
      'final_payment_status': 'paid',
      'final_payment_confirmed_at': now,
      'final_payment_confirmed_by': actorId,
      'updated_at': now,
    };

    if (hasAfterInspection ||
        booking['returned_at'] != null ||
        status == 'completed') {
      updateData['status'] = 'completed';
      updateData['completed_at'] = now;
    }

    await supabase.from('bookings').update(updateData).eq('id', bookingId);

    try {
      await TripRatingService().syncRatingFlowForBooking(
        bookingId,
        operatorFallbackUserId: actorId,
      );
    } catch (e) {
      debugPrint('Could not sync rating flow after final payment: $e');
    }

    final vehicle = booking['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    String? reviewerId;
    if (expectedRole == 'partner') {
      reviewerId = vehicle['owner_id']?.toString();
    } else {
      reviewerId = booking['operator_id']?.toString().trim();
      if (reviewerId == null || reviewerId.isEmpty) reviewerId = actorId;
    }
    if (reviewerId?.isNotEmpty == true) {
      await NotificationService().createNotification(
        userId: reviewerId!,
        title: 'Rate The Renter',
        message:
            'The final balance is fully paid. Submit the mandatory renter rating to continue completion.',
        type: 'trip_rating_required',
        data: {'booking_id': bookingId, 'reviewer_role': expectedRole},
      );
    }
    return await getBookingById(bookingId) ?? booking;
  }

  Future<bool> _hasAfterInspection(String bookingId) async {
    try {
      final response = await supabase
          .from('booking_vehicle_inspections')
          .select('id')
          .eq('booking_id', bookingId)
          .eq('inspection_type', 'after')
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> confirmSuccessfulTrip({
    required String bookingId,
    required String actorRole,
  }) async {
    final normalizedRole = actorRole.trim().toLowerCase();
    if (_tripConfirmationColumnForRole(normalizedRole) == null) {
      throw Exception('Unsupported trip confirmation role: $actorRole');
    }

    final booking = await getBookingById(bookingId);
    if (booking == null) {
      throw Exception('Booking not found');
    }

    final completionState = getTripCompletionState(booking);
    final canRate = completionState['canRate'] as Map<String, bool>?;
    if (canRate?[normalizedRole] != true) {
      throw Exception(
        'This confirmation is not available yet. Complete payment and the required ratings in order.',
      );
    }
    throw Exception(
      'A mandatory star rating is required. Open the Rate Trip screen to continue.',
    );
  }

  // Get booking counts by status for partner
  Future<Map<String, int>> getPartnerBookingCounts(String partnerId) async {
    try {
      debugPrint('Fetching booking counts for partner: $partnerId');

      final bookings = await getPartnerBookings(partnerId);

      final counts = {
        'pending': 0,
        'approved': 0,
        'confirmed': 0,
        'active': 0,
        'completed': 0,
        'rejected': 0,
        'cancelled': 0,
        'total': bookings.length,
      };

      for (final booking in bookings) {
        final status = booking['status'] as String?;
        if (status != null && counts.containsKey(status)) {
          counts[status] = counts[status]! + 1;
        }
      }

      debugPrint('Booking counts: $counts');
      return counts;
    } catch (e) {
      debugPrint('Error getting booking counts: $e');
      return {
        'pending': 0,
        'approved': 0,
        'confirmed': 0,
        'active': 0,
        'completed': 0,
        'rejected': 0,
        'cancelled': 0,
        'total': 0,
      };
    }
  }

  // Get recent bookings for partner (limit)
  Future<List<Map<String, dynamic>>> getRecentPartnerBookings(
    String userId, {
    int limit = 5,
  }) async {
    try {
      await processExpiredPendingBookings();
      debugPrint('Fetching recent bookings for owner: $userId');

      final vehicles = await supabase
          .from('vehicles')
          .select('id')
          .eq('owner_id', userId);

      if (vehicles.isEmpty) {
        return [];
      }

      final vehicleIds = vehicles.map((v) => v['id'] as String).toList();

      final response = await supabase
          .from('bookings')
          .select(
            '*, vehicles(*), users:users!bookings_renter_id_fkey(*), '
            'driver:drivers!bookings_driver_id_fkey(id, user_id, '
            '  users!drivers_user_id_fkey(id, full_name, email, phone)), '
            'job_assignments:driver_job_assignments!driver_job_assignments_booking_id_fkey('
            '  id, driver_id, status, trip_fee, offered_at, replied_at, created_at, updated_at)',
          )
          .inFilter('vehicle_id', vehicleIds)
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('Fetched ${response.length} recent bookings');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching recent bookings: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching recent bookings: $e');
      rethrow;
    }
  }

  // ================== PARTNER BOOKING CONFIRMATION ==================

  /// Partner confirms that they agree to host the renter for the upcoming
  /// booking. Required before the operator can officially approve.
  Future<void> confirmPartnerBooking({
    required String bookingId,
    required String partnerId,
  }) async {
    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    final vehicle = booking['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    final ownerId = vehicle['owner_id']?.toString();
    if (ownerId == null || ownerId.isEmpty || ownerId != partnerId) {
      throw Exception('Only the vehicle owner can confirm this booking');
    }

    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    if (status != 'pending') {
      throw Exception(
        'This booking cannot be confirmed in its current state ($status)',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('bookings')
        .update({
          'partner_booking_confirmed_at': now,
          'partner_booking_confirmed_by': partnerId,
          'updated_at': now,
        })
        .eq('id', bookingId);

    // Notify operators that partner has confirmed.
    await _notifyOperatorsForBooking(
      booking,
      title: 'Partner Confirmed Booking',
      message:
          'The vehicle partner confirmed availability. You can now approve the booking.',
      action: 'partner_booking_confirmed',
    );

    // Notify renter.
    final renterId = booking['renter_id']?.toString();
    if (renterId != null && renterId.isNotEmpty) {
      final vehicleTitle = _vehicleTitle(vehicle);
      await NotificationService().createNotification(
        userId: renterId,
        title: 'Partner Confirmed Your Booking',
        message:
            'The vehicle owner confirmed availability for $vehicleTitle. Awaiting final operator approval.',
        type: 'booking',
        data: {'booking_id': bookingId, 'event': 'partner_confirmed'},
      );
    }
  }

  /// Partner rejects the booking for their vehicle before operator approval.
  Future<void> rejectPartnerBooking({
    required String bookingId,
    required String partnerId,
    required String reason,
  }) async {
    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    final vehicle = booking['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    final ownerId = vehicle['owner_id']?.toString();
    if (ownerId == null || ownerId.isEmpty || ownerId != partnerId) {
      throw Exception('Only the vehicle owner can reject this booking');
    }

    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    if (!{'pending', 'approved'}.contains(status)) {
      throw Exception(
        'This booking cannot be rejected in its current state ($status)',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('bookings')
        .update({
          'status': 'rejected',
          'partner_booking_rejected_at': now,
          'partner_booking_rejection_reason': reason,
          'rejection_reason': reason,
          'rejected_at': now,
          'updated_at': now,
        })
        .eq('id', bookingId);

    final renterId = booking['renter_id']?.toString();
    if (renterId != null && renterId.isNotEmpty) {
      final vehicleTitle = _vehicleTitle(vehicle);
      await NotificationService().createNotification(
        userId: renterId,
        title: 'Booking Rejected',
        message:
            'Your booking for $vehicleTitle was rejected by the vehicle partner. Reason: $reason',
        type: 'booking',
        data: {'booking_id': bookingId, 'status': 'rejected'},
      );
    }
  }

  // ================== OPERATOR WORKFLOW ==================

  /// Get all pending bookings for operator approval
  Future<List<Map<String, dynamic>>> getPendingBookings() async {
    try {
      await processExpiredPendingBookings();
      debugPrint('Fetching pending bookings');
      final response = await supabase
          .from('bookings')
          .select(
            'id, renter_id, vehicle_id, start_at, end_at, start_date, end_date, status, total_price, created_at, '
            'reservation_fee_amount, reservation_payment_type, reservation_payment_covers_total, '
            'reservation_payment_reference, reservation_payment_status, reservation_payment_submitted_at, '
            'reservation_payment_proof_url, reservation_payment_method, rental_terms_accepted_at, '
            'vehicles(brand, model, year, plate_number, owner_id), '
            'users:users!bookings_renter_id_fkey(full_name, email, phone)',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching pending bookings: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching pending bookings: $e');
      return [];
    }
  }

  /// All bookings managed or monitored by operators (including partner vehicles) — every status.
  Future<List<Map<String, dynamic>>> getOperatorBookings(
    String operatorId,
  ) async {
    try {
      await processExpiredPendingBookings();
      final response = await supabase
          .from('bookings')
          .select(
            '*, '
            'vehicles(id, brand, model, year, plate_number, owner_id, owner_role, operator_id, is_partner_vehicle, latitude, longitude, '
            '  owner:owner_id(id, full_name, role, latitude, longitude), vehicle_images(image_url, display_order)), '
            'users:users!bookings_renter_id_fkey(id, full_name, email, phone, avatar_url, latitude, longitude), '
            'driver:drivers!bookings_driver_id_fkey(id, user_id, '
            '  users!drivers_user_id_fkey(id, full_name, email, phone)), '
            'job_assignments:driver_job_assignments!driver_job_assignments_booking_id_fkey('
            '  id, driver_id, status, trip_fee, offered_at, replied_at, created_at, updated_at)',
          )
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching operator bookings: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching operator bookings: $e');
      return [];
    }
  }

  /// Approved/ongoing/active bookings for the operator's live dashboard (including partner units).
  Future<List<Map<String, dynamic>>> getOperatorActiveBookings(
    String operatorId,
  ) async {
    try {
      final response = await supabase
          .from('bookings')
          .select(
            '*, '
            'vehicles(id, brand, model, year, plate_number, owner_id, owner_role, operator_id, is_partner_vehicle, latitude, longitude, '
            '  owner:owner_id(id, full_name, role, latitude, longitude), vehicle_images(image_url, display_order)), '
            'users:users!bookings_renter_id_fkey(id, full_name, email, phone, avatar_url, latitude, longitude), '
            'driver:drivers!bookings_driver_id_fkey(id, user_id, '
            '  users!drivers_user_id_fkey(id, full_name, email, phone)), '
            'job_assignments:driver_job_assignments!driver_job_assignments_booking_id_fkey('
            '  id, driver_id, status, trip_fee, offered_at, replied_at, created_at, updated_at)',
          )
          .inFilter('status', [
            'approved',
            'confirmed',
            'active',
            'ongoing',
            'return_pending_inspection',
            'awaiting_completion',
          ])
          .order('start_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error fetching operator active bookings: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint('Error fetching operator active bookings: $e');
      return [];
    }
  }

  /// Pending bookings that operators monitor (PSDC and partner units).
  Future<List<Map<String, dynamic>>> getOperatorPendingApproval(
    String operatorId,
  ) async {
    try {
      await processExpiredPendingBookings();
      final response = await supabase
          .from('bookings')
          .select(
            'id, renter_id, vehicle_id, start_at, end_at, start_date, end_date, '
            'status, total_price, with_driver, driver_id, driver_assigned_at, created_at, '
            'pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, '
            'partner_booking_confirmed_at, reservation_payment_status, '
            'reservation_payment_covers_total, reservation_fee_amount, '
            'vehicles(id, brand, model, year, plate_number, owner_id, owner_role, operator_id, is_partner_vehicle, latitude, longitude, '
            '  owner:owner_id(id, full_name, role, latitude, longitude)), '
            'users:users!bookings_renter_id_fkey(id, full_name, email, phone, latitude, longitude), '
            'driver:drivers!bookings_driver_id_fkey(id, user_id, '
            '  users!drivers_user_id_fkey(id, full_name, email, phone)), '
            'job_assignments:driver_job_assignments!driver_job_assignments_booking_id_fkey('
            '  id, driver_id, status, trip_fee, offered_at, replied_at, created_at, updated_at)',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error fetching operator pending bookings: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint('Error fetching operator pending bookings: $e');
      return [];
    }
  }

  /// Approve booking (operator action)
  Future<void> approveBooking(String bookingId, String operatorNotes) async {
    try {
      debugPrint('Approving booking: $bookingId');
      final operatorId = supabase.auth.currentUser?.id;
      if (operatorId == null || operatorId.isEmpty) {
        throw Exception('Operator is not authenticated');
      }

      // Keep every approval entry point behind finalizeBooking so a
      // driver-required reservation cannot bypass assignment/acceptance.
      await supabase
          .from('bookings')
          .update({
            'operator_notes': operatorNotes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);
      await finalizeBooking(bookingId: bookingId, operatorId: operatorId);

      debugPrint('Booking approved');
    } on PostgrestException catch (e) {
      debugPrint('Database error approving booking: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error approving booking: $e');
      rethrow;
    }
  }

  /// Reject booking (operator action)
  Future<void> rejectBooking(String bookingId, String reason) async {
    try {
      debugPrint('Rejecting booking: $bookingId');

      // Get booking details before updating
      final booking = await getBookingById(bookingId);
      if (booking == null) {
        throw Exception('Booking not found: $bookingId');
      }

      await supabase
          .from('bookings')
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'rejected_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final assignedDriverId = booking['driver_id']?.toString();
      if (assignedDriverId != null && assignedDriverId.isNotEmpty) {
        final now = DateTime.now().toIso8601String();
        await supabase
            .from('driver_job_assignments')
            .update({'status': 'cancelled', 'updated_at': now})
            .eq('booking_id', bookingId)
            .inFilter('status', ['pending_offer', 'assigned', 'accepted']);
        await supabase
            .from('users')
            .update({'is_available': true})
            .eq('id', assignedDriverId);
      }

      debugPrint('Booking rejected');

      // ✅ Send notification to renter when booking is rejected
      if (booking['renter_id'] != null) {
        try {
          final vehicle = booking['vehicles'] as Map<String, dynamic>?;
          final vehicleTitle = vehicle != null
              ? '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
              : 'Your rental vehicle';

          await supabase.from('notifications').insert({
            'user_id': booking['renter_id'],
            'title': '❌ Booking Rejected',
            'message':
                'Your booking for $vehicleTitle has been rejected. Reason: $reason',
            'type': 'booking',
            'data': {'booking_id': bookingId, 'status': 'rejected'},
            'created_at': DateTime.now().toIso8601String(),
          });

          debugPrint('✅ Rejection notification sent to renter');
        } catch (e) {
          debugPrint('⚠️ Error sending rejection notification: $e');
        }
      }
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting booking: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error rejecting booking: $e');
      rethrow;
    }
  }

  /// Assign driver to booking (operator action)
  Future<void> assignDriver(
    String bookingId,
    String driverId,
    double tripFee, {
    String? operatorId,
  }) async {
    try {
      debugPrint(
        'Assigning driver $driverId to booking $bookingId with fee: $tripFee',
      );

      final booking = await supabase
          .from('bookings')
          .select('id, with_driver, status, renter_id, operator_id')
          .eq('id', bookingId)
          .maybeSingle();

      if (booking == null) {
        throw Exception('Booking not found');
      }

      final driver = await _getDriverAssignmentTarget(driverId);
      if (driver == null) {
        throw Exception('Selected user is not a valid driver');
      }

      final driverUserId = driver['user_id']?.toString();
      if (driverUserId == null || driverUserId.isEmpty) {
        throw Exception('Selected driver is missing profile linkage');
      }

      final currentStatus =
          booking['status']?.toString().trim().toLowerCase() ?? '';

      if (!{
        'pending',
        'pending_approval',
        'awaiting_driver',
        'approved',
        'confirmed',
        'assigned',
        'active',
        'ongoing',
      }.contains(currentStatus)) {
        throw Exception(
          'A driver can only be assigned to pending, approved, confirmed, or active bookings',
        );
      }

      final effectiveOperatorId =
          operatorId ??
          booking['operator_id']?.toString() ??
          supabase.auth.currentUser?.id;

      final now = DateTime.now().toIso8601String();
      await supabase
          .from('driver_job_assignments')
          .update({'status': 'superseded', 'updated_at': now})
          .eq('booking_id', bookingId)
          .inFilter('status', ['pending_offer', 'assigned']);

      final assignment = await supabase
          .from('driver_job_assignments')
          .insert({
            'booking_id': bookingId,
            'driver_id': driverUserId,
            'trip_fee': tripFee,
            'status': 'pending_offer',
            'offered_at': now,
            'created_at': now,
            'updated_at': now,
          })
          .select('id')
          .single();
      final assignmentId = assignment['id']?.toString();

      try {
        final updateData = <String, dynamic>{
          'driver_id': driverUserId,
          'with_driver': true,
          'status': 'pending',
          'driver_assigned_at': now,
          'updated_at': now,
        };
        if (effectiveOperatorId != null && effectiveOperatorId.isNotEmpty) {
          updateData['operator_id'] = effectiveOperatorId;
        }

        await supabase
            .from('bookings')
            .update(updateData)
            .eq('id', bookingId);
      } catch (_) {
        if (assignmentId != null && assignmentId.isNotEmpty) {
          await supabase
              .from('driver_job_assignments')
              .update({'status': 'cancelled', 'updated_at': now})
              .eq('id', assignmentId);
        }
        rethrow;
      }

      await supabase
          .from('users')
          .update({'is_available': false})
          .eq('id', driverUserId);

      debugPrint('Driver job offer created for booking');

      // ✅ Send notification to renter about driver assignment
      try {
        final driverName = driver['full_name'] ?? 'Driver';
        final renterId = booking['renter_id']?.toString();
        if (renterId != null && renterId.isNotEmpty) {
          await NotificationService().createNotification(
            userId: renterId,
            title: 'Driver Selection in Progress',
            message:
                '$driverName was selected and is reviewing the job offer. Your booking is not finalized yet.',
            type: 'booking',
            data: {
              'booking_id': bookingId,
              'driver_id': driverUserId,
              'event': 'driver_offer_sent',
            },
          );
        }

        debugPrint('✅ Driver assignment notification sent to renter');
      } catch (e) {
        debugPrint('⚠️ Error sending driver assignment notification: $e');
      }

      // ✅ Notify the assigned driver with booking + renter details
      try {
        final bookingDetails = await getBookingById(bookingId);
        final renter = bookingDetails?['users'] as Map<String, dynamic>?;
        final renterName = renter?['full_name']?.toString() ?? 'Renter';
        final renterPhone = renter?['phone']?.toString() ?? '';
        await NotificationService().notifyDriverJobAssigned(
          driverId: driverUserId,
          bookingId: bookingId,
          renterId: booking['renter_id']?.toString(),
          renterName: renterName,
          renterPhone: renterPhone,
          pickupLocation: bookingDetails?['pickup_location']?.toString(),
          dropoffLocation: bookingDetails?['dropoff_location']?.toString(),
          startDate: bookingDetails?['start_date']?.toString(),
          endDate: bookingDetails?['end_date']?.toString(),
          startAt: bookingDetails?['start_at']?.toString(),
          endAt: bookingDetails?['end_at']?.toString(),
          tripFee: tripFee,
        );
        debugPrint('✅ Driver assignment notification sent to driver');
      } catch (e) {
        debugPrint('⚠️ Error sending driver notification: $e');
      }
    } on PostgrestException catch (e) {
      debugPrint('Database error assigning driver: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error assigning driver: $e');
      rethrow;
    }
  }

  /// Finalize a booking after the selected driver accepts the job offer.
  Future<Map<String, dynamic>> finalizeBooking({
    required String bookingId,
    required String operatorId,
  }) async {
    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    final currentStatus =
        booking['status']?.toString().trim().toLowerCase() ?? '';
    if (!{
      'pending',
      'pending_approval',
      'driver_accepted',
      'pending_driver_confirmation',
      'driver_assigned',
      'awaiting_driver',
      'approved',
      'confirmed',
    }.contains(currentStatus)) {
      throw Exception(
        'This booking cannot be finalized from its current state',
      );
    }

    final withDriver = booking['with_driver'] == true;
    final driverId = booking['driver_id']?.toString().trim() ?? '';
    Map<String, dynamic>? acceptedAssignment;
    if (withDriver) {
      if (driverId.isEmpty) {
        throw Exception('Select a driver before finalizing this booking');
      }

      final assignmentRows = await supabase
          .from('driver_job_assignments')
          .select('id, status, driver_id, replied_at')
          .eq('booking_id', bookingId)
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(1);
      if (assignmentRows.isNotEmpty) {
        acceptedAssignment = Map<String, dynamic>.from(assignmentRows.first);
      }
      final responseStatus = acceptedAssignment?['status']
          ?.toString()
          .trim()
          .toLowerCase();
      if (responseStatus != 'accepted' && responseStatus != 'confirmed') {
        throw Exception('Wait for the selected driver to accept the job first');
      }
    }

    final now = DateTime.now().toIso8601String();
    if (currentStatus != 'confirmed') {
      await supabase
          .from('bookings')
          .update({
            'status': 'confirmed',
            'operator_id': operatorId,
            'approved_at': now,
            'updated_at': now,
          })
          .eq('id', bookingId);
    } else if (booking['operator_id']?.toString() != operatorId) {
      await supabase
          .from('bookings')
          .update({'operator_id': operatorId, 'updated_at': now})
          .eq('id', bookingId);
    }

    if (acceptedAssignment != null) {
      await supabase
          .from('driver_job_assignments')
          .update({'status': 'confirmed', 'updated_at': now})
          .eq('id', acceptedAssignment['id']);
    }

    final finalized = await getBookingById(bookingId);
    if (finalized == null) {
      throw Exception('Booking finalized but could not be reloaded');
    }
    final vehicle = finalized['vehicles'] as Map<String, dynamic>?;
    final vehicleTitle = _vehicleTitle(vehicle);
    await _ensureBookingGroupChatAndSummary(
      booking: finalized,
      vehicleTitle: vehicleTitle,
      summaryTitle: 'Booking Confirmed',
    );

    final renterId = finalized['renter_id']?.toString();
    if (renterId != null && renterId.isNotEmpty) {
      await NotificationService().notifyBookingFinalized(
        userId: renterId,
        bookingId: bookingId,
        vehicleTitle: vehicleTitle,
        role: 'renter',
      );
    }
    if (driverId.isNotEmpty) {
      await NotificationService().notifyBookingFinalized(
        userId: driverId,
        bookingId: bookingId,
        vehicleTitle: vehicleTitle,
        role: 'driver',
      );
    }
    final ownerId = vehicle?['owner_id']?.toString();
    if (ownerId != null &&
        ownerId.isNotEmpty &&
        ownerId != operatorId &&
        ownerId != renterId) {
      await NotificationService().notifyBookingFinalized(
        userId: ownerId,
        bookingId: bookingId,
        vehicleTitle: vehicleTitle,
        role: 'partner',
      );
    }

    return finalized;
  }

  /// Repairs or creates the booking group chat without duplicating it.
  /// Only approved/active trips are eligible for an active conversation.
  Future<void> ensureBookingConversationForActiveBooking({
    required String bookingId,
    String? operatorId,
  }) async {
    var booking = await getBookingById(bookingId);
    if (booking == null) return;

    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    const activeStatuses = {'approved', 'confirmed', 'active', 'ongoing'};
    if (!activeStatuses.contains(status)) return;

    final storedOperatorId = booking['operator_id']?.toString().trim() ?? '';
    final resolvedOperatorId = operatorId?.trim() ?? '';
    if (storedOperatorId.isEmpty && resolvedOperatorId.isNotEmpty) {
      await supabase
          .from('bookings')
          .update({
            'operator_id': resolvedOperatorId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);
      booking = await getBookingById(bookingId) ?? booking;
    }

    await _ensureBookingGroupChatAndSummary(
      booking: booking,
      vehicleTitle: _vehicleTitle(booking['vehicles'] as Map<String, dynamic>?),
      summaryTitle: 'Booking Confirmed',
    );
  }

  /// Unassign driver from booking
  Future<void> unassignDriver(String bookingId) async {
    try {
      debugPrint('Unassigning driver from booking: $bookingId');
      final booking = await supabase
          .from('bookings')
          .select('driver_id')
          .eq('id', bookingId)
          .maybeSingle();
      final driverId = booking?['driver_id']?.toString();
      final now = DateTime.now().toIso8601String();
      await supabase
          .from('bookings')
          .update({
            'driver_id': null,
            'driver_assigned_at': null,
            'status': 'pending',
            'updated_at': now,
          })
          .eq('id', bookingId);

      await supabase
          .from('driver_job_assignments')
          .update({'status': 'cancelled', 'updated_at': now})
          .eq('booking_id', bookingId)
          .inFilter('status', ['pending_offer', 'assigned', 'accepted']);
      if (driverId != null && driverId.isNotEmpty) {
        await supabase
            .from('users')
            .update({'is_available': true})
            .eq('id', driverId);
      }

      debugPrint('Driver unassigned from booking');
    } on PostgrestException catch (e) {
      debugPrint('Database error unassigning driver: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error unassigning driver: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableVerifiedDrivers({
    DateTime? bookingDate,
    List<Map<String, double>> proximityTargets = const [],
    bool prioritizeProximity = false,
    bool prioritizePsdc = false,
  }) async {
    try {
      final targetDate = (bookingDate ?? DateTime.now()).toLocal();
      final scheduleDate =
          '${targetDate.year.toString().padLeft(4, '0')}-'
          '${targetDate.month.toString().padLeft(2, '0')}-'
          '${targetDate.day.toString().padLeft(2, '0')}';

      final Map<String, bool> dateScheduleMap = {};
      try {
        final dateScheduleResponse = await supabase
            .from('driver_availability_schedule')
            .select('driver_id, is_available')
            .eq('date', scheduleDate);

        for (final row in List<Map<String, dynamic>>.from(dateScheduleResponse)) {
          final dId = row['driver_id']?.toString();
          if (dId != null && dId.isNotEmpty) {
            dateScheduleMap[dId] = row['is_available'] == true;
          }
        }
      } catch (scheduleErr) {
        debugPrint('Driver availability schedule lookup note: $scheduleErr');
      }

      List<Map<String, dynamic>> rawDriverRows = [];

      // 1. Query verified & approved drivers directly from public.drivers joined with public.users
      try {
        final response = await supabase
            .from('drivers')
            .select(
              'id, user_id, verification_status, driver_tier, rating, total_trips, users(id, full_name, email, phone, role, is_available, id_verified, verification_status, application_status, avatar_url, profile_picture_url, location, latitude, longitude, is_active)',
            )
            .or('verification_status.eq.approved,verification_status.eq.verified');
        for (final row in List<Map<String, dynamic>>.from(response)) {
          final u = row['users'] as Map<String, dynamic>?;
          final uId = row['user_id']?.toString() ?? u?['id']?.toString();
          if (u != null && uId != null && uId.isNotEmpty && u['is_active'] != false) {
            rawDriverRows.add(row);
          }
        }
      } catch (joinErr) {
        debugPrint('Direct drivers table query note: $joinErr');
      }

      final drivers = rawDriverRows
          .where((driver) {
            final user = driver['users'] as Map<String, dynamic>?;
            if (user == null) return false;

            // Reject suspended / inactive users
            if (user['is_active'] == false) return false;

            final driverUserId = driver['user_id']?.toString() ?? '';
            final driverProfileId = driver['id']?.toString() ?? '';

            final bool? dateOverride =
                dateScheduleMap[driverUserId] ??
                dateScheduleMap[driverProfileId];

            // If date schedule has an explicit false, they're off-duty on this date
            if (dateOverride == false) return false;

            final driverVer =
                driver['verification_status']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';
            final userVer =
                user['verification_status']?.toString().trim().toLowerCase() ??
                '';
            final userAppStatus =
                user['application_status']?.toString().trim().toLowerCase() ??
                '';

            // Filter out explicitly rejected drivers
            if (driverVer == 'rejected' || userVer == 'rejected' || userAppStatus == 'rejected') {
              return false;
            }

            // Must be verified and have completed driver/user application
            final isVerifiedOrDone =
                user['id_verified'] == true ||
                _isVerifiedDriverStatus(userVer) ||
                _isVerifiedDriverStatus(driverVer) ||
                userAppStatus == 'approved' ||
                userAppStatus == 'verified' ||
                userAppStatus == 'basic' ||
                userAppStatus == 'completed' ||
                driver['license_verified'] == true;

            if (!isVerifiedOrDone) return false;

            return true;
          })
          .map((driver) {
            final normalized = Map<String, dynamic>.from(driver);
            final user = Map<String, dynamic>.from(driver['users'] as Map<String, dynamic>? ?? {});
            final isPsdc =
                driver['is_psdc_driver'] == true ||
                user['is_psdc_driver'] == true ||
                driver['driver_tier']?.toString().toLowerCase() == 'psdc';
            normalized['is_psdc_driver'] = isPsdc;

            // Resolve driver coordinates from Plus Code, city name, address, or lat/lng
            final rawLocation = user['location'] ?? user['address'] ?? user['city'] ?? driver['address'] ?? driver['location'] ?? '';
            final resolvedPoint = PhilippineGeocoding.resolveLocationSync(
              rawLocation,
              latitudeValue: user['latitude'] ?? driver['latitude'],
              longitudeValue: user['longitude'] ?? driver['longitude'],
            );

            user['latitude'] = resolvedPoint.latitude;
            user['longitude'] = resolvedPoint.longitude;
            normalized['users'] = user;
            normalized['latitude'] = resolvedPoint.latitude;
            normalized['longitude'] = resolvedPoint.longitude;

            if (proximityTargets.isNotEmpty) {
              final distances = proximityTargets.map(
                (target) => _distanceInKilometers(
                  resolvedPoint.latitude,
                  resolvedPoint.longitude,
                  target['latitude']!,
                  target['longitude']!,
                ),
              );
              normalized['distance_km'] = distances.reduce(math.min);
            }
            return normalized;
          })
          .toList();

      drivers.sort((a, b) {
        if (prioritizeProximity) {
          final aDistance = (a['distance_km'] as num?)?.toDouble();
          final bDistance = (b['distance_km'] as num?)?.toDouble();
          if (aDistance != null && bDistance != null) {
            final comparison = aDistance.compareTo(bDistance);
            if (comparison != 0) return comparison;
          } else if (aDistance != null) {
            return -1;
          } else if (bDistance != null) {
            return 1;
          }
        }

        if (prioritizePsdc || (!prioritizeProximity && prioritizePsdc)) {
          final aIsPsdc = a['is_psdc_driver'] == true;
          final bIsPsdc = b['is_psdc_driver'] == true;
          if (aIsPsdc && !bIsPsdc) return -1;
          if (!aIsPsdc && bIsPsdc) return 1;
        }

        final aRating = (a['rating'] as num?)?.toDouble() ?? 0.0;
        final bRating = (b['rating'] as num?)?.toDouble() ?? 0.0;
        if (aRating != bRating) {
          return bRating.compareTo(aRating);
        }

        final aTrips = (a['total_trips'] as num?)?.toInt() ?? 0;
        final bTrips = (b['total_trips'] as num?)?.toInt() ?? 0;
        if (aTrips != bTrips) {
          return bTrips.compareTo(aTrips);
        }

        final aUser = a['users'] as Map<String, dynamic>?;
        final bUser = b['users'] as Map<String, dynamic>?;
        final aName = aUser?['full_name']?.toString() ?? '';
        final bName = bUser?['full_name']?.toString() ?? '';
        return aName.compareTo(bName);
      });

      return drivers;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching available drivers: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching available drivers: $e');
      return [];
    }
  }

  double _distanceInKilometers(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const earthRadiusKm = 6371.0;
    final latitudeDelta = _degreesToRadians(latitudeB - latitudeA);
    final longitudeDelta = _degreesToRadians(longitudeB - longitudeA);
    final a =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(_degreesToRadians(latitudeA)) *
            math.cos(_degreesToRadians(latitudeB)) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  /// Mark a confirmed booking as picked up and active.
  Future<void> markBookingPickedUp(String bookingId) async {
    try {
      debugPrint('Marking booking picked up: $bookingId');

      final booking = await getBookingById(bookingId);
      if (booking == null) {
        throw Exception('Booking not found: $bookingId');
      }

      final status = (booking['status'] as String? ?? '').toLowerCase();
      if (status != 'confirmed' && status != 'approved') {
        throw Exception('Only confirmed bookings can be marked as picked up');
      }

      final currentUserId = supabase.auth.currentUser?.id;
      final assignedDriverId = booking['driver_id']?.toString();
      final withDriver = booking['with_driver'] == true;
      if (!withDriver) {
        throw Exception(
          'Pickup updates are only allowed for with-driver bookings',
        );
      }
      if (currentUserId == null ||
          assignedDriverId == null ||
          assignedDriverId != currentUserId) {
        throw Exception('Only the assigned driver can mark pickup time');
      }

      final inspection = await BookingInspectionService()
          .getCompletedInspection(
            bookingId: bookingId,
            inspectionType: 'before',
          );
      await _postInspectionAuditToBookingChat(
        booking: booking,
        inspection: inspection,
        inspectionType: 'before',
      );

      await supabase
          .from('bookings')
          .update({
            'status': 'active',
            'picked_up_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      try {
        await supabase
            .from('driver_job_assignments')
            .update({
              'status': 'in_progress',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('booking_id', bookingId)
            .eq('driver_id', currentUserId);
      } catch (e) {
        debugPrint('Could not update assignment status to in_progress: $e');
      }

      await _notifyOperatorsForBooking(
        booking,
        title: 'Unit Picked Up',
        message: 'The driver marked the unit as picked up.',
        action: 'picked_up',
      );

      debugPrint('Booking marked as active');
    } on PostgrestException catch (e) {
      debugPrint('Database error marking pickup: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error marking pickup: $e');
      rethrow;
    }
  }

  /// Complete a returned booking and recalculate the total from the actual
  /// return date when it differs from the scheduled end date.
  Future<double> completeBookingReturn({
    required String bookingId,
    required DateTime returnedAt,
  }) async {
    try {
      debugPrint('Completing returned booking: $bookingId');

      final booking = await getBookingById(bookingId);
      if (booking == null) {
        throw Exception('Booking not found: $bookingId');
      }

      final status = (booking['status'] as String? ?? '').toLowerCase();
      if (status != 'active' && status != 'ongoing') {
        throw Exception('Only ongoing bookings can be marked as returned');
      }

      final currentUserId = supabase.auth.currentUser?.id;
      final assignedDriverId = booking['driver_id']?.toString();
      final withDriver = booking['with_driver'] == true;
      if (!withDriver) {
        throw Exception(
          'Return updates are only allowed for with-driver bookings',
        );
      }
      final isDriver = currentUserId != null &&
          assignedDriverId != null &&
          (assignedDriverId == currentUserId ||
              assignedDriverId ==
                  await _getDriverProfileIdForUser(currentUserId) ||
              await _getDriverUserIdForProfile(assignedDriverId) ==
                  currentUserId);
      if (!isDriver) {
        throw Exception('Only the assigned driver can mark return time');
      }

      final lateReturn = _lateReturnValues(booking, returnedAt);
      final lateReturnFee = lateReturn['late_return_fee'] as double;
      final recalculatedTotal = lateReturn['total_price'] as double;

      await supabase
          .from('bookings')
          .update({
            'status': 'return_pending_inspection',
            'returned_at': returnedAt.toIso8601String(),
            'completion_stage': 'awaiting_after_checklist',
            ...lateReturn,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final driverUserId = booking['driver_id']?.toString() ?? currentUserId;
      if (driverUserId.isNotEmpty) {
        await supabase
            .from('users')
            .update({'is_available': true})
            .eq('id', driverUserId);
      }

      try {
        await supabase
            .from('driver_job_assignments')
            .update({
              'status': 'awaiting_completion',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('booking_id', bookingId)
            .inFilter('status', ['assigned', 'accepted', 'ongoing', 'in_progress', 'pending_offer']);
      } catch (e) {
        debugPrint('Could not update assignment return status: $e');
      }

      await _notifyOperatorsForBooking(
        booking,
        title: 'Unit Ready For Return Inspection',
        message:
            'The driver marked the unit as returned. Complete the after-return checklist, evidence, payment, and ratings. Late fee: ${PricingPolicy.peso(lateReturnFee)}. Final total: ${PricingPolicy.peso(recalculatedTotal)}.',
        action: 'returned',
      );

      debugPrint('Booking return is awaiting the after checklist');
      return recalculatedTotal;
    } on PostgrestException catch (e) {
      debugPrint('Database error completing return: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error completing return: $e');
      rethrow;
    }
  }

  /// Starts a booking after the responsible operator or partner completes the
  /// release checklist. This is also used for self-drive bookings that do not
  /// have a driver pickup action.
  Future<void> startBookingAfterInspection({
    required String bookingId,
    required String inspectorId,
  }) async {
    final inspectionService = BookingInspectionService();
    await inspectionService.assertResponsibleInspector(
      bookingId: bookingId,
      inspectorId: inspectorId,
    );
    final inspection = await inspectionService.getCompletedInspection(
      bookingId: bookingId,
      inspectionType: 'before',
    );

    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');
    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    if (status != 'approved' && status != 'confirmed') {
      if (status == 'active' || status == 'ongoing') return;
      throw Exception('Only approved bookings can begin their trip');
    }
    await _postInspectionAuditToBookingChat(
      booking: booking,
      inspection: inspection,
      inspectionType: 'before',
    );

    final now = DateTime.now().toIso8601String();
    await supabase
        .from('bookings')
        .update({'status': 'active', 'picked_up_at': now, 'updated_at': now})
        .eq('id', bookingId);

    final driverId = booking['driver_id']?.toString();
    if (driverId?.isNotEmpty == true) {
      try {
        await supabase
            .from('driver_job_assignments')
            .update({'status': 'in_progress', 'updated_at': now})
            .eq('booking_id', bookingId)
            .eq('driver_id', driverId!);
      } catch (e) {
        debugPrint('Could not start driver assignment: $e');
      }
    }

    final renterId = booking['renter_id']?.toString();
    if (renterId?.isNotEmpty == true) {
      await NotificationService().createNotification(
        userId: renterId!,
        title: 'Trip Started',
        message:
            'The release checklist is complete and your booking is now ongoing.',
        type: 'booking_ongoing',
        data: {'booking_id': bookingId, 'vehicle_id': booking['vehicle_id']},
      );
    }
  }

  /// Records the returned vehicle after the responsible operator or partner
  /// submits the after checklist. If payment is confirmed, booking is completed.
  /// If payment is unpaid, return goes through but booking stays ongoing / awaiting payment.
  Future<void> completeBookingAfterInspection({
    required String bookingId,
    required String inspectorId,
    bool confirmPaymentIfUnpaid = false,
  }) async {
    final inspectionService = BookingInspectionService();
    await inspectionService.assertResponsibleInspector(
      bookingId: bookingId,
      inspectorId: inspectorId,
    );
    final inspection = await inspectionService.getCompletedInspection(
      bookingId: bookingId,
      inspectionType: 'after',
    );

    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');
    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    if (status == 'completed' ||
        status == 'cancelled' ||
        status == 'rejected') {
      return;
    }
    await _postInspectionAuditToBookingChat(
      booking: booking,
      inspection: inspection,
      inspectionType: 'after',
    );

    final returnedAt = DateTime.now();
    final now = returnedAt.toIso8601String();
    final lateReturn = _lateReturnValues(booking, returnedAt);

    final currentPaymentStatus =
        booking['final_payment_status']?.toString().trim().toLowerCase() ??
        'pending';
    final isPaid = currentPaymentStatus == 'paid' || confirmPaymentIfUnpaid;

    if (isPaid) {
      await supabase
          .from('bookings')
          .update({
            'status': 'completed',
            'returned_at': now,
            'completed_at': now,
            'final_payment_status': 'paid',
            'final_payment_confirmed_at': now,
            'final_payment_confirmed_by': inspectorId,
            ...lateReturn,
            'updated_at': now,
          })
          .eq('id', bookingId);

      try {
        await LoyaltyService().awardPointsForCompletedBooking(bookingId);
      } catch (e) {
        debugPrint('Could not award loyalty points: $e');
      }
    } else {
      // Payment has NOT been confirmed yet. Return goes through, but booking stays ongoing!
      await supabase
          .from('bookings')
          .update({
            'status': 'ongoing',
            'returned_at': now,
            'completion_stage': 'awaiting_payment',
            'final_payment_status': 'pending',
            ...lateReturn,
            'updated_at': now,
          })
          .eq('id', bookingId);
    }

    try {
      await TripRatingService().syncRatingFlowForBooking(
        bookingId,
        operatorFallbackUserId: inspectorId,
      );
    } catch (e) {
      debugPrint('Could not sync rating flow: $e');
    }

    final driverId = booking['driver_id']?.toString();
    if (driverId?.isNotEmpty == true) {
      await supabase
          .from('users')
          .update({'is_available': true})
          .eq('id', driverId!);
      try {
        await supabase
            .from('driver_job_assignments')
            .update({
              'status': isPaid ? 'completed' : 'awaiting_completion',
              'updated_at': now,
            })
            .eq('booking_id', bookingId)
            .eq('driver_id', driverId);
      } catch (e) {
        debugPrint('Could not update driver assignment: $e');
      }
    }

    final renterId = booking['renter_id']?.toString();
    if (renterId?.isNotEmpty == true) {
      await NotificationService().createNotification(
        userId: renterId!,
        title: 'Vehicle Return Inspected & Trip Completed',
        message:
            'The return inspection is complete and your trip is marked as completed! Don\'t forget to rate your experience.',
        type: 'trip_completed',
        data: {'booking_id': bookingId, 'vehicle_id': booking['vehicle_id']},
      );
    }

    // Automated vehicle unlisting for turnaround / cleaning & inspection
    try {
      final vehicleId = booking['vehicle_id']?.toString();
      if (vehicleId != null && vehicleId.isNotEmpty) {
        final vehicle = booking['vehicles'] as Map<String, dynamic>?;
        final partnerVehicleId = booking['partner_vehicle_id']?.toString() ??
            vehicle?['partner_vehicle_id']?.toString();
        final vehicleTitle = _vehicleTitle(vehicle);
        final partnerId = vehicle?['owner_id']?.toString();

        await VehicleTurnaroundService().handleVehicleReturn(
          vehicleId: vehicleId,
          partnerVehicleId: partnerVehicleId,
          bookingId: bookingId,
          vehicleTitle: vehicleTitle,
          partnerId: partnerId,
        );
      }
    } catch (turnaroundErr) {
      debugPrint('Could not initiate vehicle turnaround: $turnaroundErr');
    }
  }

  Future<void> _postInspectionAuditToBookingChat({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> inspection,
    required String inspectionType,
  }) async {
    try {
      final bookingId = booking['id']?.toString() ?? '';
      final inspectorId = inspection['inspector_id']?.toString() ?? '';
      if (bookingId.isEmpty || inspectorId.isEmpty) return;

      try {
        await _ensureBookingGroupChatAndSummary(
          booking: booking,
          vehicleTitle: _vehicleTitle(
            booking['vehicles'] as Map<String, dynamic>?,
          ),
          summaryTitle: 'Booking Confirmed',
        );
      } catch (_) {}

      final conversation = await ChatService().getConversationByBookingId(
        bookingId,
      );
      final conversationId = conversation?['id']?.toString() ?? '';
      if (conversationId.isEmpty) {
        debugPrint(
          'The booking conversation could not be prepared for audit message',
        );
        return;
      }

      final inspector = await _getUserById(inspectorId);
      final inspectorName =
          inspector?['full_name']?.toString().trim().isNotEmpty == true
          ? inspector!['full_name'].toString().trim()
          : 'Responsible inspector';
      final inspectorRole = inspector?['role']?.toString().trim().toLowerCase();
      final roleLabel = inspectorRole == 'partner' ? 'Partner' : 'Operator';
      final normalizedType = inspectionType.trim().toLowerCase();
      final isBefore = normalizedType == 'before';
      final evidence = inspection['evidence_urls'] is List
          ? List<dynamic>.from(inspection['evidence_urls'] as List)
                .map((item) => item.toString().trim())
                .where((url) => url.isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      final checklist = inspection['checklist_items'] is Map
          ? Map<String, dynamic>.from(inspection['checklist_items'] as Map)
          : const <String, dynamic>{};
      final checkedSectionLines = <String>[];
      var checkedCount = 0;
      for (final section
          in BookingInspectionService.checklistSections.entries) {
        final confirmedLabels = section.value.entries
            .where((entry) => checklist[entry.key] == true)
            .map((entry) => entry.value)
            .toList(growable: false);
        checkedCount += confirmedLabels.length;
        if (confirmedLabels.isNotEmpty) {
          checkedSectionLines.add('• ${section.key.toUpperCase()}');
          for (final label in confirmedLabels) {
            checkedSectionLines.add('  - $label');
          }
        }
      }

      final evidenceUrl = evidence.isNotEmpty ? evidence.first : null;
      final lowerEvidenceUrl = evidenceUrl?.toLowerCase() ?? '';
      final evidenceType =
          lowerEvidenceUrl.contains('.mp4') ||
              lowerEvidenceUrl.contains('.mov') ||
              lowerEvidenceUrl.contains('.webm')
          ? 'video'
          : 'image';
      final inspectionId =
          inspection['id']?.toString() ??
          '$bookingId-$normalizedType-$inspectorId';
      final title = isBefore
          ? 'Before-Release Checklist Submitted'
          : 'After-Return Checklist Submitted';
      final content = <String>[
        title,
        'Submitted by: $inspectorName ($roleLabel)',
        'Fuel level: ${inspection['fuel_level'] ?? 'Recorded'}',
        'Mileage: ${inspection['mileage'] ?? 'Recorded'} km',
        'Cleanliness: ${inspection['cleanliness'] ?? 'Recorded'}',
        'Checklist: $checkedCount/${BookingInspectionService.requiredChecklistKeys.length} items confirmed',
        'Evidence: ${evidence.length} photo/video file${evidence.length == 1 ? '' : 's'} attached',
        'Released by: ${inspection['released_by'] ?? 'N/A'}',
        'Received by: ${inspection['received_by'] ?? 'N/A'}',
        if (inspection['scratches']?.toString().trim().isNotEmpty == true)
          'Scratches: ${inspection['scratches']}',
        if (inspection['dents']?.toString().trim().isNotEmpty == true)
          'Dents: ${inspection['dents']}',
        if (inspection['damages']?.toString().trim().isNotEmpty == true)
          'Damages: ${inspection['damages']}',
        if (inspection['remarks']?.toString().trim().isNotEmpty == true)
          'Remarks: ${inspection['remarks']}',
        if (checkedSectionLines.isNotEmpty) '',
        if (checkedSectionLines.isNotEmpty) 'CONFIRMED CHECKLIST ITEMS',
        ...checkedSectionLines,
        '',
        isBefore
            ? 'The vehicle release record is now visible to every booking participant.'
            : 'The vehicle return record is now visible to every booking participant. The trip remains pending until full payment and every mandatory participant rating is recorded.',
      ].join('\n');

      await ChatService().sendBookingAuditMessage(
        conversationId: conversationId,
        senderId: inspectorId,
        content: content,
        auditKey: 'vehicle-checklist:$normalizedType:$inspectionId',
        attachmentUrl: evidenceUrl,
        attachmentType: evidenceUrl == null ? null : evidenceType,
        attachmentName: evidenceUrl == null
            ? null
            : '${isBefore ? 'before-release' : 'after-return'}-evidence-1-of-${evidence.length}',
      );
    } catch (e) {
      debugPrint('Error posting inspection audit to chat: $e');
    }
  }

  Map<String, dynamic> _lateReturnValues(
    Map<String, dynamic> booking,
    DateTime returnedAt,
  ) {
    final scheduledReturn =
        DateTime.tryParse(booking['end_at']?.toString() ?? '') ??
        DateTime.tryParse(booking['end_date']?.toString() ?? '');
    final lateSeconds = scheduledReturn == null
        ? 0
        : returnedAt.difference(scheduledReturn).inSeconds;
    final lateHours = lateSeconds <= 0
        ? 0
        : math.max(1, (lateSeconds / Duration.secondsPerHour).ceil());
    final lateFee = lateHours * PricingPolicy.lateReturnRatePerHour;
    final existingLateFee = _asDouble(booking['late_return_fee']) ?? 0.0;
    final currentTotal =
        _asDouble(booking['total_price']) ??
        _asDouble(booking['total_cost']) ??
        0.0;
    final totalWithoutPreviousLateFee = math.max(
      0.0,
      currentTotal - existingLateFee,
    );
    final finalTotal = totalWithoutPreviousLateFee + lateFee;
    return {
      'late_return_hours': lateHours,
      'late_return_days': lateHours == 0 ? 0 : (lateHours / 24).ceil(),
      'late_return_fee': lateFee,
      'total_price': finalTotal,
      'total_cost': finalTotal,
    };
  }

  int _inclusiveRentalDays(DateTime startDate, DateTime endDate) {
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final calendarDays = endDay.difference(startDay).inDays + 1;
    return calendarDays < 1 ? 1 : calendarDays;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool _isExplicitlyUnavailable(dynamic value) {
    if (value is bool) return value == false;
    if (value is String) return value.toLowerCase() == 'false';
    return false;
  }

  bool _isVerifiedDriverStatus(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';
    return status == 'verified' ||
        status == 'approved' ||
        status == 'certified' ||
        status == 'active';
  }

  Future<Map<String, dynamic>?> _getDriverAssignmentTarget(
    String driverIdOrUserId,
  ) async {
    final cleanId = driverIdOrUserId.trim();
    if (cleanId.isEmpty) return null;

    // 1. Try finding in drivers table
    try {
      final driver = await supabase
          .from('drivers')
          .select('id, user_id, verification_status')
          .or('id.eq.$cleanId,user_id.eq.$cleanId')
          .maybeSingle();

      if (driver != null) {
        final userId = driver['user_id']?.toString() ?? cleanId;
        final user = await supabase
            .from('users')
            .select('id, full_name, role, is_available')
            .eq('id', userId)
            .maybeSingle();

        return {
          'driver_id': driver['id']?.toString() ?? cleanId,
          'user_id': userId,
          'verification_status': driver['verification_status'] ?? 'verified',
          'full_name': user?['full_name'] ?? 'Driver',
          'is_available': user?['is_available'] != false,
        };
      }
    } catch (e) {
      debugPrint('Driver table lookup note: $e');
    }

    // 2. Fallback: Lookup directly in users table
    try {
      final user = await supabase
          .from('users')
          .select('id, full_name, role, is_available')
          .eq('id', cleanId)
          .maybeSingle();

      if (user != null) {
        return {
          'driver_id': cleanId,
          'user_id': cleanId,
          'verification_status': 'verified',
          'full_name': user['full_name'] ?? 'Driver',
          'is_available': user['is_available'] != false,
        };
      }
    } catch (e) {
      debugPrint('User table driver target lookup note: $e');
    }

    return null;
  }

  Future<String?> _getDriverProfileIdForUser(String userId) async {
    final driver = await supabase
        .from('drivers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return driver?['id']?.toString();
  }

  Future<String?> _getDriverUserIdForProfile(String driverProfileId) async {
    final driver = await supabase
        .from('drivers')
        .select('user_id')
        .eq('id', driverProfileId)
        .maybeSingle();
    return driver?['user_id']?.toString();
  }

  Future<String?> _resolveDriverUserId(String driverIdOrUserId) async {
    final byUserId = await supabase
        .from('drivers')
        .select('user_id')
        .eq('user_id', driverIdOrUserId)
        .maybeSingle();
    final existingUserId = byUserId?['user_id']?.toString();
    if (existingUserId != null && existingUserId.isNotEmpty) {
      return existingUserId;
    }

    return _getDriverUserIdForProfile(driverIdOrUserId);
  }

  bool _hasTripConfirmation(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isNotEmpty;
  }

  String? _tripConfirmationColumnForRole(String role) {
    switch (role) {
      case 'operator':
        return 'operator_trip_confirmed_at';
      case 'partner':
        return 'partner_trip_confirmed_at';
      case 'driver':
        return 'driver_trip_confirmed_at';
      case 'renter':
        return 'renter_trip_confirmed_at';
      default:
        return null;
    }
  }

  Future<void> _notifyOperatorsForBooking(
    Map<String, dynamic> booking, {
    required String title,
    required String message,
    required String action,
  }) async {
    final operatorIds = <String>{};
    final operatorId = booking['operator_id']?.toString();
    if (operatorId != null && operatorId.isNotEmpty) {
      operatorIds.add(operatorId);
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleOperatorId = vehicle?['operator_id']?.toString();
    if (vehicleOperatorId != null && vehicleOperatorId.isNotEmpty) {
      operatorIds.add(vehicleOperatorId);
    }

    if (operatorIds.isEmpty) {
      final operators = await supabase
          .from('users')
          .select('id')
          .eq('role', 'operator')
          .limit(20);
      for (final operator in List<Map<String, dynamic>>.from(operators)) {
        final id = operator['id']?.toString();
        if (id != null && id.isNotEmpty) operatorIds.add(id);
      }
    }

    for (final id in operatorIds) {
      try {
        await NotificationService().createNotification(
          userId: id,
          title: title,
          message: message,
          type: 'booking_driver_update',
          data: {
            'booking_id': booking['id'],
            'vehicle_id': booking['vehicle_id'],
            'driver_id': booking['driver_id'],
            'action': action,
          },
        );
      } catch (e) {
        debugPrint('Could not notify operator $id: $e');
      }
    }
  }

  Future<void> _ensureBookingGroupChatAndSummary({
    required Map<String, dynamic> booking,
    required String vehicleTitle,
    String summaryTitle = 'Booking Details',
  }) async {
    final bookingId = booking['id']?.toString();
    final renterId = booking['renter_id']?.toString();
    if (bookingId == null ||
        bookingId.isEmpty ||
        renterId == null ||
        renterId.isEmpty) {
      return;
    }

    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final ownerId = vehicle?['owner_id']?.toString();
    final operatorId =
        booking['operator_id']?.toString() ??
        vehicle?['operator_id']?.toString() ??
        await _getDefaultOperatorId();
    final driverId = booking['driver_id']?.toString();
    final driverUserId = driverId == null || driverId.isEmpty
        ? null
        : await _resolveDriverUserId(driverId);
    final currentUserId = supabase.auth.currentUser?.id;
    final participantIds = <String>{renterId};
    if (ownerId != null && ownerId.isNotEmpty) {
      participantIds.add(ownerId);
    } else {
      // For company vehicles, add all active operators so all operators can see and reply to chat
      final allOperatorIds = await _getAllOperatorIds();
      participantIds.addAll(allOperatorIds);
    }
    if (operatorId != null && operatorId.isNotEmpty) {
      participantIds.add(operatorId);
    }
    if (currentUserId != null && currentUserId.isNotEmpty) {
      participantIds.add(currentUserId);
    }
    if (driverUserId != null && driverUserId.isNotEmpty) {
      participantIds.add(driverUserId);
    }

    final conversation = await ChatService().createGroupConversation(
      bookingId: bookingId,
      participantIds: participantIds.toList(),
    );

    final hasSummary = await _conversationHasBookingSummary(
      conversation['id'] as String,
    );
    if (hasSummary) {
      await supabase
          .from('bookings')
          .update({'conversation_created': true})
          .eq('id', bookingId);
      return;
    }

    final startLabel = _formatBookingDateTime(
      booking['start_at']?.toString() ?? booking['start_date']?.toString(),
    );
    final endLabel = _formatBookingDateTime(
      booking['end_at']?.toString() ?? booking['end_date']?.toString(),
    );
    final total =
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final withDriver = booking['with_driver'] == true ? 'Yes' : 'No';
    final renter = booking['users'] as Map<String, dynamic>?;
    final renterLabel = _partyLabel(
      renter,
      fallbackName: 'Renter',
      fallbackId: renterId,
    );
    final partner = ownerId == null || ownerId.isEmpty
        ? null
        : await _getUserById(ownerId);
    final partnerLabel = _partyLabel(
      partner,
      fallbackName: 'Partner/Owner',
      fallbackId: ownerId ?? 'N/A',
    );
    final operator = operatorId == null || operatorId.isEmpty
        ? null
        : await _getUserById(operatorId);
    final operatorLabel = operator == null
        ? 'Not assigned yet'
        : _partyLabel(
            operator,
            fallbackName: 'Operator',
            fallbackId: operatorId ?? 'N/A',
          );
    final driver = driverUserId == null || driverUserId.isEmpty
        ? null
        : await _getUserById(driverUserId);
    final driverLabel = booking['with_driver'] == true
        ? (driver == null
              ? 'Requested, waiting for operator assignment'
              : _partyLabel(
                  driver,
                  fallbackName: 'Driver',
                  fallbackId: driverUserId ?? 'N/A',
                ))
        : 'Not requested';
    final plateNumber = vehicle?['plate_number']?.toString();
    final summaryLines = <String>[
      summaryTitle,
      'Vehicle: $vehicleTitle',
      if (plateNumber != null && plateNumber.isNotEmpty)
        'Plate Number: $plateNumber',
      'Booking ID: $bookingId',
      'Status: ${booking['status'] ?? 'pending'}',
      'Schedule: $startLabel -> $endLabel',
      'Total: PHP ${total.toStringAsFixed(0)}',
      'With Driver: $withDriver',
      'Renter: $renterLabel',
      'Partner/Owner: $partnerLabel',
      'Operator: $operatorLabel',
      'Driver: $driverLabel',
      'Pickup: ${booking['pickup_location'] ?? 'N/A'}',
      'Drop-off: ${booking['dropoff_location'] ?? 'N/A'}',
      '',
      'Use this conversation for booking coordination and keep updates inside the app.',
    ];
    final summaryMessage = summaryLines.join('\n');

    final senderId = currentUserId ?? renterId;
    await ChatService().sendMessage(
      conversationId: conversation['id'] as String,
      senderId: senderId,
      content: summaryMessage,
      isAutoGenerated: true,
    );

    await supabase
        .from('bookings')
        .update({'conversation_created': true})
        .eq('id', bookingId);
  }

  Future<bool> _conversationHasBookingSummary(String conversationId) async {
    try {
      final existingMessages = await supabase
          .from('messages')
          .select('content, message')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(20);
      return List<Map<String, dynamic>>.from(existingMessages).any((message) {
        final content =
            (message['content'] ?? message['message'])
                ?.toString()
                .toLowerCase() ??
            '';
        return content.startsWith('booking request created') ||
            content.startsWith('booking details') ||
            content.startsWith('booking confirmed') ||
            content.startsWith('booking approved');
      });
    } catch (e) {
      debugPrint('Could not check existing booking summary: $e');
      return false;
    }
  }

  String _vehicleTitle(Map<String, dynamic>? vehicle) {
    if (vehicle == null) return 'Your rental vehicle';
    final vehicleName = vehicle['vehicle_name']?.toString().trim() ?? '';
    if (vehicleName.isNotEmpty) return vehicleName;
    final brand = vehicle['brand']?.toString().trim() ?? '';
    final model = vehicle['model']?.toString().trim() ?? '';
    final title = [brand, model].where((part) => part.isNotEmpty).join(' ');
    return title.isEmpty ? 'Your rental vehicle' : title;
  }

  Future<Map<String, dynamic>?> _getUserById(String userId) async {
    try {
      return await supabase
          .from('users')
          .select('id, full_name, email, phone, role')
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Could not fetch user $userId for booking chat: $e');
      return null;
    }
  }

  Future<String?> _getDefaultOperatorId() async {
    try {
      final operator = await supabase
          .from('users')
          .select('id')
          .eq('role', 'operator')
          .limit(1)
          .maybeSingle();
      return operator?['id']?.toString();
    } catch (e) {
      debugPrint('Could not fetch default operator for booking chat: $e');
      return null;
    }
  }

  Future<List<String>> _getAllOperatorIds() async {
    try {
      final operators = await supabase
          .from('users')
          .select('id')
          .eq('role', 'operator')
          .limit(20);
      return List<Map<String, dynamic>>.from(operators)
          .map((op) => op['id']?.toString().trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Could not fetch all operators: $e');
      return [];
    }
  }

  String _partyLabel(
    Map<String, dynamic>? user, {
    required String fallbackName,
    required String fallbackId,
  }) {
    final name = user?['full_name']?.toString().trim();
    final email = user?['email']?.toString().trim();
    final phone = user?['phone']?.toString().trim();
    final role = user?['role']?.toString().trim();
    final parts = <String>[
      if (name != null && name.isNotEmpty) name else fallbackName,
      if (role != null && role.isNotEmpty) 'Role: $role',
      if (email != null && email.isNotEmpty) email,
      if (phone != null && phone.isNotEmpty) phone,
      'ID: ${user?['id'] ?? fallbackId}',
    ];
    return parts.join(' | ');
  }

  Future<void> _sendBookingGroupMessage({
    required String bookingId,
    required String senderId,
    required String content,
  }) async {
    final conversation = await supabase
        .from('conversations')
        .select('id')
        .eq('booking_id', bookingId)
        .maybeSingle();
    if (conversation == null) return;
    await ChatService().sendMessage(
      conversationId: conversation['id'] as String,
      senderId: senderId,
      content: content,
    );
  }

  String _formatBookingDateTime(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    final local = parsed.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour12:$minute $suffix';
  }

  // ================== SEARCH & FILTER ==================

  /// Search bookings by multiple criteria
  Future<List<Map<String, dynamic>>> searchBookings({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? renterId,
    String? driverId,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      debugPrint('Searching bookings with filters');

      var query = supabase
          .from('bookings')
          .select(
            'id, renter_id, vehicle_id, start_at, end_at, start_date, end_date, status, total_price, pickup_location, dropoff_location, created_at, vehicles(brand, model, year, plate_number), users:users!bookings_renter_id_fkey(full_name, email)',
          );

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      if (startDate != null) {
        query = query.gte('start_date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('end_date', endDate.toIso8601String());
      }

      if (location != null && location.isNotEmpty) {
        query = query.or(
          'pickup_location.ilike.%$location%,dropoff_location.ilike.%$location%',
        );
      }

      if (renterId != null && renterId.isNotEmpty) {
        query = query.eq('renter_id', renterId);
      }

      if (driverId != null && driverId.isNotEmpty) {
        query = query.eq('driver_id', driverId);
      }

      if (minPrice != null) {
        query = query.gte('total_price', minPrice);
      }

      if (maxPrice != null) {
        query = query.lte('total_price', maxPrice);
      }

      final response = await query.order('created_at', ascending: false);

      debugPrint('Found ${response.length} matching bookings');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error searching bookings: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error searching bookings: $e');
      return [];
    }
  }

  /// Get booking statistics by date range
  Future<Map<String, dynamic>> getBookingStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('Fetching booking stats');

      var totalQuery = supabase
          .from('bookings')
          .select('id, total_price, status');

      if (startDate != null) {
        totalQuery = totalQuery.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        totalQuery = totalQuery.lte('created_at', endDate.toIso8601String());
      }

      final allBookings = List<Map<String, dynamic>>.from(await totalQuery);

      // Calculate stats
      int completed = 0;
      int cancelled = 0;
      int active = 0;
      double totalRevenue = 0;

      for (var booking in allBookings) {
        final status = booking['status'] as String?;
        final price = (booking['total_price'] as num?)?.toDouble() ?? 0;

        if (status == 'completed') {
          completed++;
          totalRevenue += price;
        } else if (status == 'cancelled') {
          cancelled++;
        } else if (status == 'active') {
          active++;
        }
      }

      return {
        'total_bookings': allBookings.length,
        'completed': completed,
        'cancelled': cancelled,
        'active': active,
        'total_revenue': totalRevenue,
        'average_booking_value': allBookings.isNotEmpty
            ? totalRevenue / allBookings.length
            : 0,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching stats: ${e.message}');
      return {};
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      return {};
    }
  }

  /// Checks if a booking can be extended and determines the maximum allowed extension date
  /// before any subsequent booking or reservation starts.
  Future<({
    bool canExtend,
    DateTime? maxAllowedExtensionDate,
    DateTime? nextBookingStart,
    String? blockingReason,
  })> getTripExtensionAvailability({
    required String bookingId,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) {
        return (
          canExtend: false,
          maxAllowedExtensionDate: null,
          nextBookingStart: null,
          blockingReason: 'Booking not found',
        );
      }

      final vehicleId = booking['vehicle_id']?.toString() ?? '';
      final endRaw =
          booking['end_at']?.toString() ?? booking['end_date']?.toString();
      final currentEndAt = endRaw != null
          ? DateTime.tryParse(endRaw)?.toLocal()
          : null;

      if (vehicleId.isEmpty || currentEndAt == null) {
        return (
          canExtend: false,
          maxAllowedExtensionDate: null,
          nextBookingStart: null,
          blockingReason: 'Invalid booking date details',
        );
      }

      final currentEndDay = DateTime(
        currentEndAt.year,
        currentEndAt.month,
        currentEndAt.day,
      );
      final initialFirstDate = currentEndDay.add(const Duration(days: 1));

      // Fetch all bookings for this vehicle excluding the current booking
      final response = await supabase
          .from('bookings')
          .select('id,start_at,end_at,start_date,end_date,status')
          .eq('vehicle_id', vehicleId)
          .neq('id', bookingId);

      final futureIntervals = <(DateTime, DateTime)>[];
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final status = row['status']?.toString();
        if (!_isBlockingStatus(status)) continue;
        final interval = _bookingInterval(row);
        if (interval == null) continue;
        final (start, end) = interval;
        // If this booking ends after our current end time or starts on/after our end day, it impacts future extension
        if (end.isAfter(currentEndAt) || !start.isBefore(currentEndDay)) {
          futureIntervals.add((start, end));
        }
      }

      // Sort by start date ascending to find the earliest conflicting upcoming booking
      futureIntervals.sort((a, b) => a.$1.compareTo(b.$1));

      DateTime maxLastDate = initialFirstDate.add(const Duration(days: 30));
      if (futureIntervals.isNotEmpty) {
        final earliestNextBooking = futureIntervals.first;
        final nextStart = earliestNextBooking.$1;
        final nextStartDay = DateTime(nextStart.year, nextStart.month, nextStart.day);

        // If the next booking starts on or before the first possible extension day, extension is impossible
        if (nextStart.isBefore(currentEndAt) || nextStartDay.isBefore(initialFirstDate) || nextStartDay == initialFirstDate) {
          final formattedDate = '${nextStart.month}/${nextStart.day}/${nextStart.year}';
          return (
            canExtend: false,
            maxAllowedExtensionDate: null,
            nextBookingStart: nextStart,
            blockingReason: 'This vehicle is already reserved for another customer starting $formattedDate. Trip extension is not available.',
          );
        }

        // The maximum allowed extension date is strictly the day before the next booking starts
        final contiguousMax = nextStartDay.subtract(const Duration(days: 1));
        if (contiguousMax.isBefore(initialFirstDate)) {
          final formattedDate = '${nextStart.month}/${nextStart.day}/${nextStart.year}';
          return (
            canExtend: false,
            maxAllowedExtensionDate: null,
            nextBookingStart: nextStart,
            blockingReason: 'This vehicle is already reserved for another customer starting $formattedDate. Trip extension is not available.',
          );
        }

        if (contiguousMax.isBefore(maxLastDate)) {
          maxLastDate = contiguousMax;
        }
      }

      return (
        canExtend: true,
        maxAllowedExtensionDate: maxLastDate,
        nextBookingStart: futureIntervals.isNotEmpty ? futureIntervals.first.$1 : null,
        blockingReason: null,
      );
    } catch (e) {
      debugPrint('Error checking trip extension availability: $e');
      return (
        canExtend: false,
        maxAllowedExtensionDate: null,
        nextBookingStart: null,
        blockingReason: 'Error checking availability: $e',
      );
    }
  }

  /// Renter requests a trip extension for an active booking.
  Future<void> requestTripExtension({
    required String bookingId,
    required DateTime newEndAt,
    required double additionalPrice,
    required int extensionDays,
    String? newDestination,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      if (booking['safety_freeze'] == true) {
        throw Exception(
          'This trip is currently under a Safety Freeze and cannot be extended. Please contact support.',
        );
      }

      final renterId = booking['renter_id']?.toString() ?? '';
      if (renterId.isNotEmpty) {
        final restriction = await UserRestrictionService().getUserRestriction(
          renterId,
        );
        if (restriction.isBlocked || restriction.isAccountRestricted) {
          throw Exception(
            'Your account is under safety review and cannot request trip extensions. Please return the vehicle by the scheduled time.',
          );
        }
      }

      final currentEndRaw =
          booking['end_at']?.toString() ?? booking['end_date']?.toString();
      final currentEndAt = currentEndRaw != null
          ? DateTime.tryParse(currentEndRaw)?.toLocal()
          : null;
      if (currentEndAt != null && !newEndAt.isAfter(currentEndAt)) {
        throw Exception(
          'Extended return date must be after your current return date.',
        );
      }

      final vehicleId = booking['vehicle_id']?.toString() ?? '';
      final overlappingBookings = await supabase
          .from('bookings')
          .select('id,start_at,end_at,start_date,end_date,status')
          .eq('vehicle_id', vehicleId)
          .neq('id', bookingId);

      final extensionStart = currentEndAt ?? DateTime.now();
      for (final b in List<Map<String, dynamic>>.from(overlappingBookings)) {
        final status = b['status']?.toString();
        if (!_isBlockingStatus(status)) continue;
        final interval = _bookingInterval(b);
        if (interval == null) continue;
        final (existingStart, existingEnd) = interval;
        if (extensionStart.isBefore(existingEnd) && newEndAt.isAfter(existingStart)) {
          final startFormatted = '${existingStart.month}/${existingStart.day}/${existingStart.year}';
          final endFormatted = '${existingEnd.month}/${existingEnd.day}/${existingEnd.year}';
          throw Exception(
            'This vehicle has already been reserved by another customer for $startFormatted - $endFormatted. Extension is not available for these dates.',
          );
        }
      }

      final principalPrice =
          (booking['principal_total_price'] as num?)?.toDouble() ??
          (booking['total_price'] as num?)?.toDouble() ??
          0.0;

      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final isPartnerVehicle = _isPartnerBookingVehicle(vehicle);

      await supabase
          .from('bookings')
          .update({
            'extension_requested_end_at': newEndAt.toIso8601String(),
            if (newDestination != null && newDestination.trim().isNotEmpty)
              'extension_requested_destination': newDestination.trim(),
            'extension_additional_price': additionalPrice,
            'extension_days': extensionDays,
            'extension_status': 'pending',
            'extension_payment_status': 'unpaid',
            'extension_requested_at': DateTime.now().toIso8601String(),
            'principal_total_price': principalPrice,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      // Create or locate conversation for this booking
      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      final renterName =
          booking['renter']?['full_name']?.toString() ??
          booking['users']?['full_name']?.toString() ??
          'Renter';
      final vehicleTitle = _vehicleTitle(vehicle);
      final formattedDate = '${newEndAt.month}/${newEndAt.day}/${newEndAt.year}';
      final destMsg = newDestination != null && newDestination.trim().isNotEmpty
          ? ' to "$newDestination"'
          : '';
      final msg =
          'Trip Extension Requested: $renterName requested extending trip until $formattedDate$destMsg (+PHP ${additionalPrice.toStringAsFixed(2)}). Awaiting ${isPartnerVehicle ? "Partner" : "Operator"} review.';

      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: renterId,
            content: msg,
          );
        }
      }

      // Send push notification to operators
      unawaited(
        NotificationService().notifyOperatorsNewBooking(
          bookingId: bookingId,
          vehicleTitle: vehicleTitle,
          renterName: renterName,
          withDriver: false,
        ).catchError((_) => 0),
      );
    } catch (e) {
      debugPrint('Error requesting trip extension: $e');
      rethrow;
    }
  }

  bool _isPartnerBookingVehicle(Map<String, dynamic> vehicle) {
    final ownerRole = vehicle['owner_role']?.toString().toLowerCase().trim();
    if (ownerRole == 'partner') return true;
    final owner = vehicle['owner'] as Map<String, dynamic>?;
    final role = owner?['role']?.toString().toLowerCase().trim();
    if (role == 'partner') return true;
    final partnerId = vehicle['partner_id']?.toString().trim();
    if (partnerId != null && partnerId.isNotEmpty) return true;
    final ownerId = vehicle['owner_id']?.toString().trim();
    return ownerId != null &&
        ownerId.isNotEmpty &&
        ownerRole != 'operator' &&
        ownerRole != 'admin';
  }

  /// Accept an extension request (Partner for partner vehicle, Operator for operator vehicle).
  Future<void> acceptTripExtension({
    required String bookingId,
    String? reviewerId,
    String? operatorId,
    String? reviewerRole,
  }) async {
    final effectiveReviewerId = reviewerId ?? operatorId ?? '';
    final effectiveRole = reviewerRole ?? (operatorId != null ? 'operator' : 'partner');

    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final isPartnerVehicle = _isPartnerBookingVehicle(vehicle);

      if (isPartnerVehicle && effectiveRole == 'operator') {
        throw Exception(
          'Operator cannot accept extension for a Partner-owned vehicle. Only the Partner can accept.',
        );
      }

      final addPrice =
          (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;

      await supabase
          .from('bookings')
          .update({
            'extension_status': 'payment_pending',
            'extension_payment_status': 'unpaid',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: effectiveReviewerId,
            content:
                'Trip Extension Accepted: Your extension request was accepted! Please pay the extension fee of PHP ${addPrice.toStringAsFixed(2)} in the app to proceed.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error accepting trip extension: $e');
      rethrow;
    }
  }

  /// Backward compatible alias for accepting trip extensions
  Future<void> approveTripExtension({
    required String bookingId,
    String? operatorId,
    String? reviewerId,
    String reviewerRole = 'operator',
  }) async {
    return acceptTripExtension(
      bookingId: bookingId,
      reviewerId: reviewerId ?? operatorId,
      reviewerRole: reviewerRole,
    );
  }

  /// Submit payment for an extension request (by Renter).
  Future<void> submitExtensionPayment({
    required String bookingId,
    String? renterId,
    String? method,
    String? reference,
    String? paymentMethod,
    String? paymentReference,
    String? proofUrl,
  }) async {
    final effectiveMethod = method ?? paymentMethod ?? 'E-Wallet';
    final effectiveReference = reference ?? paymentReference ?? 'N/A';
    final effectiveRenterId = renterId ?? supabase.auth.currentUser?.id ?? '';
    final effectiveProofUrl = proofUrl ?? '';

    try {
      await supabase
          .from('bookings')
          .update({
            'extension_payment_method': effectiveMethod.trim(),
            'extension_payment_reference': effectiveReference.trim(),
            'extension_payment_proof_url': effectiveProofUrl.trim(),
            'extension_payment_submitted_at': DateTime.now().toIso8601String(),
            'extension_payment_status': 'pending_review',
            'extension_status': 'payment_completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: effectiveRenterId,
            content:
                'Extension Payment Submitted: Renter submitted extension fee payment ($effectiveMethod - Ref: $effectiveReference). Awaiting verification.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error submitting extension payment: $e');
      rethrow;
    }
  }

  /// Verify extension payment (Operator for operator vehicle, Partner for partner vehicle).
  Future<void> verifyExtensionPayment({
    required String bookingId,
    required String verifierId,
    String? verifierRole,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final isPartnerVehicle = _isPartnerBookingVehicle(vehicle);

      if (isPartnerVehicle && verifierRole == 'operator') {
        throw Exception(
          'Operator cannot verify payment for a Partner-owned vehicle. Only the Partner can verify.',
        );
      }

      await supabase
          .from('bookings')
          .update({
            'extension_payment_status': 'verified',
            'extension_payment_verified_at': DateTime.now().toIso8601String(),
            'extension_payment_verified_by': verifierId,
            'extension_status': 'pending_final_confirmation',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: verifierId,
            content:
                'Extension Payment Verified: Payment confirmed! Ready for final trip extension confirmation.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error verifying extension payment: $e');
      rethrow;
    }
  }

  /// Finalize trip extension (commits new dates, destination, and fee to booking).
  Future<void> finalizeTripExtension({
    required String bookingId,
    required String finalizerId,
    String? finalizerRole,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final isPartnerVehicle = _isPartnerBookingVehicle(vehicle);

      if (isPartnerVehicle && finalizerRole == 'operator') {
        throw Exception(
          'Operator cannot finalize extension for a Partner-owned vehicle. Only the Partner can finalize.',
        );
      }

      final newEndAtRaw = booking['extension_requested_end_at']?.toString();
      if (newEndAtRaw == null) {
        throw Exception('No requested extension return date found on this booking.');
      }
      final newEndAt = DateTime.parse(newEndAtRaw);
      final addPrice =
          (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;
      final currentTotal =
          (booking['total_price'] as num?)?.toDouble() ??
          (booking['totalCost'] as num?)?.toDouble() ??
          0.0;
      final newTotal = currentTotal + addPrice;
      final requestedDest =
          booking['extension_requested_destination']?.toString();

      final currentDays = (booking['days'] as num?)?.toInt() ?? 1;
      final extDays = (booking['extension_days'] as num?)?.toInt() ?? 1;
      final totalDays = currentDays + extDays;

      await supabase
          .from('bookings')
          .update({
            'end_at': newEndAt.toIso8601String(),
            'end_date': newEndAt.toIso8601String(),
            'total_price': newTotal,
            'totalCost': newTotal,
            'days': totalDays,
            if (requestedDest != null && requestedDest.trim().isNotEmpty)
              'dropoff_location': requestedDest.trim(),
            'extension_status': 'finalized',
            'extension_finalized_at': DateTime.now().toIso8601String(),
            'extension_finalized_by': finalizerId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: finalizerId,
            content:
                'Trip Extension Finalized: Your trip end date is updated to ${newEndAt.month}/${newEndAt.day}/${newEndAt.year}${requestedDest != null && requestedDest.isNotEmpty ? " (Destination: $requestedDest)" : ""}. New total: PHP ${newTotal.toStringAsFixed(2)}.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error finalizing trip extension: $e');
      rethrow;
    }
  }

  /// Reject trip extension request.
  Future<void> rejectTripExtension({
    required String bookingId,
    String? reviewerId,
    String? operatorId,
    String? reviewerRole,
    String? reason,
  }) async {
    final effectiveReviewerId = reviewerId ?? operatorId ?? '';
    final effectiveRole = reviewerRole ?? (operatorId != null ? 'operator' : 'partner');

    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final isPartnerVehicle = _isPartnerBookingVehicle(vehicle);

      if (isPartnerVehicle && effectiveRole == 'operator') {
        throw Exception(
          'Operator cannot reject extension for a Partner-owned vehicle. Only the Partner can reject.',
        );
      }

      await supabase
          .from('bookings')
          .update({
            'extension_status': 'rejected',
            'extension_rejection_reason':
                reason ?? 'Extension request declined.',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: effectiveReviewerId,
            content:
                'Trip Extension Request Declined${reason != null && reason.isNotEmpty ? ": $reason" : ""}. Please return the vehicle by your original schedule.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error rejecting trip extension: $e');
      rethrow;
    }
  }

  /// Cancel trip extension request (by Renter).
  Future<void> cancelTripExtension({
    required String bookingId,
    required String userId,
  }) async {
    try {
      await supabase
          .from('bookings')
          .update({
            'extension_status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);
    } catch (e) {
      debugPrint('Error cancelling trip extension: $e');
      rethrow;
    }
  }

  /// Fetch all extension requests for an operator or partner.
  Future<List<Map<String, dynamic>>> getExtensionRequests({
    String? operatorId,
    String? partnerId,
  }) async {
    try {
      var query = supabase
          .from('bookings')
          .select('''
            *,
            users:renter_id (*),
            vehicles:vehicle_id (
              *,
              owner:owner_id (*)
            )
          ''')
          .neq('extension_status', 'none')
          .order('extension_requested_at', ascending: false);

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching extension requests: $e');
      return [];
    }
  }

  /// Renter initiates vehicle return and submits final payment settlement.
  Future<void> renterInitiateReturn({
    required String bookingId,
    required String renterId,
    String? paymentMethod,
    String? paymentReference,
    String? proofUrl,
    int? lateHours,
    double? lateFee,
    double? settledAmount,
  }) async {
    try {
      final now = DateTime.now();
      final updates = <String, dynamic>{
        'status': 'return_pending_inspection',
        'returned_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      if (paymentMethod != null && paymentMethod.isNotEmpty) {
        updates['final_payment_method'] = paymentMethod;
      }
      if (paymentReference != null && paymentReference.isNotEmpty) {
        updates['final_payment_reference'] = paymentReference;
      }
      if (proofUrl != null && proofUrl.isNotEmpty) {
        updates['final_payment_proof_url'] = proofUrl;
      }
      if (lateHours != null && lateHours > 0) {
        updates['late_return_hours'] = lateHours;
        updates['late_return_fee'] = lateFee ?? (lateHours * 300.0);
      }
      if (settledAmount != null && settledAmount > 0) {
        updates['renter_return_payment_submitted'] = true;
        updates['renter_return_payment_amount'] = settledAmount;
      }

      try {
        await supabase.from('bookings').update(updates).eq('id', bookingId);
      } catch (dbError) {
        debugPrint(
          'Full update failed, attempting fallback return update: $dbError',
        );
        final fallbackUpdates = <String, dynamic>{
          'status': 'return_pending_inspection',
          'returned_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        if (lateHours != null && lateHours > 0) {
          fallbackUpdates['late_return_hours'] = lateHours;
          fallbackUpdates['late_return_fee'] = lateFee ?? (lateHours * 300.0);
        }
        await supabase
            .from('bookings')
            .update(fallbackUpdates)
            .eq('id', bookingId);
      }

      try {
        final booking = await getBookingById(bookingId);
        final vehicle = booking?['vehicles'] as Map<String, dynamic>?;
        final vehicleTitle = _vehicleTitle(vehicle);
        final renter = booking?['renter'] as Map<String, dynamic>?;
        final renterName =
            renter?['full_name']?.toString().trim().isNotEmpty == true
            ? renter!['full_name'].toString().trim()
            : 'Renter';

        await NotificationService().notifyOperatorsVehicleReturned(
          bookingId: bookingId,
          vehicleTitle: vehicleTitle,
          renterName: renterName,
          paymentMethod: paymentMethod,
          settledAmount: settledAmount,
          partnerId: vehicle?['owner_id']?.toString(),
        );
      } catch (notifError) {
        debugPrint(
          'Could not send return notification to operator: $notifError',
        );
      }
    } catch (e) {
      debugPrint('Error initiating return: $e');
      rethrow;
    }
  }

  /// Operator or Partner confirms vehicle return after inspection.
  Future<void> confirmVehicleReturn({
    required String bookingId,
    required String reviewerId,
    required String reviewerRole,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final now = DateTime.now();
      final endRaw =
          booking['end_at']?.toString() ?? booking['end_date']?.toString();
      final endAt = endRaw != null
          ? DateTime.tryParse(endRaw)?.toLocal()
          : null;
      final returnedAtRaw = booking['returned_at']?.toString();
      final returnedAt =
          (returnedAtRaw != null
              ? DateTime.tryParse(returnedAtRaw)?.toLocal()
              : null) ??
          now;

      double lateReturnFee = 0.0;
      if (endAt != null && returnedAt.isAfter(endAt)) {
        final lateHours = (returnedAt.difference(endAt).inMinutes / 60.0)
            .ceil();
        if (lateHours > 0) {
          lateReturnFee = lateHours * 200.0;
        }
      }

      final currentTotal = (booking['total_price'] as num?)?.toDouble() ?? 0.0;
      final updatedTotal = currentTotal + lateReturnFee;

      final isFullPaymentAtCreation =
          booking['reservation_payment_covers_total'] == true ||
          booking['reservation_payment_type']?.toString().toLowerCase() ==
              'full_payment';
      final extensionFee =
          (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;

      final isFullySettled =
          isFullPaymentAtCreation && lateReturnFee <= 0 && extensionFee <= 0;
      final finalPaymentStatus = isFullySettled ? 'paid' : 'pending';

      final bookingUpdate = <String, dynamic>{
        'status': 'awaiting_completion',
        'return_confirmed_at': now.toIso8601String(),
        'return_confirmed_by': reviewerId,
        'late_return_fee': lateReturnFee,
        'total_price': updatedTotal,
        'final_payment_status': finalPaymentStatus,
        'updated_at': now.toIso8601String(),
      };

      if (!isFullySettled) {
        bookingUpdate['completion_stage'] = 'awaiting_payment';
      }

      await supabase.from('bookings').update(bookingUpdate).eq('id', bookingId);

      await TripRatingService().syncRatingFlowForBooking(bookingId);

      final conversation = await ChatService().getConversationBookingContext(
        bookingId,
      );
      if (conversation != null) {
        final conversationId = conversation['id']?.toString();
        if (conversationId != null) {
          await ChatService().sendMessage(
            conversationId: conversationId,
            senderId: reviewerId,
            content:
                'Vehicle Return Confirmed: Return inspection completed by $reviewerRole. ${lateReturnFee > 0 ? "Late fee applied: PHP ${lateReturnFee.toStringAsFixed(2)}." : "No late fees."}',
          );
        }
      }

      // Automated vehicle unlisting for turnaround / cleaning & inspection
      try {
        final vehicleId = booking['vehicle_id']?.toString();
        if (vehicleId != null && vehicleId.isNotEmpty) {
          final vehicle = booking['vehicles'] as Map<String, dynamic>?;
          final partnerVehicleId = booking['partner_vehicle_id']?.toString() ??
              vehicle?['partner_vehicle_id']?.toString();
          final vehicleTitle = _vehicleTitle(vehicle);
          final partnerId = vehicle?['owner_id']?.toString();

          await VehicleTurnaroundService().handleVehicleReturn(
            vehicleId: vehicleId,
            partnerVehicleId: partnerVehicleId,
            bookingId: bookingId,
            vehicleTitle: vehicleTitle,
            partnerId: partnerId,
          );
        }
      } catch (turnaroundErr) {
        debugPrint('Could not initiate vehicle turnaround: $turnaroundErr');
      }
    } catch (e) {
      debugPrint('Error confirming vehicle return: $e');
      rethrow;
    }
  }

  /// Operator or Admin confirms manual refund disbursement for a cancelled booking.
  /// Updates refund status to 'refunded' and sends instant notifications to the renter and owner.
  Future<Map<String, dynamic>> processRefundDisbursement({
    required String bookingId,
    required String refundReference,
    double? refundAmount,
    String? notes,
    String? operatorId,
  }) async {
    try {
      debugPrint('Processing refund disbursement for booking #$bookingId');

      final cleanRef = refundReference.trim();
      if (cleanRef.isEmpty) {
        throw Exception('Refund transaction reference number is required.');
      }

      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');

      final renterId = booking['renter_id']?.toString() ?? '';
      final vehicle = booking['vehicles'] as Map<String, dynamic>? ??
          booking['vehicle'] as Map<String, dynamic>?;
      final vehicleTitle = vehicle != null
          ? '${vehicle['brand'] ?? vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
          : 'your rental vehicle';

      final amount = refundAmount ??
          (booking['reservation_payment_amount'] as num?)?.toDouble() ??
          (booking['reservation_fee'] as num?)?.toDouble() ??
          (booking['total_amount'] as num?)?.toDouble() ??
          (booking['total_price'] as num?)?.toDouble() ??
          0.0;

      final now = DateTime.now();

      await supabase.from('bookings').update({
        'refund_status': 'refunded',
        'refund_reference': cleanRef,
        'refund_amount': amount,
        'refund_notes': notes?.trim(),
        'refund_processed_at': now.toIso8601String(),
        if (operatorId != null && operatorId.isNotEmpty)
          'refund_operator_id': operatorId,
        'updated_at': now.toIso8601String(),
      }).eq('id', bookingId);

      // 1. Notify Renter
      if (renterId.isNotEmpty) {
        final amountFmt =
            amount > 0 ? ' of PHP ${amount.toStringAsFixed(2)}' : '';
        await NotificationService().createNotification(
          userId: renterId,
          title: '💰 Refund Completed',
          message:
              'Your refund$amountFmt for $vehicleTitle has been disbursed to your account. Reference: $cleanRef.',
          type: 'booking_refund',
          data: {
            'booking_id': bookingId,
            'status': 'cancelled',
            'refund_status': 'refunded',
            'refund_reference': cleanRef,
            'refund_amount': amount,
            'event': 'refund_disbursed',
          },
        );
      }

      // 2. Notify Vehicle Owner if applicable
      final ownerId = vehicle?['owner_id']?.toString();
      if (ownerId != null && ownerId.isNotEmpty && ownerId != renterId) {
        await NotificationService().createNotification(
          userId: ownerId,
          title: 'Booking Refund Disbursed',
          message:
              'Refund for cancelled booking #$bookingId ($vehicleTitle) has been completed. Reference: $cleanRef.',
          type: 'booking',
          data: {
            'booking_id': bookingId,
            'refund_status': 'refunded',
            'event': 'owner_refund_recorded',
          },
        );
      }

      return {
        'success': true,
        'refund_status': 'refunded',
        'refund_reference': cleanRef,
        'refund_amount': amount,
      };
    } catch (e) {
      debugPrint('Error processing refund disbursement: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Reschedules an active/pending booking to new dates, retaining 100% of the deposit.
  Future<void> rescheduleBooking({
    required String bookingId,
    required DateTime newStartAt,
    required DateTime newEndAt,
    String? reason,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) {
        throw Exception('Booking not found');
      }

      final vehicleId = booking['vehicle_id']?.toString() ?? '';
      final currentRescheduleCount = (booking['reschedule_count'] as num?)?.toInt() ?? 0;
      final originalStart = booking['original_start_at'] ?? booking['start_at'];
      final originalEnd = booking['original_end_at'] ?? booking['end_at'];

      // Check vehicle availability on requested dates
      if (vehicleId.isNotEmpty) {
        final conflicts = await supabase
            .from('bookings')
            .select('id, start_at, end_at, status')
            .eq('vehicle_id', vehicleId)
            .neq('id', bookingId)
            .inFilter('status', ['pending', 'approved', 'ongoing'])
            .lte('start_at', newEndAt.toIso8601String())
            .gte('end_at', newStartAt.toIso8601String());

        if (conflicts.isNotEmpty) {
          throw Exception('The selected vehicle is not available for these new dates. Please pick different dates.');
        }
      }

      // Update booking dates and reschedule tracking
      await supabase.from('bookings').update({
        'start_at': newStartAt.toIso8601String(),
        'end_at': newEndAt.toIso8601String(),
        'original_start_at': originalStart,
        'original_end_at': originalEnd,
        'rescheduled_at': DateTime.now().toIso8601String(),
        'reschedule_count': currentRescheduleCount + 1,
        'reschedule_reason': reason ?? 'Renter requested date change',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bookingId);

      // Notify operator & partner
      try {
        final vehicleTitle = booking['vehicles'] != null
            ? '${booking['vehicles']['brand'] ?? ''} ${booking['vehicles']['model'] ?? ''}'
            : 'vehicle';
        await NotificationService().createNotification(
          userId: booking['vehicles']?['owner_id'] ?? booking['operator_id'] ?? '',
          title: 'Booking Rescheduled',
          message: 'Booking for $vehicleTitle was rescheduled to new dates.',
          type: 'booking_rescheduled',
          data: {
            'booking_id': bookingId,
            'new_start': newStartAt.toIso8601String(),
            'new_end': newEndAt.toIso8601String(),
          },
        );
      } catch (e) {
        debugPrint('Notification dispatch note: $e');
      }
    } catch (e) {
      debugPrint('Error rescheduling booking: $e');
      rethrow;
    }
  }

  /// Cancels booking under strict non-refundable policy (deposit is retained & forfeited)
  Future<void> cancelBookingWithDepositForfeit({
    required String bookingId,
    required String cancellationReason,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      final depositAmount = (booking?['reservation_fee_amount'] as num?)?.toDouble() ?? 1000.0;

      await updateBookingStatus(bookingId, 'cancelled');
      await supabase.from('bookings').update({
        'cancellation_reason': cancellationReason,
        'cancelled_at': DateTime.now().toIso8601String(),
        'deposit_forfeited': true,
        'cancellation_fee_retained': depositAmount,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bookingId);
    } catch (e) {
      debugPrint('Error cancelling booking with deposit forfeit: $e');
      rethrow;
    }
  }

  Future<void> refundSecurityDeposit({
    required String bookingId,
    required double refundAmount,
    double deductionAmount = 0.0,
    String? deductionNotes,
    required String refundMethod,
    required String refundReference,
    required String refundReceiptUrl,
    required String operatorId,
  }) async {
    final now = DateTime.now().toUtc();
    await supabase.from('bookings').update({
      'security_deposit_refunded': true,
      'security_deposit_refund_amount': refundAmount,
      'security_deposit_refund_deduction': deductionAmount,
      'security_deposit_refund_notes': deductionNotes,
      'security_deposit_refund_method': refundMethod,
      'security_deposit_refund_ref': refundReference,
      'security_deposit_refund_receipt_url': refundReceiptUrl,
      'security_deposit_refunded_at': now.toIso8601String(),
      'security_deposit_refunded_by': operatorId,
    }).eq('id', bookingId);

    // Fetch booking to notify renter
    try {
      final booking = await supabase
          .from('bookings')
          .select('renter_id, vehicles(brand, model)')
          .eq('id', bookingId)
          .maybeSingle();
      final renterId = booking?['renter_id']?.toString();
      if (renterId != null && renterId.isNotEmpty) {
        final vehicleMap = booking?['vehicles'] as Map<String, dynamic>? ?? {};
        final vehicleName =
            '${vehicleMap['brand'] ?? ''} ${vehicleMap['model'] ?? ''}'.trim();
        await NotificationService().createNotification(
          userId: renterId,
          title: 'Security Deposit Refunded',
          message:
              'Your security deposit of PHP ${refundAmount.toStringAsFixed(0)} for $vehicleName has been successfully refunded via $refundMethod.',
          type: 'deposit_refunded',
          data: {
            'booking_id': bookingId,
            'refund_amount': refundAmount,
            'refund_reference': refundReference,
            'receipt_url': refundReceiptUrl,
          },
        );
      }
    } catch (e) {
      debugPrint('Deposit refund notification error: $e');
    }
  }

  Future<void> setSecurityDepositReturnEligibility({
    required String bookingId,
    required bool isEligible,
    String? ineligibilityReason,
  }) async {
    await supabase.from('bookings').update({
      'security_deposit_return_eligible': isEligible,
      if (ineligibilityReason != null)
        'security_deposit_ineligibility_reason': ineligibilityReason,
    }).eq('id', bookingId);
  }

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
