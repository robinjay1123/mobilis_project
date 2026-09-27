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

  static const double unapprovedLateReturnPenalty = 5000.0;

  static String peso(double amount) => 'PHP ${amount.toStringAsFixed(2)}';

  /// Calculates exceeded return / late return fee based on vehicle seat count, hours, and approval status:
  /// - Approved Extension:
  ///   - 1 to 5 hours:
  ///     - 1 to 5 seaters: PHP 200 / hour
  ///     - 6 to 7+ seaters: PHP 350 / hour
  ///   - 6 hours and above (within 24 hrs): Whole day rental price (dailyRate, e.g. PHP 1,800)
  ///   - Over 24 hours: (lateHours ~/ 24) * dailyRate + remainder tier (hourly if < 6 hrs, whole day if >= 6 hrs)
  /// - Not Approved Extension (unauthorized late return):
  ///   - "not approved extension kahit 1 hour man yan or what 5k parin since hindi nga approve"
  ///   - Flat PHP 5,000 penalty for up to 24 hours
  ///   - Over 24 hours: (lateHours ~/ 24) * dailyRate + PHP 5,000 penalty
  static double calculateLateReturnFee({
    required int seats,
    required int lateHours,
    required double dailyRate,
    bool isApproved = true,
    double? unapprovedFee,
    double? lateFee4to5Seater,
    double? lateFee6PlusSeater,
    int? lateFeeDayCapHours,
  }) {
    final breakdown = getExceededReturnBreakdown(
      seats: seats,
      lateHours: lateHours,
      dailyRate: dailyRate,
      isApproved: isApproved,
      unapprovedFee: unapprovedFee,
      lateFee4to5Seater: lateFee4to5Seater,
      lateFee6PlusSeater: lateFee6PlusSeater,
      lateFeeDayCapHours: lateFeeDayCapHours,
    );
    return breakdown.totalFee;
  }

  /// Returns full granular breakdown of exceeded return computation.
  static ExceededReturnBreakdown getExceededReturnBreakdown({
    required int seats,
    required int lateHours,
    required double dailyRate,
    bool isApproved = true,
    double? unapprovedFee,
    double? lateFee4to5Seater,
    double? lateFee6PlusSeater,
    int? lateFeeDayCapHours,
  }) {
    if (lateHours <= 0) {
      return const ExceededReturnBreakdown(
        lateHours: 0,
        seats: 4,
        dailyRate: 0.0,
        isApproved: true,
        hourlyRate: 0.0,
        isWholeDayCap: false,
        isUnapprovedPenalty: false,
        totalFee: 0.0,
        ruleDescription: 'Returned on time (No extra fees)',
        tierDescription: 'On time',
      );
    }

    final capHours = lateFeeDayCapHours ?? lateReturnDayCapHours; // 6 hrs
    final rate4to5 = lateFee4to5Seater ?? lateReturnRate4to5Seater; // PHP 200/hr
    final rate6Plus = lateFee6PlusSeater ?? lateReturnRate6PlusSeater; // PHP 350/hr
    final hourlyRate = seats >= 6 ? rate6Plus : rate4to5;
    final tier = seats >= 6 ? '7-Seater Tier (₱350/hr)' : '1–5 Seater Tier (₱200/hr)';

    // Rule: Not Approved Extension ("kahit 1 hour man yan or what 5k parin since hindi nga approve")
    if (!isApproved) {
      final penalty = unapprovedFee ?? unapprovedLateReturnPenalty;
      if (lateHours <= 24) {
        return ExceededReturnBreakdown(
          lateHours: lateHours,
          seats: seats,
          dailyRate: dailyRate,
          isApproved: false,
          hourlyRate: hourlyRate,
          isWholeDayCap: false,
          isUnapprovedPenalty: true,
          totalFee: penalty,
          ruleDescription: 'Unapproved extension / late return: Flat ${peso(penalty)} penalty',
          tierDescription: 'Unapproved Extension (Flat ₱5,000 Penalty)',
        );
      }
      final days = lateHours ~/ 24;
      final dailyCost = days * (dailyRate > 0 ? dailyRate : 0.0);
      final fee = dailyCost + penalty;
      return ExceededReturnBreakdown(
        lateHours: lateHours,
        seats: seats,
        dailyRate: dailyRate,
        isApproved: false,
        hourlyRate: hourlyRate,
        isWholeDayCap: false,
        isUnapprovedPenalty: true,
        totalFee: fee,
        ruleDescription:
            'Unapproved extension: $days day${days > 1 ? 's' : ''} (${peso(dailyCost)}) + ${peso(penalty)} penalty',
        tierDescription: 'Unapproved Multi-day Late Return',
      );
    }

    // Rule: Approved Extension (1 to 5 hrs = hourly rate, 6+ hrs = whole day rate)
    if (lateHours <= 24) {
      if (lateHours >= capHours) {
        final fee = dailyRate > 0 ? dailyRate : (hourlyRate * capHours);
        return ExceededReturnBreakdown(
          lateHours: lateHours,
          seats: seats,
          dailyRate: dailyRate,
          isApproved: true,
          hourlyRate: hourlyRate,
          isWholeDayCap: true,
          isUnapprovedPenalty: false,
          totalFee: fee,
          ruleDescription:
              'Approved Extension (≥ $capHours hrs): Whole day rental price (${peso(fee)})',
          tierDescription: '$tier • Whole Day Cap',
        );
      }

      final calculatedTotal = lateHours * hourlyRate;
      final isCap = dailyRate > 0 && calculatedTotal > dailyRate;
      final fee = isCap ? dailyRate : calculatedTotal;
      return ExceededReturnBreakdown(
        lateHours: lateHours,
        seats: seats,
        dailyRate: dailyRate,
        isApproved: true,
        hourlyRate: hourlyRate,
        isWholeDayCap: isCap,
        isUnapprovedPenalty: false,
        totalFee: fee,
        ruleDescription: isCap
            ? 'Approved Extension: Capped at whole day rental price (${peso(fee)})'
            : 'Approved Extension ($lateHours hr${lateHours == 1 ? '' : 's'} × ${peso(hourlyRate)}/hr): ${peso(fee)}',
        tierDescription: tier,
      );
    }

    // Multi-day approved extension (> 24 hours)
    final fullDays = lateHours ~/ 24;
    final remainingHours = lateHours % 24;
    double remainderCost = 0.0;
    bool isRemainderCap = false;

    if (remainingHours >= capHours) {
      remainderCost = dailyRate > 0 ? dailyRate : (hourlyRate * capHours);
      isRemainderCap = true;
    } else if (remainingHours > 0) {
      remainderCost = remainingHours * hourlyRate;
      if (dailyRate > 0 && remainderCost > dailyRate) {
        remainderCost = dailyRate;
        isRemainderCap = true;
      }
    }

    final totalFee =
        (fullDays * (dailyRate > 0 ? dailyRate : (hourlyRate * 24))) + remainderCost;
    final ruleDesc = remainderCost > 0
        ? 'Approved Extension: $fullDays day${fullDays > 1 ? 's' : ''} + ${isRemainderCap ? "1 whole day (≥ $capHours hrs)" : "$remainingHours hr(s)"} = ${peso(totalFee)}'
        : 'Approved Extension: $fullDays day${fullDays > 1 ? 's' : ''} = ${peso(totalFee)}';

    return ExceededReturnBreakdown(
      lateHours: lateHours,
      seats: seats,
      dailyRate: dailyRate,
      isApproved: true,
      hourlyRate: hourlyRate,
      isWholeDayCap: isRemainderCap,
      isUnapprovedPenalty: false,
      totalFee: totalFee,
      ruleDescription: ruleDesc,
      tierDescription: '$tier • Multi-day Extension',
    );
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

class ExceededReturnBreakdown {
  final int lateHours;
  final int seats;
  final double dailyRate;
  final bool isApproved;
  final double hourlyRate;
  final bool isWholeDayCap;
  final bool isUnapprovedPenalty;
  final double totalFee;
  final String ruleDescription;
  final String tierDescription;

  const ExceededReturnBreakdown({
    required this.lateHours,
    required this.seats,
    required this.dailyRate,
    required this.isApproved,
    required this.hourlyRate,
    required this.isWholeDayCap,
    required this.isUnapprovedPenalty,
    required this.totalFee,
    required this.ruleDescription,
    required this.tierDescription,
  });

  Map<String, dynamic> toMap() => {
        'late_hours': lateHours,
        'seats': seats,
        'daily_rate': dailyRate,
        'is_approved': isApproved,
        'hourly_rate': hourlyRate,
        'is_whole_day_cap': isWholeDayCap,
        'is_unapproved_penalty': isUnapprovedPenalty,
        'total_fee': totalFee,
        'rule_description': ruleDescription,
        'tier_description': tierDescription,
      };
}
