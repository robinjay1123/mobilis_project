class PricingPolicy {
  static const double deliveryRatePerKm = 75;
  static const double lateReturnRatePerHour = 300;
  static const double longBookingReservationRate = 0.20;
  static const int longBookingReservationThresholdDays = 7;
  static const double driverDailyRate = 1500.0;
  static const int minHourlyBookingHours = 12;

  static const double minDailyRentalPrice = 500;
  static const double maxDailyRentalPrice = 25000;
  static const double minHourlyRentalPrice = 75;
  static const double maxHourlyRentalPrice = 5000;

  static String peso(double amount) => 'PHP ${amount.toStringAsFixed(2)}';

  /// Calculates the rental subtotal for hourly mode.
  /// Rule:
  /// - Minimum hours for hourly rental is 12 hours.
  /// - 12 hours costs half of 1 day's price: (pricePerDay / 2).
  /// - When hours exceed 12 hours (e.g. 13 hours):
  ///   Price = (pricePerDay / 2) + (excessHours * pricePerHour).
  static double calculateHourlyRentalSubtotal({
    required int hours,
    required double pricePerDay,
    required double pricePerHour,
  }) {
    if (hours <= 0) return 0.0;
    final billableHours =
        hours < minHourlyBookingHours ? minHourlyBookingHours : hours;
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
