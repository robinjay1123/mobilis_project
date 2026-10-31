import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoyaltyRewardMilestone {
  final int stamp;
  final String label;
  final String? id;
  final String description;
  final String rewardType; // 'discount', 'gift', 'free_time'
  final double discountAmount;
  final double discountPercent;
  final int freeHours;
  final String? voucherCode;
  final bool isActive;

  const LoyaltyRewardMilestone(
    this.stamp,
    this.label, {
    this.id,
    this.description = '',
    this.rewardType = 'discount',
    this.discountAmount = 0.0,
    this.discountPercent = 0.0,
    this.freeHours = 0,
    this.voucherCode,
    this.isActive = true,
  });

  factory LoyaltyRewardMilestone.fromJson(Map<String, dynamic> json) {
    return LoyaltyRewardMilestone(
      (json['stamp'] as num?)?.toInt() ?? 1,
      json['label']?.toString() ?? '',
      id: json['id']?.toString(),
      description: json['description']?.toString() ?? '',
      rewardType: json['reward_type']?.toString() ?? 'discount',
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      freeHours: (json['free_hours'] as num?)?.toInt() ?? 0,
      voucherCode: json['voucher_code']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'stamp': stamp,
      'label': label,
      'description': description,
      'reward_type': rewardType,
      'discount_amount': discountAmount,
      'discount_percent': discountPercent,
      'free_hours': freeHours,
      'voucher_code': voucherCode,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  LoyaltyRewardMilestone copyWith({
    String? id,
    int? stamp,
    String? label,
    String? description,
    String? rewardType,
    double? discountAmount,
    double? discountPercent,
    int? freeHours,
    String? voucherCode,
    bool? isActive,
  }) {
    return LoyaltyRewardMilestone(
      stamp ?? this.stamp,
      label ?? this.label,
      id: id ?? this.id,
      description: description ?? this.description,
      rewardType: rewardType ?? this.rewardType,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      freeHours: freeHours ?? this.freeHours,
      voucherCode: voucherCode ?? this.voucherCode,
      isActive: isActive ?? this.isActive,
    );
  }
}

class LoyaltyRewardState {
  static const int maximumStamps = 18;
  static const List<LoyaltyRewardMilestone> defaultMilestones = [
    LoyaltyRewardMilestone(3, '\u20B150 OFF', discountAmount: 50.0, voucherCode: 'LOYALTY50'),
    LoyaltyRewardMilestone(6, '\u20B1200 OFF', discountAmount: 200.0, voucherCode: 'LOYALTY200'),
    LoyaltyRewardMilestone(8, 'PSDC Mug', rewardType: 'gift'),
    LoyaltyRewardMilestone(10, 'PSDC Umbrella', rewardType: 'gift'),
    LoyaltyRewardMilestone(12, '\u20B1300 OFF', discountAmount: 300.0, voucherCode: 'LOYALTY300'),
    LoyaltyRewardMilestone(15, 'Free 3 Hours', rewardType: 'free_time', freeHours: 3, voucherCode: 'LOYALTY_FREE3H'),
    LoyaltyRewardMilestone(18, 'Free 24 Hours', rewardType: 'free_time', freeHours: 24, voucherCode: 'LOYALTY_FREE24H'),
  ];

  static List<LoyaltyRewardMilestone> activeMilestones = List.from(defaultMilestones);

  final DateTime membershipStartedAt;
  final DateTime membershipExpiresAt;
  final int successfulTrips;
  final String rewardStatus;
  final Set<int> redeemedMilestones;
  final DateTime? redeemedAt;
  final bool storageReady;
  final List<LoyaltyRewardMilestone> milestonesList;

  LoyaltyRewardState({
    required this.membershipStartedAt,
    required this.membershipExpiresAt,
    required this.successfulTrips,
    required this.rewardStatus,
    this.redeemedMilestones = const <int>{},
    this.redeemedAt,
    this.storageReady = true,
    List<LoyaltyRewardMilestone>? milestones,
  }) : milestonesList = milestones ?? activeMilestones;

  List<LoyaltyRewardMilestone> get milestones => milestonesList;

  int get progressTrips => successfulTrips.clamp(0, maximumStamps);
  int get remainingTrips =>
      (maximumStamps - progressTrips).clamp(0, maximumStamps);
  double get progress => progressTrips / maximumStamps;
  bool get isRedeemed => redeemedMilestones.length >= milestones.where((m) => m.isActive).length;
  bool get isExpired => DateTime.now().isAfter(membershipExpiresAt);

  List<LoyaltyRewardMilestone> get unlockedMilestones => milestones
      .where((milestone) => milestone.isActive && successfulTrips >= milestone.stamp)
      .toList(growable: false);

  List<LoyaltyRewardMilestone> get claimableMilestones => unlockedMilestones
      .where((milestone) => !redeemedMilestones.contains(milestone.stamp))
      .toList(growable: false);

  LoyaltyRewardMilestone? get nextClaimableMilestone =>
      claimableMilestones.isEmpty ? null : claimableMilestones.first;

  LoyaltyRewardMilestone? get nextMilestone {
    for (final milestone in milestones) {
      if (milestone.isActive && successfulTrips < milestone.stamp) return milestone;
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
    final milestones = await loadMilestones();
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
      return _fromRecord(
        record,
        successfulTrips: successfulTrips,
        milestones: milestones,
      );
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
        milestones: milestones,
      );
    }
  }

  Future<List<LoyaltyRewardMilestone>> loadMilestones() async {
    try {
      final rows = await _client
          .from('loyalty_card_milestones')
          .select()
          .order('stamp', ascending: true);
      final list = (rows as List)
          .map((r) => LoyaltyRewardMilestone.fromJson(Map<String, dynamic>.from(r)))
          .toList();
      if (list.isNotEmpty) {
        LoyaltyRewardState.activeMilestones = list;
        return list;
      }
    } catch (e) {
      debugPrint('LoyaltyRewardService: Error loading dynamic milestones: $e');
    }
    return LoyaltyRewardState.defaultMilestones;
  }

  Future<LoyaltyRewardMilestone> saveMilestone(LoyaltyRewardMilestone milestone) async {
    final data = milestone.toJson(includeId: false);
    try {
      final response = await _client
          .from('loyalty_card_milestones')
          .upsert(data, onConflict: 'stamp')
          .select()
          .single();
      final saved = LoyaltyRewardMilestone.fromJson(Map<String, dynamic>.from(response));
      final idx = LoyaltyRewardState.activeMilestones.indexWhere((m) => m.stamp == saved.stamp);
      if (idx != -1) {
        LoyaltyRewardState.activeMilestones[idx] = saved;
      } else {
        LoyaltyRewardState.activeMilestones.add(saved);
        LoyaltyRewardState.activeMilestones.sort((a, b) => a.stamp.compareTo(b.stamp));
      }
      return saved;
    } catch (e) {
      debugPrint('LoyaltyRewardService: Error saving milestone: $e');
      final idx = LoyaltyRewardState.activeMilestones.indexWhere((m) => m.stamp == milestone.stamp);
      if (idx != -1) {
        LoyaltyRewardState.activeMilestones[idx] = milestone;
      } else {
        LoyaltyRewardState.activeMilestones.add(milestone);
        LoyaltyRewardState.activeMilestones.sort((a, b) => a.stamp.compareTo(b.stamp));
      }
      return milestone;
    }
  }

  Future<void> deleteMilestone(int stamp) async {
    try {
      await _client.from('loyalty_card_milestones').delete().eq('stamp', stamp);
    } catch (e) {
      debugPrint('LoyaltyRewardService: Error deleting milestone: $e');
    }
    LoyaltyRewardState.activeMilestones.removeWhere((m) => m.stamp == stamp);
  }

  Future<void> toggleMilestoneStatus(int stamp, bool isActive) async {
    try {
      await _client
          .from('loyalty_card_milestones')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('stamp', stamp);
    } catch (e) {
      debugPrint('LoyaltyRewardService: Error toggling milestone: $e');
    }
    final idx = LoyaltyRewardState.activeMilestones.indexWhere((m) => m.stamp == stamp);
    if (idx != -1) {
      LoyaltyRewardState.activeMilestones[idx] =
          LoyaltyRewardState.activeMilestones[idx].copyWith(isActive: isActive);
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
    List<LoyaltyRewardMilestone>? milestones,
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
      milestones: milestones,
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
