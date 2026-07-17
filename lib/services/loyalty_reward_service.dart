import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoyaltyRewardState {
  final DateTime membershipStartedAt;
  final DateTime membershipExpiresAt;
  final int successfulTrips;
  final String rewardStatus;
  final DateTime? redeemedAt;
  final bool storageReady;

  const LoyaltyRewardState({
    required this.membershipStartedAt,
    required this.membershipExpiresAt,
    required this.successfulTrips,
    required this.rewardStatus,
    this.redeemedAt,
    this.storageReady = true,
  });

  int get progressTrips => successfulTrips >= 12 ? 12 : successfulTrips;
  int get remainingTrips => successfulTrips >= 12 ? 0 : 12 - successfulTrips;
  double get progress => progressTrips / 12;
  bool get isRedeemed => rewardStatus.toLowerCase() == 'redeemed';
  bool get isExpired => DateTime.now().isAfter(membershipExpiresAt);
  bool get canRedeem =>
      storageReady && !isRedeemed && !isExpired && successfulTrips >= 12;
}

class LoyaltyRewardService {
  LoyaltyRewardService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<LoyaltyRewardState> load(String renterId) async {
    final completedRows = await _client
        .from('bookings')
        .select('id,status')
        .eq('renter_id', renterId);
    final successfulTrips = completedRows
        .where(
          (row) =>
              row['status']?.toString().trim().toLowerCase() == 'completed',
        )
        .length;

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
      return _fromRecord(record, successfulTrips: successfulTrips);
    } on PostgrestException catch (error) {
      debugPrint('Loyalty storage unavailable: ${error.message}');
      final now = DateTime.now();
      return LoyaltyRewardState(
        membershipStartedAt: now,
        membershipExpiresAt: _addSixMonths(now),
        successfulTrips: successfulTrips,
        rewardStatus: 'locked',
        storageReady: false,
      );
    }
  }

  Future<LoyaltyRewardState> redeem(String renterId) async {
    await _client.rpc(
      'redeem_renter_loyalty_reward',
      params: {'p_renter_id': renterId},
    );
    return load(renterId);
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
      redeemedAt: DateTime.tryParse(record['redeemed_at']?.toString() ?? ''),
    );
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
