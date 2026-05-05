import 'package:flutter/foundation.dart';
import 'admin_service.dart';
import 'auth_service.dart';

/// Helper utility for logging operator activities
///
/// This simplifies logging operator movements and actions in operator screens.
///
/// Example usage:
/// ```dart
/// await OperatorActivityLogger.logActivity(
///   context: context,
///   activityType: 'booking_approved',
///   description: 'Approved booking BK-123',
///   bookingId: 'booking-123',
/// );
/// ```
class OperatorActivityLogger {
  static final AdminService _adminService = AdminService();
  static final AuthService _authService = AuthService();

  /// Log an operator activity with automatic error handling
  static Future<bool> logActivity({
    required String activityType,
    String? description,
    String? bookingId,
    String? driverId,
    Map<String, dynamic>? metadata,
    bool suppressErrors = false,
  }) async {
    try {
      final operatorId = _authService.currentUser?.id;

      if (operatorId == null) {
        if (!suppressErrors) {
          debugPrint('Cannot log activity: No operator logged in');
        }
        return false;
      }

      final result = await _adminService.logOperatorActivity(
        operatorId: operatorId,
        activityType: activityType,
        description: description ?? activityType,
        bookingId: bookingId,
        driverId: driverId,
        metadata: metadata,
      );

      if (result) {
        debugPrint('✓ Logged operator activity: $activityType');
      } else {
        if (!suppressErrors) {
          debugPrint('✗ Failed to log operator activity: $activityType');
        }
      }

      return result;
    } catch (e) {
      if (!suppressErrors) {
        debugPrint('Error logging operator activity: $e');
      }
      return false;
    }
  }

  /// Log operator login
  static Future<bool> logLogin({String? description}) async {
    return logActivity(
      activityType: 'login',
      description: description ?? 'Operator logged in',
    );
  }

  /// Log operator logout
  static Future<bool> logLogout({String? description}) async {
    return logActivity(
      activityType: 'logout',
      description: description ?? 'Operator logged out',
    );
  }

  /// Log booking approval
  static Future<bool> logBookingApproved({
    required String bookingId,
    String? reason,
    double? totalPrice,
  }) async {
    return logActivity(
      activityType: 'booking_approved',
      description: reason ?? 'Booking approved',
      bookingId: bookingId,
      metadata: {
        if (totalPrice != null) 'total_price': totalPrice,
        'approval_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log booking rejection
  static Future<bool> logBookingRejected({
    required String bookingId,
    String? reason,
  }) async {
    return logActivity(
      activityType: 'booking_rejected',
      description: reason ?? 'Booking rejected',
      bookingId: bookingId,
      metadata: {
        'rejection_reason': reason ?? 'No reason provided',
        'rejection_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log driver assignment
  static Future<bool> logDriverAssigned({
    required String bookingId,
    required String driverId,
    required double tripFee,
    String? driverName,
  }) async {
    return logActivity(
      activityType: 'driver_assigned',
      description: 'Assigned driver to booking',
      bookingId: bookingId,
      driverId: driverId,
      metadata: {
        'trip_fee': tripFee,
        'driver_name': driverName,
        'assignment_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log driver removal
  static Future<bool> logDriverRemoved({
    required String bookingId,
    required String driverId,
    String? reason,
  }) async {
    return logActivity(
      activityType: 'driver_removed',
      description: reason ?? 'Removed driver from booking',
      bookingId: bookingId,
      driverId: driverId,
      metadata: {
        'removal_reason': reason ?? 'No reason provided',
        'removal_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log profile update
  static Future<bool> logProfileUpdated({String? fieldName}) async {
    return logActivity(
      activityType: 'profile_updated',
      description: fieldName != null
          ? 'Updated $fieldName'
          : 'Updated operator profile',
      metadata: {
        'updated_field': fieldName,
        'update_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get operator activity history
  static Future<List<Map<String, dynamic>>> getActivityHistory({
    String? operatorId,
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final id = operatorId ?? _authService.currentUser?.id;

      if (id == null) {
        debugPrint('Cannot get activity history: No operator ID provided');
        return [];
      }

      return await _adminService.getOperatorActivityHistory(
        id,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('Error getting activity history: $e');
      return [];
    }
  }

  /// Get operator activity summary
  static Future<Map<String, dynamic>> getActivitySummary({
    String? operatorId,
  }) async {
    try {
      final id = operatorId ?? _authService.currentUser?.id;

      if (id == null) {
        debugPrint('Cannot get activity summary: No operator ID provided');
        return {};
      }

      return await _adminService.getOperatorActivitySummary(id);
    } catch (e) {
      debugPrint('Error getting activity summary: $e');
      return {};
    }
  }
}
