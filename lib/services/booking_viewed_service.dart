import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service to track which bookings have been viewed by operators and admins.
/// When a new booking is created, it will be marked as unviewed until the operator/admin
/// visits the Bookings section or opens the booking, at which point the red mark/badge disappears.
class BookingViewedService {
  static final BookingViewedService _instance =
      BookingViewedService._internal();
  factory BookingViewedService() => _instance;
  BookingViewedService._internal();

  String _getKey(String role, String? userId) {
    if (userId != null && userId.isNotEmpty) {
      return 'viewed_booking_ids_${role}_$userId';
    }
    return 'viewed_booking_ids_$role';
  }

  /// Get the set of booking IDs that have already been viewed by this user.
  Future<Set<String>> getViewedBookingIds({
    required String role,
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_getKey(role, userId)) ?? [];
      return list.toSet();
    } catch (e) {
      debugPrint('Error getting viewed booking IDs: $e');
      return {};
    }
  }

  /// Check if a specific booking has been viewed.
  Future<bool> isBookingViewed(
    String bookingId, {
    required String role,
    String? userId,
  }) async {
    if (bookingId.isEmpty) return true;
    final viewed = await getViewedBookingIds(role: role, userId: userId);
    return viewed.contains(bookingId);
  }

  /// Mark a single booking as viewed.
  Future<void> markBookingAsViewed(
    String bookingId, {
    required String role,
    String? userId,
  }) async {
    if (bookingId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(role, userId);
      final set = (prefs.getStringList(key) ?? []).toSet();
      if (!set.contains(bookingId)) {
        set.add(bookingId);
        final list = set.toList();
        if (list.length > 2000) {
          list.removeRange(0, list.length - 2000);
        }
        await prefs.setStringList(key, list);
      }
    } catch (e) {
      debugPrint('Error marking booking $bookingId as viewed: $e');
    }
  }

  /// Mark a batch of bookings as viewed.
  Future<void> markAllBookingsAsViewed(
    Iterable<String> bookingIds, {
    required String role,
    String? userId,
  }) async {
    final validIds = bookingIds.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(role, userId);
      final set = (prefs.getStringList(key) ?? []).toSet();
      set.addAll(validIds);
      final list = set.toList();
      if (list.length > 2000) {
        list.removeRange(0, list.length - 2000);
      }
      await prefs.setStringList(key, list);
    } catch (e) {
      debugPrint('Error marking all bookings as viewed: $e');
    }
  }

  /// Return all booking IDs from [bookingIds] that have NOT been viewed yet.
  Future<Set<String>> getUnviewedBookingIds(
    Iterable<String> bookingIds, {
    required String role,
    String? userId,
  }) async {
    final viewed = await getViewedBookingIds(role: role, userId: userId);
    return bookingIds
        .where((id) => id.isNotEmpty && !viewed.contains(id))
        .toSet();
  }

  /// Count how many bookings from [bookingIds] have not been viewed yet.
  Future<int> countUnviewedBookings(
    Iterable<String> bookingIds, {
    required String role,
    String? userId,
  }) async {
    final unviewed = await getUnviewedBookingIds(
      bookingIds,
      role: role,
      userId: userId,
    );
    return unviewed.length;
  }
}
