import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class LoyaltyProfile {
  final String userId;
  final int completedTripsCount;
  final int loyaltyPoints;
  final String tierName; // 'Bronze', 'Silver', 'Gold', 'VIP Renter'
  final List<LoyaltyVoucher> availableVouchers;

  const LoyaltyProfile({
    required this.userId,
    required this.completedTripsCount,
    required this.loyaltyPoints,
    required this.tierName,
    required this.availableVouchers,
  });
}

class LoyaltyVoucher {
  final String code;
  final String title;
  final String description;
  final double discountPercent; // e.g. 10.0 for 10%
  final double discountAmount; // e.g. 500.0 for P500 off
  final bool isPercent;
  final int minTripsRequired;

  const LoyaltyVoucher({
    required this.code,
    required this.title,
    required this.description,
    required this.discountPercent,
    required this.discountAmount,
    required this.isPercent,
    required this.minTripsRequired,
  });
}

class LoyaltyService {
  static final LoyaltyService _instance = LoyaltyService._internal();
  factory LoyaltyService() => _instance;
  LoyaltyService._internal();

  final _supabase = Supabase.instance.client;

  /// System vouchers based on completed trips with PSDC
  static const List<LoyaltyVoucher> systemVouchers = [
    LoyaltyVoucher(
      code: 'PSDC3TRIPS10',
      title: '10% OFF Frequent Renter Voucher',
      description: 'Unlocked after 3 completed trips with PSDC!',
      discountPercent: 10.0,
      discountAmount: 0.0,
      isPercent: true,
      minTripsRequired: 3,
    ),
    LoyaltyVoucher(
      code: 'PSDC5TRIPS500',
      title: '₱500 OFF PSDC Loyal Renter Reward',
      description: 'Unlocked after 5 completed trips with PSDC!',
      discountPercent: 0.0,
      discountAmount: 500.0,
      isPercent: false,
      minTripsRequired: 5,
    ),
    LoyaltyVoucher(
      code: 'PSDCVIP20',
      title: '20% OFF PSDC VIP Renter Voucher',
      description: 'Unlocked after 10 completed trips with PSDC!',
      discountPercent: 20.0,
      discountAmount: 0.0,
      isPercent: true,
      minTripsRequired: 10,
    ),
  ];

  /// Get loyalty profile for a renter
  Future<LoyaltyProfile> getLoyaltyProfile(String userId) async {
    try {
      if (userId.trim().isEmpty) {
        return const LoyaltyProfile(
          userId: '',
          completedTripsCount: 0,
          loyaltyPoints: 0,
          tierName: 'Bronze',
          availableVouchers: [],
        );
      }

      // Count completed bookings for this renter
      final response = await _supabase
          .from('bookings')
          .select('id, status, completion_stage')
          .eq('renter_id', userId)
          .or('status.eq.completed,completion_stage.eq.completed');
      
      final completedTrips = List<Map<String, dynamic>>.from(response).length;
      
      // Calculate total points earned (100 points per completed trip + bonus)
      final points = completedTrips * 150;

      // Resolve tier
      String tier = 'Bronze Renter';
      if (completedTrips >= 10) {
        tier = 'VIP Renter ⭐';
      } else if (completedTrips >= 5) {
        tier = 'Gold Renter 🥇';
      } else if (completedTrips >= 3) {
        tier = 'Silver Renter 🥈';
      }

      // Unlocked vouchers
      final unlocked = systemVouchers
          .where((v) => completedTrips >= v.minTripsRequired)
          .toList();

      return LoyaltyProfile(
        userId: userId,
        completedTripsCount: completedTrips,
        loyaltyPoints: points,
        tierName: tier,
        availableVouchers: unlocked,
      );
    } catch (e) {
      debugPrint('Error getting loyalty profile: $e');
      return LoyaltyProfile(
        userId: userId,
        completedTripsCount: 0,
        loyaltyPoints: 0,
        tierName: 'Bronze Renter',
        availableVouchers: const [],
      );
    }
  }

  /// Award points and notify renter when a booking is completed
  Future<void> awardPointsForCompletedBooking({
    required String renterId,
    required String bookingId,
    required double totalCost,
  }) async {
    if (renterId.trim().isEmpty) return;
    try {
      final profile = await getLoyaltyProfile(renterId);
      final newTripCount = profile.completedTripsCount + 1;
      final pointsEarned = 150 + ((totalCost / 100).floor() * 5);
      final newPoints = profile.loyaltyPoints + pointsEarned;

      // Check if new voucher unlocked
      String unlockMsg = '';
      for (final v in systemVouchers) {
        if (newTripCount == v.minTripsRequired) {
          unlockMsg = ' 🎁 You unlocked a new reward: ${v.title} (${v.code})!';
          break;
        }
      }

      await NotificationService().createNotification(
        userId: renterId,
        title: '🎉 Loyalty Points Earned!',
        message:
            'You earned +$pointsEarned PSDC Loyalty Points for completing your trip! Total Points: $newPoints.$unlockMsg',
        type: 'loyalty_reward',
        data: {
          'booking_id': bookingId,
          'points_earned': pointsEarned,
          'total_points': newPoints,
          'completed_trips': newTripCount,
          'event': 'loyalty_points_earned',
        },
      );
    } catch (e) {
      debugPrint('Skipped awarding loyalty points notification: $e');
    }
  }
}
