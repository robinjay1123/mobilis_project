import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/services/loyalty_reward_service.dart';

LoyaltyRewardState rewardState({
  required int trips,
  Set<int> redeemed = const <int>{},
}) {
  final now = DateTime.now();
  return LoyaltyRewardState(
    membershipStartedAt: now.subtract(const Duration(days: 1)),
    membershipExpiresAt: now.add(const Duration(days: 30)),
    successfulTrips: trips,
    rewardStatus: 'locked',
    redeemedMilestones: redeemed,
  );
}

void main() {
  test('zero completed trips starts an empty loyalty card', () {
    final state = rewardState(trips: 0);

    expect(state.progressTrips, 0);
    expect(state.progress, 0);
    expect(state.canRedeem, isFalse);
    expect(state.nextMilestone?.stamp, 3);
  });

  test('completed trips unlock milestone rewards in order', () {
    final state = rewardState(trips: 7, redeemed: const {3});

    expect(state.progressTrips, 7);
    expect(state.nextClaimableMilestone?.stamp, 6);
    expect(state.nextMilestone?.stamp, 8);
    expect(state.canRedeem, isTrue);
  });

  test('all 18 stamps and redemptions complete the card', () {
    final redeemed = LoyaltyRewardState.milestones
        .map((milestone) => milestone.stamp)
        .toSet();
    final state = rewardState(trips: 18, redeemed: redeemed);

    expect(state.progressTrips, 18);
    expect(state.progress, 1);
    expect(state.isRedeemed, isTrue);
    expect(state.canRedeem, isFalse);
  });
}
