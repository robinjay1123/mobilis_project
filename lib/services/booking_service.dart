import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'chat_service.dart';
import 'notification_service.dart';

class BookingService {
  static final BookingService _instance = BookingService._internal();

  factory BookingService() {
    return _instance;
  }

  BookingService._internal();

  final supabase = Supabase.instance.client;

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
              operator_id,
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
            )
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
          .select('*, vehicles(*)')
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
  }) async {
    try {
      debugPrint('Creating booking for renter: $renterId, vehicle: $vehicleId');

      final overlappingBookings = await supabase
          .from('bookings')
          .select('id')
          .eq('vehicle_id', vehicleId)
          .inFilter('status', ['pending', 'approved', 'confirmed', 'active'])
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
        'with_driver': withDriver,
        'pickup_location': pickupLocation,
        'dropoff_location': dropoffLocation,
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
          await _ensureBookingGroupChatAndSummary(
            booking: createdBooking,
            vehicleTitle: vehicleTitle,
            summaryTitle: 'Booking Request Created',
          );
        }
      } catch (e) {
        debugPrint('Booking created but conversation setup failed: $e');
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

      // Get booking details before updating
      final booking = await getBookingById(bookingId);
      if (booking == null) {
        throw Exception('Booking not found: $bookingId');
      }

      if (status == 'cancelled') {
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
            'status': status,
            if (status == 'cancelled') 'refund_status': 'refund_needed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      debugPrint('Booking status updated');

      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final vehicleTitle = vehicle != null
          ? '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
          : 'Your rental vehicle';

      // ✅ Send notifications based on status change
      if (status == 'approved') {
        // Notify renter of approval
        final renterId = booking['renter_id']?.toString();
        if (renterId != null && renterId.isNotEmpty) {
          await NotificationService().notifyBookingApproved(
            renterId: renterId,
            bookingId: bookingId,
            vehicleTitle: vehicleTitle,
          );
        }
      } else if (status == 'rejected') {
        // Notify renter of rejection
        if (booking['renter_id'] != null) {
          try {
            await supabase.from('notifications').insert({
              'user_id': booking['renter_id'],
              'title': '❌ Booking Rejected',
              'message': 'Your booking for $vehicleTitle has been rejected.',
              'type': 'booking',
              'data': {'booking_id': bookingId, 'status': status},
              'created_at': DateTime.now().toIso8601String(),
            });
            debugPrint('✅ Rejection notification sent to renter');
          } catch (e) {
            debugPrint('⚠️ Error sending rejection notification: $e');
          }
        }
      } else if (status == 'cancelled') {
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
                      'status': status,
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
                'status': status,
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

      // Create booking group chat + summary once booking is accepted.
      if ((status == 'confirmed' || status == 'approved') &&
          booking['conversation_created'] != true) {
        try {
          await _ensureBookingGroupChatAndSummary(
            booking: booking,
            vehicleTitle: vehicleTitle,
            summaryTitle:
                'Booking ${status == 'approved' ? 'Approved' : 'Confirmed'}',
          );
        } catch (e) {
          debugPrint('Error creating booking group chat summary: $e');
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
      await supabase
          .from('bookings')
          .update({
            'status': 'approved',
            'operator_notes': operatorNotes,
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

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

      // Update booking with driver. If a partner assigns directly from a
      // pending request, make it visible as an approved assigned trip.
      final updatePayload = <String, dynamic>{
        'driver_id': driverProfileId,
        'with_driver': true,
        'driver_assigned_at': DateTime.now().toIso8601String(),
        if (currentStatus == 'pending') 'status': 'approved',
        'updated_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('bookings').update(updatePayload).eq('id', bookingId);

      try {
        await supabase.from('driver_job_assignments').insert({
          'booking_id': bookingId,
          'driver_id': driverProfileId,
          'trip_fee': tripFee,
          'status': 'assigned',
          'assigned_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Driver assignment job record skipped: $e');
      }

      await supabase
          .from('users')
          .update({'is_available': false})
          .eq('id', driverUserId);

      try {
        final currentUserId = supabase.auth.currentUser?.id;
        await ChatService().addParticipantsToBookingConversation(
          bookingId: bookingId,
          participantIds: [
            driverUserId,
            if (currentUserId != null && currentUserId.isNotEmpty)
              currentUserId,
          ],
        );

        final bookingAfterAssign = await getBookingById(bookingId);
        if (bookingAfterAssign != null) {
          final chatSenderId =
              currentUserId ??
              bookingAfterAssign['renter_id']?.toString() ??
              driverUserId;
          final renter = bookingAfterAssign['users'] as Map<String, dynamic>?;
          final renterName = renter?['full_name']?.toString() ?? 'Renter';
          final driverName = driver['full_name']?.toString() ?? 'Driver';
          final driverMessage =
              'Driver assigned: $driverName\n'
              'Renter: $renterName (${bookingAfterAssign['renter_id'] ?? 'n/a'})\n'
              'Pickup: ${bookingAfterAssign['pickup_location'] ?? 'N/A'}\n'
              'Drop-off: ${bookingAfterAssign['dropoff_location'] ?? 'N/A'}';
          await _sendBookingGroupMessage(
            bookingId: bookingId,
            senderId: chatSenderId,
            content: driverMessage,
          );
        }
      } catch (e) {
        debugPrint('Could not add driver to group chat: $e');
      }

      debugPrint('Driver assigned to booking');

      // ✅ Send notification to renter about driver assignment
      try {
        final driverName = driver['full_name'] ?? 'Driver';
        final renterId = booking['renter_id']?.toString();
        if (renterId != null && renterId.isNotEmpty) {
          await NotificationService().createNotification(
            userId: renterId,
            title: 'Driver Assigned',
            message: '$driverName has been assigned as your driver.',
            type: 'booking',
            data: {
              'booking_id': bookingId,
              'driver_id': driverUserId,
              'event': 'driver_assigned_to_booking',
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

  /// Unassign driver from booking
  Future<void> unassignDriver(String bookingId) async {
    try {
      debugPrint('Unassigning driver from booking: $bookingId');
      await supabase
          .from('bookings')
          .update({'driver_id': null, 'driver_assigned_at': null})
          .eq('id', bookingId);

      debugPrint('Driver unassigned from booking');
    } on PostgrestException catch (e) {
      debugPrint('Database error unassigning driver: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error unassigning driver: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableVerifiedDrivers() async {
    try {
      final response = await supabase
          .from('drivers')
          .select(
            'id, user_id, verification_status, driver_tier, users!drivers_user_id_fkey(id, full_name, email, role, is_available, id_verified, verification_status)',
          );

      final drivers = List<Map<String, dynamic>>.from(response).where((driver) {
        final user = driver['users'] as Map<String, dynamic>?;
        if (user == null) return false;

        final role = user['role']?.toString().trim().toLowerCase() ?? '';
        if (role.isNotEmpty && role != 'driver') return false;

        final isAvailable = user['is_available'] == true;
        final isVerified =
            _isVerifiedDriverStatus(driver['verification_status']) ||
            _isVerifiedDriverStatus(user['verification_status']) ||
            user['id_verified'] == true;

        return isAvailable && isVerified;
      }).toList();

      drivers.sort((a, b) {
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
      final currentDriverProfileId = currentUserId == null
          ? null
          : await _getDriverProfileIdForUser(currentUserId);
      if (currentUserId == null ||
          assignedDriverId == null ||
          currentDriverProfileId == null ||
          assignedDriverId != currentDriverProfileId) {
        throw Exception('Only the assigned driver can mark pickup time');
      }

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
            .eq('driver_id', currentDriverProfileId);
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
      if (status != 'active' && status != 'confirmed' && status != 'approved') {
        throw Exception('Only confirmed or active bookings can be returned');
      }

      final currentUserId = supabase.auth.currentUser?.id;
      final assignedDriverId = booking['driver_id']?.toString();
      final withDriver = booking['with_driver'] == true;
      if (!withDriver) {
        throw Exception(
          'Return updates are only allowed for with-driver bookings',
        );
      }
      final currentDriverProfileId = currentUserId == null
          ? null
          : await _getDriverProfileIdForUser(currentUserId);
      if (currentUserId == null ||
          assignedDriverId == null ||
          currentDriverProfileId == null ||
          assignedDriverId != currentDriverProfileId) {
        throw Exception('Only the assigned driver can mark return time');
      }

      final startDate = DateTime.tryParse(
        booking['start_date']?.toString() ?? '',
      );
      final scheduledEndDate = DateTime.tryParse(
        booking['end_date']?.toString() ?? '',
      );
      if (startDate == null || scheduledEndDate == null) {
        throw Exception('Booking dates are incomplete');
      }

      final originalTotal =
          (booking['total_price'] as num?)?.toDouble() ??
          (booking['total_cost'] as num?)?.toDouble() ??
          0.0;
      final bookedDays = _inclusiveRentalDays(startDate, scheduledEndDate);
      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final dailyRate =
          _asDouble(vehicle?['price_per_day']) ??
          (bookedDays > 0 ? originalTotal / bookedDays : originalTotal);
      final actualDays = _inclusiveRentalDays(startDate, returnedAt);
      final recalculatedTotal = actualDays == bookedDays
          ? originalTotal
          : dailyRate * actualDays;

      await supabase
          .from('bookings')
          .update({
            'status': 'completed',
            'returned_at': returnedAt.toIso8601String(),
            'completed_at': DateTime.now().toIso8601String(),
            'total_price': recalculatedTotal,
            'total_cost': recalculatedTotal,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final driverId = booking['driver_id']?.toString();
      final driverUserId = driverId == null || driverId.isEmpty
          ? null
          : await _getDriverUserIdForProfile(driverId);
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
              'status': 'completed',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('booking_id', bookingId)
            .eq('driver_id', currentDriverProfileId);
      } catch (e) {
        debugPrint('Could not update assignment status to completed: $e');
      }

      await _notifyOperatorsForBooking(
        booking,
        title: 'Unit Returned',
        message:
            'The driver marked the unit as returned. Final total: PHP ${recalculatedTotal.toStringAsFixed(0)}.',
        action: 'returned',
      );

      try {
        await ChatService().closeConversation(bookingId);
      } catch (e) {
        debugPrint('Could not close booking conversation: $e');
      }

      debugPrint('Booking completed with total: $recalculatedTotal');
      return recalculatedTotal;
    } on PostgrestException catch (e) {
      debugPrint('Database error completing return: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error completing return: $e');
      rethrow;
    }
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
        : await _getDriverUserIdForProfile(driverId);
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
