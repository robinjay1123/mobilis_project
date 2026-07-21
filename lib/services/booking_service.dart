import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'chat_service.dart';
import 'notification_service.dart';
import 'user_restriction_service.dart';
import 'vehicle_service.dart';
import 'booking_inspection_service.dart';
import '../utils/pricing_policy.dart';

class BookingService {
  static final BookingService _instance = BookingService._internal();

  factory BookingService() {
    return _instance;
  }

  BookingService._internal();

  final supabase = Supabase.instance.client;
  static const List<String> _bookingBlockingStatuses = [
    'pending',
    'approved',
    'confirmed',
    'active',
    'ongoing',
  ];

  // Get bookings for a partner (via their vehicles)
  // Note: vehicles use owner_id which references users.id
  Future<List<Map<String, dynamic>>> getPartnerBookings(String userId) async {
    try {
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
          .select('*, vehicles(*), users:users!bookings_renter_id_fkey(*)')
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
          .select('*, vehicles(*), users:users!bookings_renter_id_fkey(*)')
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
    double? deliveryDistanceKm,
    double? deliveryRatePerKm,
    double? deliveryFee,
    bool withDriver = false,
    String? pickupLocation,
    String? dropoffLocation,
    DateTime? rentalTermsAcceptedAt,
    String? rentalTermsSnapshot,
    double? reservationFeeAmount,
    String? reservationPaymentReference,
    String? reservationPaymentProofUrl,
    String? reservationPaymentMethod,
    String? reservationPaymentType,
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

      final restriction = await UserRestrictionService().getUserRestriction(
        renterId,
      );
      if (restriction.isBlocked || restriction.isAccountRestricted) {
        throw Exception(
          'This renter account is restricted and cannot book vehicles right now',
        );
      }

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

      final vehicleState = await supabase
          .from('vehicles')
          .select('id,owner_role,plate_number,is_available,is_posted,status')
          .eq('id', vehicleId)
          .maybeSingle();
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

      final overlappingBookings = await supabase
          .from('bookings')
          .select('id')
          .eq('vehicle_id', vehicleId)
          .inFilter('status', _bookingBlockingStatuses)
          // Half-open overlap rule:
          // overlap if new_start < existing_end AND new_end > existing_start
          .lt('start_at', endAt.toIso8601String())
          .gt('end_at', startAt.toIso8601String())
          .limit(1);

      if (overlappingBookings.isNotEmpty) {
        throw Exception('Selected dates are unavailable for bookings');
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
        if (deliveryDistanceKm != null)
          'delivery_distance_km': deliveryDistanceKm,
        if (deliveryRatePerKm != null)
          'delivery_rate_per_km': deliveryRatePerKm,
        'delivery_fee': deliveryFee ?? 0,
        'with_driver': withDriver,
        'pickup_location': pickupLocation,
        'dropoff_location': cleanDestination,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

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

      final response = await supabase
          .from('bookings')
          .insert(bookingPayload)
          .select()
          .single();

      try {
        final bookingId = response['id']?.toString();
        if (bookingId != null && bookingId.isNotEmpty) {
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
        }
      } catch (e) {
        debugPrint('Booking created but operator notification failed: $e');
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
        'operator': completionStage == 'operator_rating',
        'partner': completionStage == 'partner_rating',
        'driver': completionStage == 'driver_rating',
        'renter': completionStage == 'renter_rating',
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
    final expectedRole = state['firstReviewerRole']?.toString() ?? 'operator';
    final normalizedRole = actorRole.trim().toLowerCase();
    if (normalizedRole != expectedRole) {
      throw Exception(
        expectedRole == 'partner'
            ? 'Only the vehicle partner can confirm this final payment'
            : 'Only the PSDC operator can confirm this final payment',
      );
    }
    final stage = state['completionStage']?.toString() ?? '';
    if (stage != 'awaiting_payment' && stage != '${expectedRole}_rating') {
      throw Exception('The vehicle return checklist is not ready for payment');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('bookings')
        .update({
          'final_payment_status': 'paid',
          'final_payment_confirmed_at': now,
          'final_payment_confirmed_by': actorId,
          'completion_stage': '${expectedRole}_rating',
          'updated_at': now,
        })
        .eq('id', bookingId);

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
          .select('*, vehicles(*), users:users!bookings_renter_id_fkey(*)')
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

  // ================== OPERATOR WORKFLOW ==================

  /// Get all pending bookings for operator approval
  Future<List<Map<String, dynamic>>> getPendingBookings() async {
    try {
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

  /// Approve booking (operator action)
  Future<void> approveBooking(String bookingId, String operatorNotes) async {
    try {
      debugPrint('Approving booking: $bookingId');
      final operatorId = supabase.auth.currentUser?.id;
      await supabase
          .from('bookings')
          .update({
            'status': 'approved',
            if (operatorId != null && operatorId.isNotEmpty)
              'operator_id': operatorId,
            'operator_notes': operatorNotes,
            'approved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      await ensureBookingConversationForActiveBooking(
        bookingId: bookingId,
        operatorId: operatorId,
      );

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
    double tripFee,
  ) async {
    try {
      debugPrint(
        'Assigning driver $driverId to booking $bookingId with fee: $tripFee',
      );

      final booking = await supabase
          .from('bookings')
          .select('id, with_driver, status, renter_id')
          .eq('id', bookingId)
          .maybeSingle();

      if (booking == null) {
        throw Exception('Booking not found');
      }

      final driver = await _getDriverAssignmentTarget(driverId);
      if (driver == null) {
        throw Exception('Selected user is not a valid driver');
      }

      if (_isExplicitlyUnavailable(driver['is_available'])) {
        throw Exception('Selected driver is not available');
      }

      final driverProfileId = driver['driver_id']?.toString();
      final driverUserId = driver['user_id']?.toString();
      if (driverProfileId == null ||
          driverProfileId.isEmpty ||
          driverUserId == null ||
          driverUserId.isEmpty) {
        throw Exception('Selected driver is missing profile linkage');
      }

      final currentStatus =
          booking['status']?.toString().trim().toLowerCase() ?? '';

      if (!{'pending', 'approved'}.contains(currentStatus)) {
        throw Exception(
          'A driver can only be selected before the booking is finalized',
        );
      }

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
        await supabase
            .from('bookings')
            .update({
              'driver_id': driverUserId,
              'with_driver': true,
              'status': 'pending',
              'driver_assigned_at': now,
              'updated_at': now,
            })
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
    if (!{'pending', 'approved', 'confirmed'}.contains(currentStatus)) {
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
  }) async {
    try {
      final targetDate = (bookingDate ?? DateTime.now()).toLocal();
      final scheduleDate =
          '${targetDate.year.toString().padLeft(4, '0')}-'
          '${targetDate.month.toString().padLeft(2, '0')}-'
          '${targetDate.day.toString().padLeft(2, '0')}';
      final todayScheduleResponse = await supabase
          .from('driver_availability_schedule')
          .select('driver_id')
          .eq('date', scheduleDate)
          .eq('is_available', true);
      final anyScheduleResponse = await supabase
          .from('driver_availability_schedule')
          .select('driver_id')
          .eq('is_available', true);
      final availableTodayDriverIds = List<Map<String, dynamic>>.from(
        todayScheduleResponse,
      ).map((row) => row['driver_id']?.toString()).whereType<String>().toSet();
      final scheduledDriverIds = List<Map<String, dynamic>>.from(
        anyScheduleResponse,
      ).map((row) => row['driver_id']?.toString()).whereType<String>().toSet();

      final response = await supabase
          .from('drivers')
          .select(
            'id, user_id, verification_status, driver_tier, rating, total_trips, users!drivers_user_id_fkey(id, full_name, email, phone, role, is_available, id_verified, verification_status, application_status, avatar_url, profile_picture_url, location, latitude, longitude)',
          );

      final drivers = List<Map<String, dynamic>>.from(response)
          .where((driver) {
            final user = driver['users'] as Map<String, dynamic>?;
            if (user == null) return false;

            final role = user['role']?.toString().trim().toLowerCase() ?? '';
            if (role.isNotEmpty && role != 'driver') return false;

            final driverUserId = driver['user_id']?.toString();
            final hasDateSchedule = scheduledDriverIds.contains(driverUserId);
            final isAvailable = hasDateSchedule
                ? availableTodayDriverIds.contains(driverUserId)
                : user['is_available'] == true;
            final isVerified =
                _isVerifiedDriverStatus(driver['verification_status']) ||
                _isVerifiedDriverStatus(user['verification_status']) ||
                user['id_verified'] == true;
            final isCertified =
                user['application_status']?.toString().trim().toLowerCase() ==
                'approved';

            return isAvailable && isVerified && isCertified;
          })
          .map((driver) {
            final normalized = Map<String, dynamic>.from(driver);
            final user = driver['users'] as Map<String, dynamic>? ?? {};
            final latitude = (user['latitude'] as num?)?.toDouble();
            final longitude = (user['longitude'] as num?)?.toDouble();
            if (latitude != null &&
                longitude != null &&
                proximityTargets.isNotEmpty) {
              final distances = proximityTargets.map(
                (target) => _distanceInKilometers(
                  latitude,
                  longitude,
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
      if (currentUserId == null ||
          assignedDriverId == null ||
          assignedDriverId != currentUserId) {
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

      final driverUserId = booking['driver_id']?.toString();
      if (driverUserId != null && driverUserId.isNotEmpty) {
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
            .eq('driver_id', currentUserId);
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
  /// submits the after checklist. Completion waits for payment and ratings.
  Future<void> completeBookingAfterInspection({
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
      inspectionType: 'after',
    );

    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');
    final status = booking['status']?.toString().trim().toLowerCase() ?? '';
    if (status != 'active' &&
        status != 'ongoing' &&
        status != 'return_pending_inspection') {
      if (status == 'completed') return;
      throw Exception('Only ongoing bookings can complete a return checklist');
    }
    await _postInspectionAuditToBookingChat(
      booking: booking,
      inspection: inspection,
      inspectionType: 'after',
    );

    final returnedAt = DateTime.now();
    final now = returnedAt.toIso8601String();
    final lateReturn = _lateReturnValues(booking, returnedAt);
    final actor = await supabase
        .from('users')
        .select('role')
        .eq('id', inspectorId)
        .maybeSingle();
    final actorRole = actor?['role']?.toString().trim().toLowerCase();
    final firstReviewerRole = actorRole == 'partner' ? 'partner' : 'operator';
    final coversTotal = booking['reservation_payment_covers_total'] == true;
    final lateFee = lateReturn['late_return_fee'] as double;
    final isFullyPaid = coversTotal && lateFee <= 0;
    final completionStage = isFullyPaid
        ? '${firstReviewerRole}_rating'
        : 'awaiting_payment';

    await supabase
        .from('bookings')
        .update({
          'status': 'awaiting_completion',
          'returned_at': now,
          'completed_at': null,
          'completion_stage': completionStage,
          'final_payment_status': isFullyPaid ? 'paid' : 'pending',
          if (isFullyPaid) 'final_payment_confirmed_at': now,
          if (isFullyPaid) 'final_payment_confirmed_by': inspectorId,
          ...lateReturn,
          'updated_at': now,
        })
        .eq('id', bookingId);

    final driverId = booking['driver_id']?.toString();
    if (driverId?.isNotEmpty == true) {
      await supabase
          .from('users')
          .update({'is_available': true})
          .eq('id', driverId!);
      try {
        await supabase
            .from('driver_job_assignments')
            .update({'status': 'awaiting_completion', 'updated_at': now})
            .eq('booking_id', bookingId)
            .eq('driver_id', driverId);
      } catch (e) {
        debugPrint('Could not complete driver assignment: $e');
      }
    }

    final renterId = booking['renter_id']?.toString();
    if (renterId?.isNotEmpty == true) {
      await NotificationService().createNotification(
        userId: renterId!,
        title: isFullyPaid
            ? 'Vehicle Returned - Rating Required'
            : 'Vehicle Returned - Final Payment Required',
        message:
            'The after-return checklist is complete. The trip will be completed after full payment and all required ratings. Late fee: ${PricingPolicy.peso(lateFee)}.',
        type: 'booking_awaiting_completion',
        data: {'booking_id': bookingId, 'vehicle_id': booking['vehicle_id']},
      );
    }

    final vehicle = booking['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    String? firstReviewerId;
    if (firstReviewerRole == 'partner') {
      firstReviewerId = vehicle['owner_id']?.toString();
    } else {
      firstReviewerId = booking['operator_id']?.toString().trim();
      if (firstReviewerId == null || firstReviewerId.isEmpty) {
        firstReviewerId = inspectorId;
      }
    }
    if (isFullyPaid && firstReviewerId?.isNotEmpty == true) {
      await NotificationService().createNotification(
        userId: firstReviewerId!,
        title: 'Mandatory Renter Rating Required',
        message:
            'The return checklist and payment are complete. Rate the renter to continue trip completion.',
        type: 'trip_rating_required',
        data: {'booking_id': bookingId, 'reviewer_role': firstReviewerRole},
      );
    }
  }

  Future<void> _postInspectionAuditToBookingChat({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> inspection,
    required String inspectionType,
  }) async {
    final bookingId = booking['id']?.toString() ?? '';
    final inspectorId = inspection['inspector_id']?.toString() ?? '';
    if (bookingId.isEmpty || inspectorId.isEmpty) return;

    await _ensureBookingGroupChatAndSummary(
      booking: booking,
      vehicleTitle: _vehicleTitle(booking['vehicles'] as Map<String, dynamic>?),
      summaryTitle: 'Booking Confirmed',
    );
    final conversation = await ChatService().getConversationByBookingId(
      bookingId,
    );
    final conversationId = conversation?['id']?.toString() ?? '';
    if (conversationId.isEmpty) {
      throw Exception('The booking conversation could not be prepared');
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
        : const <dynamic>[];
    final checklist = inspection['checklist_items'] is Map
        ? Map<String, dynamic>.from(inspection['checklist_items'] as Map)
        : const <String, dynamic>{};
    final checkedCount = checklist.values
        .where((value) => value == true)
        .length;
    final evidenceUrl = evidence.isEmpty ? null : evidence.first.toString();
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
      '',
      isBefore
          ? 'The vehicle release record is now visible to every booking participant.'
          : 'The vehicle return record is now visible to every booking participant.',
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
          : '${isBefore ? 'before-release' : 'after-return'}-evidence',
    );
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
        status == 'certified';
  }

  Future<Map<String, dynamic>?> _getDriverAssignmentTarget(
    String driverIdOrUserId,
  ) async {
    Map<String, dynamic>? driver = await supabase
        .from('drivers')
        .select(
          'id, user_id, verification_status, users!drivers_user_id_fkey(id, full_name, role, is_available)',
        )
        .eq('id', driverIdOrUserId)
        .maybeSingle();

    driver ??= await supabase
        .from('drivers')
        .select(
          'id, user_id, verification_status, users!drivers_user_id_fkey(id, full_name, role, is_available)',
        )
        .eq('user_id', driverIdOrUserId)
        .maybeSingle();

    if (driver == null) return null;

    final user = driver['users'] as Map<String, dynamic>?;
    final role = user?['role']?.toString().toLowerCase();
    if (role != 'driver') return null;

    return {
      'driver_id': driver['id'],
      'user_id': driver['user_id'],
      'verification_status': driver['verification_status'],
      'full_name': user?['full_name'],
      'is_available': user?['is_available'],
    };
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
    if (ownerId != null && ownerId.isNotEmpty) participantIds.add(ownerId);
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

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
