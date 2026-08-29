class PricingPolicy {
  static const double deliveryRatePerKm = 75;
  static const double lateReturnRate4to5Seater = 200.0;
  static const double lateReturnRate6PlusSeater = 350.0;
  static const int lateReturnDayCapHours = 6;
  static const double lateReturnRatePerHour = 200.0;
  static const double standardReservationFee = 1000.0;
  static const double longBookingReservationRate = 0.20;
  static const int longBookingReservationThresholdDays = 7;
  static const double driverDailyRate = 1500.0;
  static const int minHourlyBookingHours = 12;
  static const int maxHourlyBookingHours = 23;

  /// Calculates the reservation fee:
  /// - 1 to 7 days: ₱1,000 flat fee
  /// - 8+ days (i.e. > 7 days): 20% of the principal rental total
  static double calculateReservationFee({
    required int days,
    required double principalRentalTotal,
    double defaultStandardFee = standardReservationFee,
  }) {
    if (days > longBookingReservationThresholdDays) {
      return principalRentalTotal * longBookingReservationRate;
    }
    return defaultStandardFee;
  }

  static const double minDailyRentalPrice = 500;
  static const double maxDailyRentalPrice = 25000;
  static const double minHourlyRentalPrice = 75;
  static const double maxHourlyRentalPrice = 5000;

  static String peso(double amount) => 'PHP ${amount.toStringAsFixed(2)}';

  /// Calculates late return fee based on vehicle seat count and late hours:
  /// - 4 to 5 seaters: PHP 200 / hour (configurable)
  /// - 6 to 7+ seaters: PHP 350 / hour (configurable)
  /// - Above 6 hours: Capped at the whole day rental price (dailyRate)
  static double calculateLateReturnFee({
    required int seats,
    required int lateHours,
    required double dailyRate,
    double? lateFee4to5Seater,
    double? lateFee6PlusSeater,
    int? lateFeeDayCapHours,
  }) {
    if (lateHours <= 0) return 0.0;
    final capHours = lateFeeDayCapHours ?? lateReturnDayCapHours;
    final rate4to5 = lateFee4to5Seater ?? lateReturnRate4to5Seater;
    final rate6Plus = lateFee6PlusSeater ?? lateReturnRate6PlusSeater;

    // Rule: "when the late is above 6 hrs that whole 6 hrs will be treated as whole day price"
    if (lateHours >= capHours) {
      return dailyRate > 0
          ? dailyRate
          : ((seats >= 6 ? rate6Plus : rate4to5) * capHours);
    }

    final hourlyRate = seats >= 6 ? rate6Plus : rate4to5;
    final calculatedTotal = lateHours * hourlyRate;
    if (dailyRate > 0 && calculatedTotal > dailyRate) {
      return dailyRate;
    }
    return calculatedTotal;
  }

  /// Calculates the rental subtotal for hourly mode.
  /// Rule:
  /// - Minimum duration for hourly rental is 12 hours.
  /// - Maximum duration for hourly rental is 23 hours.
  /// - 12 hours costs half of 1 day's price: (pricePerDay / 2).
  /// - When hours exceed 12 hours (up to 23 hours):
  ///   Price = (pricePerDay / 2) + (excessHours * pricePerHour).
  static double calculateHourlyRentalSubtotal({
    required int hours,
    required double pricePerDay,
    required double pricePerHour,
  }) {
    if (hours <= 0) return 0.0;
    int billableHours = hours;
    if (billableHours < minHourlyBookingHours) {
      billableHours = minHourlyBookingHours;
    } else if (billableHours > maxHourlyBookingHours) {
      billableHours = maxHourlyBookingHours;
    }

    final halfDayPrice = pricePerDay > 0
        ? (pricePerDay / 2.0)
        : (pricePerHour * minHourlyBookingHours);
    final effectiveHourlyRate = pricePerHour > 0
        ? pricePerHour
        : (pricePerDay > 0 ? (pricePerDay / 24.0) : 0.0);

    if (billableHours <= minHourlyBookingHours) {
      return halfDayPrice;
    }

    final excessHours = billableHours - minHourlyBookingHours;
    final calculatedTotal = halfDayPrice + (excessHours * effectiveHourlyRate);

    // If within 24 hours and daily price is set, cap at full daily rate
    if (billableHours <= 24 && pricePerDay > 0 && calculatedTotal > pricePerDay) {
      return pricePerDay;
    }
    return calculatedTotal;
  }

  static String? validateDailyRentalPrice(double? value) {
    if (value == null) return 'Please enter a valid daily rental price';
    if (value < minDailyRentalPrice) {
      return 'Daily price must be at least ${peso(minDailyRentalPrice)}';
    }
    if (value > maxDailyRentalPrice) {
      return 'Daily price cannot exceed ${peso(maxDailyRentalPrice)}';
    }
    return null;
  }

  static String? validateHourlyRentalPrice(double? value) {
    if (value == null) return 'Please enter a valid hourly rental price';
    if (value < minHourlyRentalPrice) {
      return 'Hourly price must be at least ${peso(minHourlyRentalPrice)}';
    }
    if (value > maxHourlyRentalPrice) {
      return 'Hourly price cannot exceed ${peso(maxHourlyRentalPrice)}';
    }
    return null;
  }
}
