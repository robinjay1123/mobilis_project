import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'auto_message_service.dart';

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
          .select('*, vehicles(*), users(*)')
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
          .select('*, vehicles(*), users(*)')
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
          .select('*, vehicles(*)')
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
          .select('*, vehicles(*), users(*)')
          .eq('id', bookingId)
          .maybeSingle();

      debugPrint('Booking fetched: ${response != null}');
      return response;
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
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
    bool withDriver = false,
    String? pickupLocation,
    String? dropoffLocation,
  }) async {
    try {
      debugPrint('Creating booking for renter: $renterId, vehicle: $vehicleId');

      final response = await supabase
          .from('bookings')
          .insert({
            'renter_id': renterId,
            'vehicle_id': vehicleId,
            'start_date': startDate.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'total_price': totalPrice,
            'with_driver': withDriver,
            'pickup_location': pickupLocation,
            'dropoff_location': dropoffLocation,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint('Booking created successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating booking: ${e.message}');
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

      await supabase
          .from('bookings')
          .update({
            'status': status,
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
        if (booking['renter_id'] != null) {
          try {
            await supabase.from('notifications').insert({
              'user_id': booking['renter_id'],
              'title': '✅ Booking Approved!',
              'message':
                  'Your booking for $vehicleTitle has been approved by the owner.',
              'type': 'booking',
              'data': {'booking_id': bookingId, 'status': status},
              'created_at': DateTime.now().toIso8601String(),
            });
            debugPrint('✅ Approval notification sent to renter');
          } catch (e) {
            debugPrint('⚠️ Error sending approval notification: $e');
          }
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

      // Create auto-message once booking is accepted by operator/owner.
      if ((status == 'confirmed' || status == 'approved') &&
          booking['conversation_created'] != true) {
        try {
          debugPrint(
            'Creating auto-message conversation for booking: $bookingId',
          );

          final result = await AutoMessageService.createBookingConversation(
            bookingId: bookingId,
            renterId: booking['renter_id'] as String,
            recipientId:
                booking['partner_id'] as String? ??
                vehicle?['owner_id'] as String? ??
                '',
            vehicleTitle: vehicleTitle,
            pickupDate: booking['start_date']?.toString() ?? '',
            dropoffDate: booking['end_date']?.toString() ?? '',
          );

          if (result['success'] == true) {
            // Mark conversation as created
            await supabase
                .from('bookings')
                .update({'conversation_created': true})
                .eq('id', bookingId);
            debugPrint('Auto-message conversation created and marked');
          }
        } catch (e) {
          debugPrint('Error creating auto-message conversation: $e');
          // Don't fail the booking update if auto-message fails
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
          .select('*, vehicles(*), users(*)')
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
            'id, renter_id, vehicle_id, start_date, end_date, status, total_price, created_at, vehicles(brand, model, year, plate_number, owner_id), users(full_name, email, phone)',
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

      if (booking['with_driver'] != true) {
        throw Exception(
          'Driver assignment is only allowed for with-driver bookings',
        );
      }

      final driver = await supabase
          .from('users')
          .select('id, role, is_available, full_name')
          .eq('id', driverId)
          .maybeSingle();

      if (driver == null || (driver['role'] as String?) != 'driver') {
        throw Exception('Selected user is not a valid driver');
      }

      if (driver['is_available'] == false) {
        throw Exception('Selected driver is not available');
      }

      // Update booking with driver
      await supabase
          .from('bookings')
          .update({
            'driver_id': driverId,
            'trip_fee': tripFee,
            'driver_assigned_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      debugPrint('Driver assigned to booking');

      // ✅ Send notification to renter about driver assignment
      try {
        final driverName = driver['full_name'] ?? 'Driver';
        await supabase.from('notifications').insert({
          'user_id': booking['renter_id'],
          'title': '🚗 Driver Assigned',
          'message': '$driverName has been assigned as your driver.',
          'type': 'booking',
          'data': {
            'booking_id': bookingId,
            'driver_id': driverId,
            'action': 'driver_assigned',
          },
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('✅ Driver assignment notification sent to renter');
      } catch (e) {
        debugPrint('⚠️ Error sending driver assignment notification: $e');
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
          .update({
            'driver_id': null,
            'trip_fee': null,
            'driver_assigned_at': null,
          })
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
            'id, renter_id, vehicle_id, start_date, end_date, status, total_price, pickup_location, dropoff_location, created_at, vehicles(brand, model, year, plate_number), users(full_name, email)',
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
