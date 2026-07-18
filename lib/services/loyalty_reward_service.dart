import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoyaltyRewardMilestone {
  final int stamp;
  final String label;

  const LoyaltyRewardMilestone(this.stamp, this.label);
}

class LoyaltyRewardState {
  static const int maximumStamps = 18;
  static const List<LoyaltyRewardMilestone> milestones = [
    LoyaltyRewardMilestone(3, '\u20B150 OFF'),
    LoyaltyRewardMilestone(6, '\u20B1200 OFF'),
    LoyaltyRewardMilestone(8, 'PSDC Mug'),
    LoyaltyRewardMilestone(10, 'PSDC Umbrella'),
    LoyaltyRewardMilestone(12, '\u20B1300 OFF'),
    LoyaltyRewardMilestone(15, 'Free 3 Hours'),
    LoyaltyRewardMilestone(18, 'Free 24 Hours'),
  ];

  final DateTime membershipStartedAt;
  final DateTime membershipExpiresAt;
  final int successfulTrips;
  final String rewardStatus;
  final Set<int> redeemedMilestones;
  final DateTime? redeemedAt;
  final bool storageReady;

  const LoyaltyRewardState({
    required this.membershipStartedAt,
    required this.membershipExpiresAt,
    required this.successfulTrips,
    required this.rewardStatus,
    this.redeemedMilestones = const <int>{},
    this.redeemedAt,
    this.storageReady = true,
  });

  int get progressTrips => successfulTrips.clamp(0, maximumStamps);
  int get remainingTrips =>
      (maximumStamps - progressTrips).clamp(0, maximumStamps);
  double get progress => progressTrips / maximumStamps;
  bool get isRedeemed => redeemedMilestones.length == milestones.length;
  bool get isExpired => DateTime.now().isAfter(membershipExpiresAt);

  List<LoyaltyRewardMilestone> get unlockedMilestones => milestones
      .where((milestone) => successfulTrips >= milestone.stamp)
      .toList(growable: false);

  List<LoyaltyRewardMilestone> get claimableMilestones => unlockedMilestones
      .where((milestone) => !redeemedMilestones.contains(milestone.stamp))
      .toList(growable: false);

  LoyaltyRewardMilestone? get nextClaimableMilestone =>
      claimableMilestones.isEmpty ? null : claimableMilestones.first;

  LoyaltyRewardMilestone? get nextMilestone {
    for (final milestone in milestones) {
      if (successfulTrips < milestone.stamp) return milestone;
    }
    return null;
  }

  bool get canRedeem =>
      storageReady && !isExpired && nextClaimableMilestone != null;
}

class LoyaltyRewardService {
  LoyaltyRewardService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<LoyaltyRewardState> load(String renterId) async {
    try {
      var record = await _client
          .from('renter_loyalty_rewards')
          .select()
          .eq('renter_id', renterId)
          .maybeSingle();

      record ??= await _client
          .from('renter_loyalty_rewards')
          .insert({'renter_id': renterId})
          .select()
          .single();
      final successfulTrips = await _completedTripsDuringMembership(
        renterId,
        record,
      );
      return _fromRecord(record, successfulTrips: successfulTrips);
    } on PostgrestException catch (error) {
      debugPrint('Loyalty storage unavailable: ${error.message}');
      final now = DateTime.now();
      final successfulTrips = await _completedTripCount(renterId);
      return LoyaltyRewardState(
        membershipStartedAt: now,
        membershipExpiresAt: _addSixMonths(now),
        successfulTrips: successfulTrips,
        rewardStatus: 'locked',
        storageReady: false,
      );
    }
  }

  Future<LoyaltyRewardState> redeem(
    String renterId,
    LoyaltyRewardMilestone milestone,
  ) async {
    await _client.rpc(
      'redeem_renter_loyalty_reward',
      params: {'p_renter_id': renterId, 'p_milestone': milestone.stamp},
    );
    return load(renterId);
  }

  Future<int> _completedTripsDuringMembership(
    String renterId,
    Map<String, dynamic> record,
  ) async {
    final startedAt = DateTime.tryParse(
      record['membership_started_at']?.toString() ?? '',
    );
    final expiresAt = DateTime.tryParse(
      record['membership_expires_at']?.toString() ?? '',
    );
    final rows = await _client
        .from('bookings')
        .select('id,status,completed_at,created_at')
        .eq('renter_id', renterId);

    return rows.where((row) {
      if (row['status']?.toString().trim().toLowerCase() != 'completed') {
        return false;
      }
      final completedAt = DateTime.tryParse(
        row['completed_at']?.toString() ?? '',
      );
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
      final earnedAt = completedAt ?? createdAt;
      if (earnedAt == null) return false;
      if (startedAt != null && earnedAt.isBefore(startedAt)) return false;
      if (expiresAt != null && earnedAt.isAfter(expiresAt)) return false;
      return true;
    }).length;
  }

  Future<int> _completedTripCount(String renterId) async {
    final rows = await _client
        .from('bookings')
        .select('id,status')
        .eq('renter_id', renterId);
    return rows
        .where(
          (row) =>
              row['status']?.toString().trim().toLowerCase() == 'completed',
        )
        .length;
  }

  LoyaltyRewardState _fromRecord(
    Map<String, dynamic> record, {
    required int successfulTrips,
  }) {
    final now = DateTime.now();
    return LoyaltyRewardState(
      membershipStartedAt:
          DateTime.tryParse(
            record['membership_started_at']?.toString() ?? '',
          ) ??
          now,
      membershipExpiresAt:
          DateTime.tryParse(
            record['membership_expires_at']?.toString() ?? '',
          ) ??
          _addSixMonths(now),
      successfulTrips: successfulTrips,
      rewardStatus: record['reward_status']?.toString() ?? 'locked',
      redeemedMilestones: _parseRedeemedMilestones(
        record['redeemed_milestones'],
      ),
      redeemedAt: DateTime.tryParse(record['redeemed_at']?.toString() ?? ''),
    );
  }

  Set<int> _parseRedeemedMilestones(dynamic value) {
    if (value is List) {
      return value
          .map((item) => int.tryParse(item.toString()))
          .whereType<int>()
          .toSet();
    }
    if (value is String) {
      return RegExp(r'\d+')
          .allMatches(value)
          .map((match) => int.tryParse(match.group(0) ?? ''))
          .whereType<int>()
          .toSet();
    }
    return <int>{};
  }

  static DateTime _addSixMonths(DateTime date) {
    final targetMonth = date.month + 6;
    final year = date.year + ((targetMonth - 1) ~/ 12);
    final month = ((targetMonth - 1) % 12) + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day, date.hour, date.minute, date.second);
  }
}
