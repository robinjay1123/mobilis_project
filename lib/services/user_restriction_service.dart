import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

class UserRestrictionState {
  final int violationCount;
  final bool isBlocked;
  final DateTime? chatRestrictedUntil;
  final DateTime? accountRestrictedUntil;
  final String reason;
  final String level;

  const UserRestrictionState({
    required this.violationCount,
    required this.isBlocked,
    required this.chatRestrictedUntil,
    required this.accountRestrictedUntil,
    required this.reason,
    required this.level,
  });

  bool get isChatRestricted =>
      chatRestrictedUntil != null &&
      chatRestrictedUntil!.isAfter(DateTime.now());

  bool get isAccountRestricted =>
      accountRestrictedUntil != null &&
      accountRestrictedUntil!.isAfter(DateTime.now());

  bool get isMessagingRestricted =>
      isBlocked || isAccountRestricted || isChatRestricted;

  DateTime? get activeUntil {
    if (isAccountRestricted) return accountRestrictedUntil;
    if (isChatRestricted) return chatRestrictedUntil;
    if (isBlocked) return null;
    return null;
  }

  bool get isPermanentlyBlocked => isBlocked && activeUntil == null;

  static const empty = UserRestrictionState(
    violationCount: 0,
    isBlocked: false,
    chatRestrictedUntil: null,
    accountRestrictedUntil: null,
    reason: '',
    level: 'none',
  );
}

class UserRestrictionService {
  static final UserRestrictionService _instance =
      UserRestrictionService._internal();

  factory UserRestrictionService() {
    return _instance;
  }

  UserRestrictionService._internal();

  final SupabaseClient supabase = Supabase.instance.client;

  static const Duration _firstRestrictionDuration = Duration(days: 7);
  static const Duration _secondRestrictionDuration = Duration(days: 30);
  static const String _defaultReason =
      'Sharing contact information or asking users to move the transaction outside the app.';

  Future<UserRestrictionState> getCurrentUserRestriction() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return UserRestrictionState.empty;
    return getUserRestriction(userId);
  }

  Future<UserRestrictionState> getUserRestriction(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select(
            'off_platform_flag_count, is_blocked, chat_restricted_until, account_restricted_until, restriction_reason, restriction_level',
          )
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return UserRestrictionState.empty;

      return UserRestrictionState(
        violationCount:
            (response['off_platform_flag_count'] as num?)?.toInt() ?? 0,
        isBlocked: response['is_blocked'] == true,
        chatRestrictedUntil: DateTime.tryParse(
          response['chat_restricted_until']?.toString() ?? '',
        )?.toLocal(),
        accountRestrictedUntil: DateTime.tryParse(
          response['account_restricted_until']?.toString() ?? '',
        )?.toLocal(),
        reason: response['restriction_reason']?.toString().trim() ?? '',
        level: response['restriction_level']?.toString().trim() ?? 'none',
      );
    } catch (e) {
      debugPrint('Error fetching user restriction state: $e');
      return UserRestrictionState.empty;
    }
  }

  Future<UserRestrictionState> applyPolicyViolation({
    required String userId,
    String? conversationId,
  }) async {
    try {
      final response = await supabase
          .from('users')
          .select(
            'id, email, phone, role, full_name, off_platform_flag_count, chat_restricted_until, account_restricted_until',
          )
          .eq('id', userId)
          .single();

      final violationCount =
          (response['off_platform_flag_count'] as num?)?.toInt() ?? 0;
      final role = response['role']?.toString().trim().toLowerCase() ?? '';
      final now = DateTime.now();
      final currentUntil = DateTime.tryParse(
        response['account_restricted_until']?.toString() ??
            response['chat_restricted_until']?.toString() ??
            '',
      );

      final updatePayload = <String, dynamic>{
        'restriction_reason': _defaultReason,
        'id_verified': false,
        'verification_status': 'rejected',
      };

      if (violationCount >= 3) {
        updatePayload['is_blocked'] = true;
        updatePayload['is_active'] = false;
        updatePayload['application_status'] = 'rejected';
        updatePayload['chat_restricted_until'] = null;
        updatePayload['account_restricted_until'] = null;
        updatePayload['restriction_level'] = 'third_attempt_blocked';
        await supabase.from('users').update(updatePayload).eq('id', userId);
        await _applyRoleRestrictions(userId: userId, role: role);
        await _recordBlockedIdentity(
          userId: userId,
          email: response['email']?.toString(),
          phone: response['phone']?.toString(),
          fullName: response['full_name']?.toString(),
        );
      } else {
        final until = _maxDateTime(
          currentUntil,
          now.add(
            violationCount >= 2
                ? _secondRestrictionDuration
                : _firstRestrictionDuration,
          ),
        );
        updatePayload['chat_restricted_until'] = until.toIso8601String();
        updatePayload['account_restricted_until'] = until.toIso8601String();
        updatePayload['restriction_level'] = violationCount >= 2
            ? 'second_attempt'
            : 'first_attempt';
        await supabase.from('users').update(updatePayload).eq('id', userId);
        await _applyRoleRestrictions(
          userId: userId,
          role: role,
          restrictedUntil: until,
        );
      }

      if (conversationId != null && conversationId.trim().isNotEmpty) {
        final state = await getUserRestriction(userId);
        if (state.isAccountRestricted || state.isBlocked) {
          await supabase
              .from('conversations')
              .update({
                'status': 'closed',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', conversationId);
        }
      }

      return getUserRestriction(userId);
    } catch (e) {
      debugPrint('Error applying policy violation: $e');
      return getUserRestriction(userId);
    }
  }

  Future<Map<String, dynamic>?> findBlockedIdentityMatch({
    String? email,
    String? phone,
    String? fullName,
  }) async {
    try {
      final filters = <String>[];
      if (email != null && email.trim().isNotEmpty) {
        filters.add('email.eq.${email.trim()}');
      }
      if (phone != null && phone.trim().isNotEmpty) {
        filters.add('phone.eq.${phone.trim()}');
      }
      if (fullName != null && fullName.trim().isNotEmpty) {
        filters.add('full_name.ilike.${fullName.trim()}');
      }
      if (filters.isEmpty) return null;

      final response = await supabase
          .from('users')
          .select(
            'id, email, full_name, phone, role, restriction_reason, off_platform_flag_count',
          )
          .eq('is_blocked', true)
          .or(filters.join(','))
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error checking blocked identity match: $e');
      return null;
    }
  }

  Future<void> markUserAsBlockedMatch({
    required String userId,
    required String matchedBlockedUserId,
    String? reason,
  }) async {
    try {
      await supabase
          .from('users')
          .update({
            'is_blocked': true,
            'is_active': false,
            'id_verified': false,
            'verification_status': 'rejected',
            'application_status': 'rejected',
            'restriction_level': 'matched_blocked_identity',
            'restriction_reason':
                reason ??
                'Matched a permanently blocked user record ($matchedBlockedUserId).',
          })
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error marking matched blocked user: $e');
    }
  }

  Future<void> _applyRoleRestrictions({
    required String userId,
    required String role,
    DateTime? restrictedUntil,
  }) async {
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedRole == 'driver') {
      try {
        await supabase
            .from('users')
            .update({'is_available': false})
            .eq('id', userId);
      } catch (e) {
        debugPrint('Unable to disable driver availability: $e');
      }
    }

    if (normalizedRole == 'partner') {
      await _voidPartnerBookings(
        userId: userId,
        restrictedUntil: restrictedUntil,
      );
      try {
        await supabase
            .from('vehicles')
            .update({'is_posted': false, 'is_available': false})
            .eq('owner_id', userId);
      } catch (e) {
        debugPrint('Unable to unlist partner vehicles: $e');
      }
      try {
        await supabase
            .from('partner_vehicles')
            .update({
              'is_available': false,
              'status': 'disabled',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('partner_id', userId);
      } catch (e) {
        debugPrint('Unable to disable partner fleet: $e');
      }
    }
  }

  Future<void> _voidPartnerBookings({
    required String userId,
    DateTime? restrictedUntil,
  }) async {
    try {
      final vehicleRows = await supabase
          .from('vehicles')
          .select('id')
          .eq('owner_id', userId);
      final vehicleIds = List<Map<String, dynamic>>.from(
        vehicleRows,
      ).map((row) => row['id']?.toString()).whereType<String>().toList();

      if (vehicleIds.isEmpty) {
        await _createOwnerRestrictionNotification(
          userId: userId,
          restrictedUntil: restrictedUntil,
          affectedBookings: 0,
        );
        return;
      }

      final affected = await supabase
          .from('bookings')
          .select(
            'id, renter_id, vehicle_id, status, operator_id, reservation_payment_reference',
          )
          .inFilter('vehicle_id', vehicleIds)
          .inFilter('status', ['pending', 'approved', 'confirmed', 'active']);

      final bookings = List<Map<String, dynamic>>.from(affected);
      for (final booking in bookings) {
        final bookingId = booking['id']?.toString();
        if (bookingId == null || bookingId.isEmpty) continue;

        await supabase
            .from('bookings')
            .update({
              'status': 'cancelled',
              'refund_status': 'refund_needed',
              'cancellation_reason':
                  'Booking cancelled due to a safety restriction on the owner account.',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', bookingId);

        await supabase
            .from('conversations')
            .update({
              'status': 'closed',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('booking_id', bookingId);

        final renterId = booking['renter_id']?.toString();
        if (renterId != null && renterId.isNotEmpty) {
          await NotificationService().createNotification(
            userId: renterId,
            title: 'Booking Cancelled for Safety Review',
            message:
                'One of your bookings was cancelled because the owner account is under safety review. Refund processing has been started if applicable.',
            type: 'booking',
            data: {
              'booking_id': bookingId,
              'status': 'cancelled',
              'event': 'policy_restriction_booking_void',
            },
          );
        }
      }

      await _createOwnerRestrictionNotification(
        userId: userId,
        restrictedUntil: restrictedUntil,
        affectedBookings: bookings.length,
      );
    } catch (e) {
      debugPrint('Error voiding partner bookings: $e');
    }
  }

  Future<void> _createOwnerRestrictionNotification({
    required String userId,
    DateTime? restrictedUntil,
    required int affectedBookings,
  }) async {
    await NotificationService().createNotification(
      userId: userId,
      title: 'Important Safety Update',
      message:
          'Your account is under a temporary restriction after a policy violation. Booking activity has been limited for safety.',
      type: 'policy_restriction',
      data: {
        'event': 'booking_void',
        'affected_bookings': affectedBookings,
        if (restrictedUntil != null)
          'restricted_until': restrictedUntil.toIso8601String(),
        'refund_status': 'refund_initiated',
      },
    );
  }

  Future<void> _recordBlockedIdentity({
    required String userId,
    String? email,
    String? phone,
    String? fullName,
  }) async {
    try {
      await supabase
          .from('users')
          .update({
            'email': email,
            'phone': phone,
            'full_name': fullName,
            'restriction_reason':
                'Account permanently blocked after repeated off-platform policy violations.',
          })
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error recording blocked identity details: $e');
    }
  }

  DateTime _maxDateTime(DateTime? a, DateTime b) {
    if (a == null) return b;
    return a.isAfter(b) ? a : b;
  }
}
