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
            'id, role, off_platform_flag_count, is_blocked, is_active, chat_restricted_until, account_restricted_until, restriction_reason, restriction_level',
          )
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return UserRestrictionState.empty;

      final isBlocked = response['is_blocked'] == true;
      final chatRestrictedUntil = DateTime.tryParse(
        response['chat_restricted_until']?.toString() ?? '',
      )?.toLocal();
      final accountRestrictedUntil = DateTime.tryParse(
        response['account_restricted_until']?.toString() ?? '',
      )?.toLocal();
      final level = response['restriction_level']?.toString().trim() ?? 'none';
      final role = response['role']?.toString().trim().toLowerCase() ?? '';
      final now = DateTime.now();

      final isPermanentBlocked =
          level == 'third_attempt_blocked' ||
          level == 'matched_blocked_identity';
      final hasExpiredAccount =
          accountRestrictedUntil != null && accountRestrictedUntil.isBefore(now);
      final hasExpiredChat =
          chatRestrictedUntil != null && chatRestrictedUntil.isBefore(now);

      // If temporary restriction has expired (e.g. 7 days or 30 days have passed), auto-unban!
      if (!isPermanentBlocked &&
          (hasExpiredAccount ||
              hasExpiredChat ||
              (isBlocked &&
                  accountRestrictedUntil == null &&
                  chatRestrictedUntil == null &&
                  level != 'third_attempt_blocked' &&
                  level != 'matched_blocked_identity'))) {
        if (hasExpiredAccount || hasExpiredChat) {
          await liftExpiredRestriction(userId: userId, role: role);
          return UserRestrictionState.empty;
        }
      }

      return UserRestrictionState(
        violationCount:
            (response['off_platform_flag_count'] as num?)?.toInt() ?? 0,
        isBlocked:
            isBlocked &&
            (isPermanentBlocked ||
                (accountRestrictedUntil != null &&
                    accountRestrictedUntil.isAfter(now))),
        chatRestrictedUntil: chatRestrictedUntil,
        accountRestrictedUntil: accountRestrictedUntil,
        reason: response['restriction_reason']?.toString().trim() ?? '',
        level: level,
      );
    } catch (e) {
      debugPrint('Error fetching user restriction state: $e');
      return UserRestrictionState.empty;
    }
  }

  /// Automatically lifts expired temporary restrictions (e.g. after 7 days)
  Future<void> liftExpiredRestriction({
    required String userId,
    String? role,
  }) async {
    try {
      debugPrint('Automatically lifting expired restriction for user: $userId');

      await supabase
          .from('users')
          .update({
            'is_active': true,
            'is_blocked': false,
            'chat_restricted_until': null,
            'account_restricted_until': null,
            'restriction_reason': null,
            'restriction_level': 'none',
            'verification_status': 'verified',
            'id_verified': true,
          })
          .eq('id', userId);

      final normalizedRole = role?.trim().toLowerCase() ?? '';
      if (normalizedRole == 'driver') {
        try {
          await supabase
              .from('users')
              .update({'is_available': true})
              .eq('id', userId);
        } catch (e) {
          debugPrint('Error restoring driver availability: $e');
        }
      }

      if (normalizedRole == 'partner') {
        try {
          await supabase
              .from('vehicles')
              .update({'is_available': true, 'is_posted': true})
              .eq('owner_id', userId);
        } catch (e) {
          debugPrint('Error restoring partner vehicles: $e');
        }
        try {
          await supabase
              .from('partner_vehicles')
              .update({
                'is_available': true,
                'status': 'approved',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('partner_id', userId);
        } catch (e) {
          debugPrint('Error restoring partner fleet: $e');
        }
      }

      // Clear safety freeze on any active bookings for this renter
      try {
        await supabase
            .from('bookings')
            .update({
              'safety_freeze': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('renter_id', userId)
            .inFilter('status', ['active', 'ongoing'])
            .eq('safety_freeze', true);
      } catch (e) {
        debugPrint('Error lifting safety freeze on renter bookings: $e');
      }

      try {
        await NotificationService().createNotification(
          userId: userId,
          title: 'Account Restriction Ended',
          message:
              'Your temporary restriction has concluded. Full access to messaging and bookings has been restored.',
          type: 'policy_restriction',
          data: {'event': 'restriction_lifted_auto'},
        );
      } catch (e) {
        debugPrint('Error sending auto-unban notification: $e');
      }
    } catch (e) {
      debugPrint('Error lifting expired restriction: $e');
    }
  }

  /// Batch scans and clears all expired user restrictions across the platform
  Future<void> processExpiredRestrictions() async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      final expiredUsers = await supabase
          .from('users')
          .select(
            'id, role, account_restricted_until, chat_restricted_until, restriction_level',
          )
          .or('account_restricted_until.lte.$nowIso,chat_restricted_until.lte.$nowIso');

      final list = List<Map<String, dynamic>>.from(expiredUsers);
      for (final user in list) {
        final level = user['restriction_level']?.toString().trim() ?? '';
        if (level == 'third_attempt_blocked' ||
            level == 'matched_blocked_identity') {
          continue; // Permanent blocks require admin unban
        }
        final userId = user['id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          await liftExpiredRestriction(
            userId: userId,
            role: user['role']?.toString(),
          );
        }
      }
    } catch (e) {
      debugPrint('Error processing expired restrictions: $e');
    }
  }

  /// Manually unbans and reactivates a user, clearing all blocks, flags, and restrictions
  Future<Map<String, dynamic>> unbanUser(String userId) async {
    try {
      debugPrint('Manually unbanning user: $userId');

      final userResponse = await supabase
          .from('users')
          .select('id, role, email, full_name')
          .eq('id', userId)
          .maybeSingle();

      final role =
          userResponse?['role']?.toString().trim().toLowerCase() ?? '';

      await supabase
          .from('users')
          .update({
            'is_active': true,
            'is_blocked': false,
            'chat_restricted_until': null,
            'account_restricted_until': null,
            'restriction_reason': null,
            'restriction_level': 'none',
            'off_platform_flag_count': 0,
            'suspension_reason': null,
            'suspended_at': null,
            'verification_status': 'verified',
            'id_verified': true,
          })
          .eq('id', userId);

      if (role == 'driver') {
        try {
          await supabase
              .from('users')
              .update({'is_available': true})
              .eq('id', userId);
        } catch (e) {
          debugPrint('Error enabling driver availability on unban: $e');
        }
      }

      if (role == 'partner') {
        try {
          await supabase
              .from('vehicles')
              .update({'is_available': true, 'is_posted': true})
              .eq('owner_id', userId);
        } catch (e) {
          debugPrint('Error enabling partner vehicles on unban: $e');
        }
        try {
          await supabase
              .from('partner_vehicles')
              .update({
                'is_available': true,
                'status': 'approved',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('partner_id', userId);
        } catch (e) {
          debugPrint('Error enabling partner fleet on unban: $e');
        }
      }

      // Clear safety freeze on any active bookings for this renter
      try {
        await supabase
            .from('bookings')
            .update({
              'safety_freeze': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('renter_id', userId)
            .inFilter('status', ['active', 'ongoing'])
            .eq('safety_freeze', true);
      } catch (e) {
        debugPrint('Error lifting safety freeze on renter bookings on unban: $e');
      }

      try {
        await supabase
            .from('message_flags')
            .update({
              'status': 'dismissed',
              'admin_notes': 'Dismissed on manual unban/reactivation',
              'reviewed_at': DateTime.now().toIso8601String(),
            })
            .eq('sender_id', userId)
            .eq('status', 'pending_review');
      } catch (e) {
        debugPrint('Error dismissing flags on unban: $e');
      }

      try {
        await NotificationService().createNotification(
          userId: userId,
          title: 'Account Reactivated',
          message:
              'Your account has been unbanned and reactivated by administration. Full access to messaging, bookings, and platform features has been restored.',
          type: 'policy_restriction',
          data: {'event': 'manual_unban_reactivated'},
        );
      } catch (e) {
        debugPrint('Error sending unban notification: $e');
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error in unbanUser: $e');
      return {'success': false, 'error': e.toString()};
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
        await _handleRenterBookingsOnViolation(userId: userId);
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
        await _handleRenterBookingsOnViolation(
          userId: userId,
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

  /// Permanently bans and blocks a user account immediately across all platform roles & bookings
  Future<void> blockUserPermanently(String userId, String reason) async {
    try {
      final userResponse = await supabase
          .from('users')
          .select('id, role, email, phone, full_name')
          .eq('id', userId)
          .maybeSingle();

      final role = userResponse?['role']?.toString().trim().toLowerCase() ?? '';
      final now = DateTime.now().toIso8601String();

      await supabase
          .from('users')
          .update({
            'is_blocked': true,
            'is_active': false,
            'id_verified': false,
            'verification_status': 'rejected',
            'application_status': 'rejected',
            'chat_restricted_until': null,
            'account_restricted_until': null,
            'restriction_level': 'third_attempt_blocked',
            'restriction_reason': reason,
            'suspension_reason': reason,
            'suspended_at': now,
            'updated_at': now,
          })
          .eq('id', userId);

      await _applyRoleRestrictions(userId: userId, role: role);
      await _handleRenterBookingsOnViolation(userId: userId);

      await _recordBlockedIdentity(
        userId: userId,
        email: userResponse?['email']?.toString(),
        phone: userResponse?['phone']?.toString(),
        fullName: userResponse?['full_name']?.toString(),
      );
    } catch (e) {
      debugPrint('Error in blockUserPermanently: $e');
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

  /// Handles renter's bookings when a policy violation occurs:
  /// 1. Auto-cancels upcoming/pending bookings, frees vehicles, and initiates refund.
  /// 2. Applies Safety Freeze on active/ongoing trips (keeps live recovery, tracking, & return checklist active; locks extensions).
  Future<void> _handleRenterBookingsOnViolation({
    required String userId,
    DateTime? restrictedUntil,
  }) async {
    try {
      final rows = await supabase
          .from('bookings')
          .select(
            'id, renter_id, vehicle_id, status, operator_id, start_date, end_date, total_amount, vehicle:vehicles(id, make, model, year, plate_number, owner_id)',
          )
          .eq('renter_id', userId)
          .inFilter('status', [
            'pending',
            'pending_approval',
            'approved',
            'confirmed',
            'awaiting_driver',
            'active',
            'ongoing',
          ]);

      final bookings = List<Map<String, dynamic>>.from(rows);
      if (bookings.isEmpty) return;

      for (final booking in bookings) {
        final bookingId = booking['id']?.toString();
        final vehicleId = booking['vehicle_id']?.toString();
        final status = booking['status']?.toString().trim().toLowerCase() ?? '';
        if (bookingId == null || bookingId.isEmpty) continue;

        final vehicle = booking['vehicle'] as Map<String, dynamic>?;
        final vehicleName = vehicle != null
            ? '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
            : 'Vehicle';
        final ownerId = vehicle?['owner_id']?.toString();
        final operatorId = booking['operator_id']?.toString();

        final isActiveTrip = status == 'active' || status == 'ongoing';

        if (isActiveTrip) {
          // 1. ACTIVE TRIP: Apply Safety Freeze (Do NOT cancel or terminate tracking!)
          debugPrint('Applying Safety Freeze to active trip booking #$bookingId');
          await supabase.from('bookings').update({
            'safety_freeze': true,
            'cancellation_reason':
                'Active trip under Safety Freeze: Renter account is under safety review. Extensions and new bookings blocked; live recovery & return inspection remain active.',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', bookingId);

          // Alert Renter
          await NotificationService().createNotification(
            userId: userId,
            title: 'Active Trip Safety Notice',
            message:
                'Your account is currently under safety review. Your active trip for $vehicleName is under a Safety Freeze. Trip extensions are locked, but your live return and emergency services remain active.',
            type: 'policy_restriction',
            data: {
              'booking_id': bookingId,
              'event': 'active_trip_safety_freeze',
              if (restrictedUntil != null)
                'restricted_until': restrictedUntil.toIso8601String(),
            },
          );

          // Alert Vehicle Owner / Partner
          if (ownerId != null && ownerId.isNotEmpty && ownerId != userId) {
            await NotificationService().createNotification(
              userId: ownerId,
              title: '⚠️ Active Trip Safety Alert (Safety Freeze)',
              message:
                  'The renter on active booking #$bookingId for your $vehicleName triggered a safety violation. The trip is placed in Safety Freeze (extensions locked, tracking and return inspection active). Please monitor until return.',
              type: 'policy_restriction',
              data: {
                'booking_id': bookingId,
                'vehicle_id': vehicleId,
                'event': 'owner_active_safety_freeze',
              },
            );
          }

          // Alert Operator
          if (operatorId != null && operatorId.isNotEmpty) {
            await NotificationService().createNotification(
              userId: operatorId,
              title: '⚠️ Active Trip Safety Freeze Alert',
              message:
                  'Renter on active booking #$bookingId ($vehicleName) has triggered a policy violation. Trip is in Safety Freeze.',
              type: 'policy_restriction',
              data: {
                'booking_id': bookingId,
                'operator_id': operatorId,
                'event': 'operator_active_safety_freeze',
              },
            );
          }
        } else {
          // 2. UPCOMING / PENDING: Auto-Cancel & Initiate Refund & Free Vehicle
          debugPrint('Auto-cancelling upcoming booking #$bookingId due to renter violation');
          await supabase.from('bookings').update({
            'status': 'cancelled',
            'refund_status': 'refund_needed',
            'cancellation_reason':
                'Booking cancelled automatically due to a safety policy violation on the renter account.',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', bookingId);

          // Free vehicle
          if (vehicleId != null && vehicleId.isNotEmpty) {
            try {
              await supabase
                  .from('vehicles')
                  .update({'is_available': true})
                  .eq('id', vehicleId);
            } catch (e) {
              debugPrint('Error freeing vehicle $vehicleId: $e');
            }
          }

          // Close chat conversation
          try {
            await supabase
                .from('conversations')
                .update({
                  'status': 'closed',
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('booking_id', bookingId);
          } catch (e) {
            debugPrint('Error closing conversation for cancelled booking: $e');
          }

          // Notify Renter
          await NotificationService().createNotification(
            userId: userId,
            title: 'Upcoming Booking Cancelled',
            message:
                'Your upcoming reservation for $vehicleName was cancelled because your account is under safety review. Refund processing has been initiated.',
            type: 'booking',
            data: {
              'booking_id': bookingId,
              'status': 'cancelled',
              'event': 'renter_violation_cancelled',
            },
          );

          // Notify Vehicle Owner / Partner
          if (ownerId != null && ownerId.isNotEmpty && ownerId != userId) {
            await NotificationService().createNotification(
              userId: ownerId,
              title: 'Upcoming Booking Cancelled',
              message:
                  'Upcoming booking #$bookingId for your $vehicleName was cancelled due to a safety violation on the renter account. Your vehicle is now available for new bookings.',
              type: 'booking',
              data: {
                'booking_id': bookingId,
                'vehicle_id': vehicleId,
                'status': 'cancelled',
                'event': 'renter_violation_vehicle_freed',
              },
            );
          }

          // Notify Operator
          if (operatorId != null && operatorId.isNotEmpty) {
            await NotificationService().createNotification(
              userId: operatorId,
              title: 'Booking Cancelled (Renter Safety Violation)',
              message:
                  'Booking #$bookingId ($vehicleName) has been automatically cancelled due to renter safety violation.',
              type: 'booking',
              data: {
                'booking_id': bookingId,
                'status': 'cancelled',
                'event': 'operator_booking_auto_cancelled',
              },
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling renter bookings on violation: $e');
    }
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
