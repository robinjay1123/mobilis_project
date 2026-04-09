import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

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

      await supabase
          .from('bookings')
          .update({'status': status})
          .eq('id', bookingId);

      debugPrint('Booking status updated');
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
        'confirmed': 0,
        'active': 0,
        'completed': 0,
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
        'confirmed': 0,
        'active': 0,
        'completed': 0,
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

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
