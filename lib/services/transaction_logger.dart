import 'package:flutter/foundation.dart';
import 'admin_service.dart';
import 'auth_service.dart';

/// Helper utility for logging renter, driver, and partner transactions
///
/// This simplifies logging booking and transaction events across the app.
///
/// Example usage:
/// ```dart
/// // Renter creates booking
/// await TransactionLogger.logRenterTransaction(
///   transactionType: 'booking_created',
///   description: 'Created booking for vehicle',
///   bookingId: 'booking-123',
///   vehicleId: 'vehicle-456',
/// );
///
/// // Driver accepts job
/// await TransactionLogger.logDriverTransaction(
///   transactionType: 'job_accepted',
///   description: 'Accepted job for booking',
///   bookingId: 'booking-123',
/// );
///
/// // Partner's vehicle rented
/// await TransactionLogger.logPartnerTransaction(
///   transactionType: 'vehicle_rented',
///   description: 'Vehicle rented to customer',
///   bookingId: 'booking-123',
///   vehicleId: 'vehicle-456',
/// );
/// ```
class TransactionLogger {
  static final AdminService _adminService = AdminService();
  static final AuthService _authService = AuthService();

  // ==================== RENTER TRANSACTION LOGGING ====================

  /// Log renter transaction (booking_created, payment_made, etc.)
  static Future<bool> logRenterTransaction({
    required String transactionType,
    String? description,
    String? bookingId,
    String? vehicleId,
    Map<String, dynamic>? metadata,
    bool suppressErrors = false,
  }) async {
    try {
      final renterId = _authService.currentUser?.id;

      if (renterId == null) {
        if (!suppressErrors) {
          debugPrint('Cannot log renter transaction: No renter logged in');
        }
        return false;
      }

      final result = await _adminService.logRenterTransaction(
        renterId: renterId,
        transactionType: transactionType,
        description: description ?? transactionType,
        bookingId: bookingId,
        vehicleId: vehicleId,
        metadata: metadata,
      );

      if (result) {
        debugPrint('✓ Logged renter transaction: $transactionType');
      } else {
        if (!suppressErrors) {
          debugPrint('✗ Failed to log renter transaction: $transactionType');
        }
      }

      return result;
    } catch (e) {
      if (!suppressErrors) {
        debugPrint('Error logging renter transaction: $e');
      }
      return false;
    }
  }

  /// Log booking created
  static Future<bool> logBookingCreated({
    required String bookingId,
    required String vehicleId,
    String? vehicleName,
    DateTime? pickupDate,
    DateTime? returnDate,
  }) {
    return logRenterTransaction(
      transactionType: 'booking_created',
      description: 'Created booking for $vehicleName',
      bookingId: bookingId,
      vehicleId: vehicleId,
      metadata: {
        'vehicle_name': vehicleName,
        'pickup_date': pickupDate?.toIso8601String(),
        'return_date': returnDate?.toIso8601String(),
      },
    );
  }

  /// Log booking completed
  static Future<bool> logBookingCompleted({
    required String bookingId,
    required double totalAmount,
    String? notes,
  }) {
    return logRenterTransaction(
      transactionType: 'booking_completed',
      description: notes ?? 'Booking completed',
      bookingId: bookingId,
      metadata: {
        'total_amount': totalAmount,
        'completion_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log booking cancelled
  static Future<bool> logBookingCancelled({
    required String bookingId,
    String? reason,
  }) {
    return logRenterTransaction(
      transactionType: 'booking_cancelled',
      description: reason ?? 'Booking cancelled by renter',
      bookingId: bookingId,
      metadata: {'cancellation_reason': reason},
    );
  }

  /// Log payment made
  static Future<bool> logPaymentMade({
    required String bookingId,
    required double amount,
    String? paymentMethod,
    String? transactionRef,
  }) {
    return logRenterTransaction(
      transactionType: 'payment_made',
      description: 'Payment of \$$amount made',
      bookingId: bookingId,
      metadata: {
        'amount': amount,
        'payment_method': paymentMethod,
        'transaction_ref': transactionRef,
        'payment_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== DRIVER TRANSACTION LOGGING ====================

  /// Log driver transaction (job_accepted, job_completed, etc.)
  static Future<bool> logDriverTransaction({
    required String transactionType,
    String? description,
    String? bookingId,
    String? renterId,
    Map<String, dynamic>? metadata,
    bool suppressErrors = false,
  }) async {
    try {
      final driverId = _authService.currentUser?.id;

      if (driverId == null) {
        if (!suppressErrors) {
          debugPrint('Cannot log driver transaction: No driver logged in');
        }
        return false;
      }

      final result = await _adminService.logDriverTransaction(
        driverId: driverId,
        transactionType: transactionType,
        description: description ?? transactionType,
        bookingId: bookingId,
        renterId: renterId,
        metadata: metadata,
      );

      if (result) {
        debugPrint('✓ Logged driver transaction: $transactionType');
      } else {
        if (!suppressErrors) {
          debugPrint('✗ Failed to log driver transaction: $transactionType');
        }
      }

      return result;
    } catch (e) {
      if (!suppressErrors) {
        debugPrint('Error logging driver transaction: $e');
      }
      return false;
    }
  }

  /// Log job accepted
  static Future<bool> logJobAccepted({
    required String bookingId,
    required String renterId,
    String? renterName,
    double? tripFee,
  }) {
    return logDriverTransaction(
      transactionType: 'job_accepted',
      description: 'Accepted job for $renterName - Trip fee: \$$tripFee',
      bookingId: bookingId,
      renterId: renterId,
      metadata: {
        'renter_name': renterName,
        'trip_fee': tripFee,
        'acceptance_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log job completed
  static Future<bool> logJobCompleted({
    required String bookingId,
    required double tripFee,
    String? notes,
  }) {
    return logDriverTransaction(
      transactionType: 'job_completed',
      description: notes ?? 'Job completed - Trip fee: \$$tripFee',
      bookingId: bookingId,
      metadata: {
        'trip_fee': tripFee,
        'completion_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log earnings received
  static Future<bool> logEarningsReceived({
    required double amount,
    String? description,
  }) {
    return logDriverTransaction(
      transactionType: 'earnings_received',
      description: description ?? 'Received earnings of \$$amount',
      metadata: {
        'amount': amount,
        'receipt_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== PARTNER TRANSACTION LOGGING ====================

  /// Log partner transaction (vehicle_rented, rental_completed, etc.)
  static Future<bool> logPartnerTransaction({
    required String transactionType,
    String? description,
    String? bookingId,
    String? vehicleId,
    String? renterId,
    Map<String, dynamic>? metadata,
    bool suppressErrors = false,
  }) async {
    try {
      final partnerId = _authService.currentUser?.id;

      if (partnerId == null) {
        if (!suppressErrors) {
          debugPrint('Cannot log partner transaction: No partner logged in');
        }
        return false;
      }

      final result = await _adminService.logPartnerTransaction(
        partnerId: partnerId,
        transactionType: transactionType,
        description: description ?? transactionType,
        bookingId: bookingId,
        vehicleId: vehicleId,
        renterId: renterId,
        metadata: metadata,
      );

      if (result) {
        debugPrint('✓ Logged partner transaction: $transactionType');
      } else {
        if (!suppressErrors) {
          debugPrint('✗ Failed to log partner transaction: $transactionType');
        }
      }

      return result;
    } catch (e) {
      if (!suppressErrors) {
        debugPrint('Error logging partner transaction: $e');
      }
      return false;
    }
  }

  /// Log vehicle rented
  static Future<bool> logVehicleRented({
    required String bookingId,
    required String vehicleId,
    required String vehicleName,
    required String renterName,
    required DateTime pickupDate,
    required DateTime returnDate,
    required double dailyRate,
  }) {
    return logPartnerTransaction(
      transactionType: 'vehicle_rented',
      description: '$vehicleName rented to $renterName',
      bookingId: bookingId,
      vehicleId: vehicleId,
      metadata: {
        'vehicle_name': vehicleName,
        'renter_name': renterName,
        'pickup_date': pickupDate.toIso8601String(),
        'return_date': returnDate.toIso8601String(),
        'daily_rate': dailyRate,
        'days_rented': returnDate.difference(pickupDate).inDays,
      },
    );
  }

  /// Log rental completed
  static Future<bool> logRentalCompleted({
    required String bookingId,
    required String vehicleId,
    required double earnings,
    String? condition,
  }) {
    return logPartnerTransaction(
      transactionType: 'rental_completed',
      description: 'Rental completed - Earnings: \$$earnings',
      bookingId: bookingId,
      vehicleId: vehicleId,
      metadata: {
        'earnings': earnings,
        'vehicle_condition': condition,
        'completion_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log earnings received by partner
  static Future<bool> logPartnerEarningsReceived({
    required double amount,
    required int bookingCount,
    String? description,
  }) {
    return logPartnerTransaction(
      transactionType: 'earnings_received',
      description:
          description ??
          'Received earnings of \$$amount from $bookingCount bookings',
      metadata: {
        'amount': amount,
        'booking_count': bookingCount,
        'receipt_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== HISTORY RETRIEVAL ====================

  /// Get renter transaction history
  static Future<List<Map<String, dynamic>>> getRenterHistory({
    String? renterId,
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType,
  }) async {
    try {
      final id = renterId ?? _authService.currentUser?.id;

      if (id == null) {
        debugPrint('Cannot get renter history: No renter ID provided');
        return [];
      }

      return await _adminService.getRenterTransactionHistory(
        id,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
        transactionType: transactionType,
      );
    } catch (e) {
      debugPrint('Error getting renter history: $e');
      return [];
    }
  }

  /// Get driver transaction history
  static Future<List<Map<String, dynamic>>> getDriverHistory({
    String? driverId,
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType,
  }) async {
    try {
      final id = driverId ?? _authService.currentUser?.id;

      if (id == null) {
        debugPrint('Cannot get driver history: No driver ID provided');
        return [];
      }

      return await _adminService.getDriverTransactionHistory(
        id,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
        transactionType: transactionType,
      );
    } catch (e) {
      debugPrint('Error getting driver history: $e');
      return [];
    }
  }

  /// Get partner transaction history
  static Future<List<Map<String, dynamic>>> getPartnerHistory({
    String? partnerId,
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType,
  }) async {
    try {
      final id = partnerId ?? _authService.currentUser?.id;

      if (id == null) {
        debugPrint('Cannot get partner history: No partner ID provided');
        return [];
      }

      return await _adminService.getPartnerTransactionHistory(
        id,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
        transactionType: transactionType,
      );
    } catch (e) {
      debugPrint('Error getting partner history: $e');
      return [];
    }
  }

  /// Get booking transaction history (all parties)
  static Future<List<Map<String, dynamic>>> getBookingHistory({
    required String bookingId,
    int limit = 100,
  }) async {
    try {
      return await _adminService.getBookingTransactionHistory(
        bookingId,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error getting booking history: $e');
      return [];
    }
  }

  // ==================== TRANSACTION SUMMARIES ====================

  /// Get renter transaction summary
  static Future<Map<String, dynamic>> getRenterSummary({
    String? renterId,
  }) async {
    try {
      final id = renterId ?? _authService.currentUser?.id;

      if (id == null) {
        debugPrint('Cannot get renter summary: No renter ID provided');
        return {};
      }

      return await _adminService.getRenterTransactionSummary(id);
    } catch (e) {
      debugPrint('Error getting renter summary: $e');
      return {};
    }
  }

  /// Get driver transaction summary
  static Future<Map<String, dynamic>> getDriverSummary({
    String? driverId,
  }) async {
    try {
      final id = driverId ?? _authService.currentUser?.id;

      if (id == null) {
        debugPrint('Cannot get driver summary: No driver ID provided');
        return {};
      }

      return await _adminService.getDriverTransactionSummary(id);
    } catch (e) {
      debugPrint('Error getting driver summary: $e');
      return {};
    }
  }

  /// Get partner transaction summary
  static Future<Map<String, dynamic>> getPartnerSummary({
    String? partnerId,
  }) async {
    try {
      final id = partnerId ?? _authService.currentUser?.id;

      if (id == null) {
        debugPrint('Cannot get partner summary: No partner ID provided');
        return {};
      }

      return await _adminService.getPartnerTransactionSummary(id);
    } catch (e) {
      debugPrint('Error getting partner summary: $e');
      return {};
    }
  }
}
