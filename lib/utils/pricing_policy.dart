class PricingPolicy {
  static const double deliveryRatePerKm = 75;
  static const double lateReturnRatePerHour = 300;
  static const double longBookingReservationRate = 0.20;
  static const int longBookingReservationThresholdDays = 7;

  static const double minDailyRentalPrice = 500;
  static const double maxDailyRentalPrice = 25000;
  static const double minHourlyRentalPrice = 75;
  static const double maxHourlyRentalPrice = 5000;

  static String peso(double amount) => 'PHP ${amount.toStringAsFixed(2)}';

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
