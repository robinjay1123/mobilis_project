import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_service.dart';
import 'booking_settlement_service.dart';
import 'image_optimization_service.dart';
import 'notification_service.dart';

class TripRatingService {
  static final TripRatingService _instance = TripRatingService._internal();

  factory TripRatingService() {
    return _instance;
  }

  TripRatingService._internal();

  final SupabaseClient supabase = Supabase.instance.client;
  static const String _bucketName = 'trip_review_images';

  Future<Map<String, dynamic>?> getBookingContext(String bookingId) async {
    try {
      final booking = await supabase
          .from('bookings')
          .select('''
            id,
            renter_id,
            vehicle_id,
            driver_id,
            operator_id,
            with_driver,
            status,
            completion_stage,
            final_payment_status,
            operator_trip_confirmed_at,
            partner_trip_confirmed_at,
            driver_trip_confirmed_at,
            renter_trip_confirmed_at,
            start_at,
            end_at,
            start_date,
            end_date,
            total_price,
            total_cost,
            pickup_location,
            dropoff_location,
            vehicles:vehicle_id (
              id,
              owner_id,
              owner_role,
              operator_id,
              brand,
              model,
              year,
              vehicle_name,
              image_url,
              transmission,
              fuel_type,
              seats
            ),
            driver:drivers!bookings_driver_id_fkey (
              id,
              user_id,
              rating,
              users!drivers_user_id_fkey (
                id,
                full_name,
                email,
                role,
                avatar_url,
                profile_picture_url
              )
            )
          ''')
          .eq('id', bookingId)
          .maybeSingle();

      if (booking == null) return null;

      final context = Map<String, dynamic>.from(booking);
      final renterId = context['renter_id']?.toString();
      if (renterId != null && renterId.isNotEmpty) {
        final renter = await supabase
            .from('users')
            .select(
              'id, full_name, email, role, avatar_url, profile_picture_url',
            )
            .eq('id', renterId)
            .maybeSingle();
        if (renter != null) {
          context['renter'] = Map<String, dynamic>.from(renter);
        }
      }

      final vehicle = booking['vehicles'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(booking['vehicles'])
          : <String, dynamic>{};
      final ownerId = vehicle['owner_id']?.toString();
      final operatorId =
          context['operator_id']?.toString() ??
          vehicle['operator_id']?.toString();

      if (ownerId != null && ownerId.isNotEmpty) {
        final owner = await supabase
            .from('users')
            .select(
              'id, full_name, email, role, avatar_url, profile_picture_url',
            )
            .eq('id', ownerId)
            .maybeSingle();
        if (owner != null) {
          context['vehicle_owner'] = Map<String, dynamic>.from(owner);
        }
      }

      final assignedDriverId = context['driver_id']?.toString();
      final embeddedDriver = context['driver'];
      if (assignedDriverId != null &&
          assignedDriverId.isNotEmpty &&
          embeddedDriver is! Map<String, dynamic>) {
        final driverUser = await _findAssignedDriverUser(assignedDriverId);
        if (driverUser != null) {
          context['driver'] = {
            'user_id': driverUser['id'],
            'users': driverUser,
          };
        }
      }

      Map<String, dynamic>? operatorUser;
      if (operatorId != null && operatorId.isNotEmpty) {
        final operator = await supabase
            .from('users')
            .select(
              'id, full_name, email, role, avatar_url, profile_picture_url',
            )
            .eq('id', operatorId)
            .maybeSingle();
        if (operator != null) {
          operatorUser = Map<String, dynamic>.from(operator);
        }
      }

      operatorUser ??= await _findFallbackOperator();
      if (operatorUser != null) {
        context['operator_user'] = operatorUser;
      }

      return context;
    } on PostgrestException catch (e) {
      debugPrint('Database error loading booking context: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Unexpected error loading booking context: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> buildTargetsForBooking({
    required String bookingId,
    required String reviewerUserId,
    required String reviewerRole,
    bool includePreviouslySubmittedForRecovery = true,
  }) async {
    final context = await getBookingContext(bookingId);
    if (context == null) return [];

    final renter = context['renter'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['renter'])
        : <String, dynamic>{};
    final driverWrap = context['driver'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['driver'])
        : <String, dynamic>{};
    final driverUser = driverWrap['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(driverWrap['users'])
        : <String, dynamic>{};
    final owner = context['vehicle_owner'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['vehicle_owner'])
        : <String, dynamic>{};
    final operatorUser = context['operator_user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['operator_user'])
        : <String, dynamic>{};

    final targets = <Map<String, dynamic>>[];

    void addTarget(Map<String, dynamic> user, String role, String prompt) {
      final userId =
          user['id']?.toString() ?? user['user_id']?.toString() ?? '';
      if (userId.isEmpty || userId == reviewerUserId) return;
      targets.add({
        'userId': userId,
        'role': role,
        'name': _displayName(user),
        'avatarUrl': _displayAvatar(user),
        'prompt': prompt,
        'alreadyRated': false,
      });
    }

    final cleanRole = reviewerRole.trim().toLowerCase();
    final ownerRole = _ownerRole(context, owner);
    final hasDriver = driverUser.isNotEmpty;
    final isPartnerVehicle = ownerRole == 'partner';
    final expectedStage = '${cleanRole}_rating';
    final completionStage = context['completion_stage']
        ?.toString()
        .trim()
        .toLowerCase();
    if (completionStage != expectedStage) return [];

    if (cleanRole == 'renter') {
      if (isPartnerVehicle) {
        addTarget(owner, 'partner', 'How was the partner and vehicle service?');
      } else {
        addTarget(
          operatorUser,
          'operator',
          'How was the PSDC operator and vehicle service?',
        );
      }
      if (hasDriver) {
        addTarget(
          driverUser,
          'driver',
          'How was your experience with the driver?',
        );
      }
    } else if (cleanRole == 'driver') {
      addTarget(renter, 'renter', 'How was the renter during the trip?');
    } else if (cleanRole == 'partner') {
      if (isPartnerVehicle) {
        addTarget(renter, 'renter', 'How was the renter during this booking?');
      }
    } else if (cleanRole == 'operator' && !isPartnerVehicle) {
      addTarget(renter, 'renter', 'How was the renter during this booking?');
    }

    final deduped = <String, Map<String, dynamic>>{};
    for (final target in targets) {
      final key = '${target['userId']}_${target['role']}';
      deduped[key] = target;
    }

    final uniqueTargets = deduped.values.toList();
    for (final target in uniqueTargets) {
      target['alreadyRated'] = await _hasExistingRating(
        bookingId: bookingId,
        reviewerUserId: reviewerUserId,
        targetUserId: target['userId'].toString(),
        targetRole: target['role'].toString(),
      );
    }

    final pendingTargets = uniqueTargets
        .where((target) => target['alreadyRated'] != true)
        .toList();
    if (pendingTargets.isNotEmpty) return pendingTargets;

    // A rating can be saved before the booking-stage update completes (for
    // example after a lost connection). In that case the booking still points
    // at this reviewer even though the rating row already exists. Return the
    // targets again so submitting safely upserts the review and advances the
    // completion workflow instead of showing a false "already completed"
    // state.
    if (includePreviouslySubmittedForRecovery && uniqueTargets.isNotEmpty) {
      return uniqueTargets;
    }

    return const <Map<String, dynamic>>[];
  }

  Future<void> submitRating({
    required String bookingId,
    required String reviewerUserId,
    required String reviewerRole,
    required String targetUserId,
    required String targetRole,
    required double rating,
    String? comment,
    List<String>? tags,
    List<File>? imageFiles,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5 stars');
    }
    final context = await getBookingContext(bookingId);
    if (context == null) throw Exception('Booking not found');
    final cleanReviewerRole = reviewerRole.trim().toLowerCase();
    final expectedStage = '${cleanReviewerRole}_rating';
    final currentStage = context['completion_stage']
        ?.toString()
        .trim()
        .toLowerCase();
    if (currentStage != expectedStage) {
      throw Exception('This rating is not available at the current trip stage');
    }
    await _assertAuthorizedReviewer(
      context: context,
      reviewerUserId: reviewerUserId,
      reviewerRole: cleanReviewerRole,
    );

    final uploadedUrls = imageFiles == null || imageFiles.isEmpty
        ? <String>[]
        : await _uploadReviewImages(
            bookingId: bookingId,
            reviewerUserId: reviewerUserId,
            targetRole: targetRole,
            imageFiles: imageFiles,
          );

    final now = DateTime.now().toUtc().toIso8601String();
    await supabase.from('trip_ratings').upsert({
      'booking_id': bookingId,
      'reviewer_user_id': reviewerUserId,
      'reviewer_role': cleanReviewerRole,
      'target_user_id': targetUserId,
      'target_role': targetRole,
      'rating': rating,
      'comment': (comment ?? '').trim(),
      'tags': tags ?? <String>[],
      'image_urls': uploadedUrls,
      'updated_at': now,
    }, onConflict: 'booking_id,reviewer_user_id,target_user_id,target_role');

    await _refreshTargetProfileRating(targetUserId, targetRole);
    await _advanceCompletionAfterReviewer(
      context: context,
      reviewerUserId: reviewerUserId,
      reviewerRole: cleanReviewerRole,
    );
  }

  Future<void> _assertAuthorizedReviewer({
    required Map<String, dynamic> context,
    required String reviewerUserId,
    required String reviewerRole,
  }) async {
    final renterId = context['renter_id']?.toString();
    final operatorId = context['operator_id']?.toString();
    final owner = context['vehicle_owner'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['vehicle_owner'])
        : <String, dynamic>{};
    final ownerId = owner['id']?.toString();
    final ownerRole = _ownerRole(context, owner);
    final driver = context['driver'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['driver'])
        : <String, dynamic>{};
    final driverUser = driver['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(driver['users'])
        : <String, dynamic>{};
    final driverUserId =
        driverUser['id']?.toString() ?? context['driver_id']?.toString();

    var authorized = false;
    switch (reviewerRole) {
      case 'renter':
        authorized = reviewerUserId == renterId;
        break;
      case 'driver':
        authorized = reviewerUserId == driverUserId;
        break;
      case 'partner':
        authorized = ownerRole == 'partner' && reviewerUserId == ownerId;
        break;
      case 'operator':
        if (ownerRole != 'partner') {
          authorized =
              operatorId == null ||
              operatorId.isEmpty ||
              operatorId == reviewerUserId;
          if (authorized) {
            final user = await supabase
                .from('users')
                .select('role')
                .eq('id', reviewerUserId)
                .maybeSingle();
            authorized =
                user?['role']?.toString().trim().toLowerCase() == 'operator';
          }
        }
        break;
    }
    if (!authorized) {
      throw Exception('You are not authorized to submit this trip rating');
    }
  }

  Future<void> _advanceCompletionAfterReviewer({
    required Map<String, dynamic> context,
    required String reviewerUserId,
    required String reviewerRole,
  }) async {
    final bookingId = context['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final remainingTargets = await buildTargetsForBooking(
      bookingId: bookingId,
      reviewerUserId: reviewerUserId,
      reviewerRole: reviewerRole,
      includePreviouslySubmittedForRecovery: false,
    );
    if (remainingTargets.isNotEmpty) return;

    final driver = context['driver'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['driver'])
        : <String, dynamic>{};
    final driverUser = driver['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(driver['users'])
        : <String, dynamic>{};
    final driverUserId = driverUser['id']?.toString();
    final renterId = context['renter_id']?.toString();
    final now = DateTime.now().toUtc().toIso8601String();
    final confirmationColumn = '${reviewerRole}_trip_confirmed_at';

    if (reviewerRole == 'operator' || reviewerRole == 'partner') {
      final nextStage = driverUserId?.isNotEmpty == true
          ? 'driver_rating'
          : 'renter_rating';
      final bookingUpdate = <String, dynamic>{
        confirmationColumn: now,
        'completion_stage': nextStage,
        'updated_at': now,
      };
      // Older PSDC bookings may not have an assigned operator. Bind the
      // operator who performs the return review so the renter rates the same
      // person who actually handled the trip.
      if (reviewerRole == 'operator' &&
          (context['operator_id']?.toString().trim().isEmpty ?? true)) {
        bookingUpdate['operator_id'] = reviewerUserId;
      }
      await supabase.from('bookings').update(bookingUpdate).eq('id', bookingId);
      await _notifyNextReviewer(
        userId: driverUserId?.isNotEmpty == true ? driverUserId! : renterId,
        bookingId: bookingId,
        role: driverUserId?.isNotEmpty == true ? 'driver' : 'renter',
      );
      return;
    }

    if (reviewerRole == 'driver') {
      await supabase
          .from('bookings')
          .update({
            confirmationColumn: now,
            'completion_stage': 'renter_rating',
            'updated_at': now,
          })
          .eq('id', bookingId);
      await _notifyNextReviewer(
        userId: renterId,
        bookingId: bookingId,
        role: 'renter',
      );
      return;
    }

    if (reviewerRole == 'renter') {
      await _finalizeCompletedBooking(
        context: context,
        reviewerUserId: reviewerUserId,
        completedAt: now,
      );
    }
  }

  Future<void> _notifyNextReviewer({
    required String? userId,
    required String bookingId,
    required String role,
  }) async {
    if (userId == null || userId.isEmpty) return;
    await NotificationService().createNotification(
      userId: userId,
      title: 'Mandatory Trip Rating Required',
      message: role == 'renter'
          ? 'The other trip participants have finished their ratings. Submit your final rating to complete the trip.'
          : 'Submit your renter rating to continue the trip completion process.',
      type: 'trip_rating_required',
      data: {'booking_id': bookingId, 'reviewer_role': role},
    );
  }

  Future<void> _finalizeCompletedBooking({
    required Map<String, dynamic> context,
    required String reviewerUserId,
    required String completedAt,
  }) async {
    final bookingId = context['id']?.toString() ?? '';
    final completionContext = await _assertAllRequiredRatingsComplete(
      bookingId,
    );
    final ratingsResponse = await supabase
        .from('trip_ratings')
        .select('rating')
        .eq('booking_id', bookingId);
    final ratings = List<Map<String, dynamic>>.from(ratingsResponse);
    final ratingCount = ratings.length;
    final ratingAverage = ratingCount == 0
        ? 0.0
        : ratings.fold<double>(
                0,
                (sum, row) => sum + ((row['rating'] as num?)?.toDouble() ?? 0),
              ) /
              ratingCount;

    // Completion is the source of truth for trip history and revenue. Commit
    // it before the retryable accounting work so a temporary ledger failure
    // cannot leave a fully paid and fully rated trip stuck as ongoing.
    await supabase
        .from('bookings')
        .update({
          'status': 'completed',
          'completed_at': completedAt,
          'renter_trip_confirmed_at': completedAt,
          'completion_stage': 'completed',
          'completion_rating_average': ratingAverage,
          'completion_rating_count': ratingCount,
          'commission_status': 'processing',
          'commission_eligible_at': completedAt,
          'updated_at': completedAt,
        })
        .eq('id', bookingId);

    await _releaseSettlementWithoutBlockingCompletion(
      bookingId: bookingId,
      updatedAt: completedAt,
    );

    final driverUserId = completionContext['driver_id']?.toString();
    if (driverUserId?.isNotEmpty == true) {
      await supabase
          .from('users')
          .update({'is_available': true})
          .eq('id', driverUserId!);
      try {
        await supabase
            .from('driver_job_assignments')
            .update({'status': 'completed', 'updated_at': completedAt})
            .eq('booking_id', bookingId);
      } catch (e) {
        debugPrint('Could not finalize driver assignment after ratings: $e');
      }
    }

    final conversation = await ChatService().getConversationByBookingId(
      bookingId,
    );
    final conversationId = conversation?['id']?.toString();
    if (conversationId?.isNotEmpty == true) {
      await ChatService().sendBookingAuditMessage(
        conversationId: conversationId!,
        senderId: reviewerUserId,
        content:
            'Trip completed successfully. Full payment, return inspection, and all mandatory participant ratings are recorded.',
        auditKey: 'trip-completed-$bookingId',
      );
    }
    await ChatService().closeConversation(bookingId);

    final participantIds = <String>{
      if (completionContext['renter_id']?.toString().isNotEmpty == true)
        completionContext['renter_id'].toString(),
      if (driverUserId?.isNotEmpty == true) driverUserId!,
      if (completionContext['operator_id']?.toString().isNotEmpty == true)
        completionContext['operator_id'].toString(),
    };
    final owner = completionContext['vehicle_owner'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(completionContext['vehicle_owner'])
        : <String, dynamic>{};
    if (owner['id']?.toString().isNotEmpty == true) {
      participantIds.add(owner['id'].toString());
    }
    for (final userId in participantIds) {
      await NotificationService().createNotification(
        userId: userId,
        title: 'Trip Successfully Completed',
        message:
            'The return, full payment, and required ratings are complete. This booking is now successful.',
        type: 'booking_completed',
        data: {'booking_id': bookingId},
      );
    }
  }

  /// Repairs bookings where every rating was saved but an earlier settlement
  /// attempt failed before the booking could advance to Completed.
  Future<bool> reconcileCompletedBooking(String bookingId) async {
    final context = await getBookingContext(bookingId);
    if (context == null) return false;
    final status = context['status']?.toString().trim().toLowerCase();
    final now = DateTime.now().toUtc().toIso8601String();
    if (status == 'completed') {
      await _releaseSettlementWithoutBlockingCompletion(
        bookingId: bookingId,
        updatedAt: now,
      );
      return true;
    }

    try {
      await _assertAllRequiredRatingsComplete(bookingId);
    } catch (_) {
      return false;
    }
    await _finalizeCompletedBooking(
      context: context,
      reviewerUserId: context['renter_id']?.toString() ?? '',
      completedAt: now,
    );
    return true;
  }

  Future<void> _releaseSettlementWithoutBlockingCompletion({
    required String bookingId,
    required String updatedAt,
  }) async {
    try {
      await BookingSettlementService().releaseForCompletedBooking(bookingId);
      await supabase
          .from('bookings')
          .update({'commission_status': 'released', 'updated_at': updatedAt})
          .eq('id', bookingId);
    } catch (error) {
      debugPrint('Settlement retry required for booking $bookingId: $error');
      await supabase
          .from('bookings')
          .update({
            'commission_status': 'settlement_failed',
            'updated_at': updatedAt,
          })
          .eq('id', bookingId);
    }
  }

  Future<Map<String, dynamic>> _assertAllRequiredRatingsComplete(
    String bookingId,
  ) async {
    final latestContext = await getBookingContext(bookingId);
    if (latestContext == null) throw Exception('Booking not found');
    if (latestContext['final_payment_status']
            ?.toString()
            .trim()
            .toLowerCase() !=
        'paid') {
      throw Exception('The final payment must be confirmed first');
    }

    final owner = latestContext['vehicle_owner'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(latestContext['vehicle_owner'])
        : <String, dynamic>{};
    final driver = latestContext['driver'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(latestContext['driver'])
        : <String, dynamic>{};
    final driverUser = driver['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(driver['users'])
        : <String, dynamic>{};
    final isPartnerVehicle = _ownerRole(latestContext, owner) == 'partner';
    final renterId = latestContext['renter_id']?.toString() ?? '';
    final operatorUser = latestContext['operator_user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(latestContext['operator_user'])
        : <String, dynamic>{};
    final firstReviewerRole = isPartnerVehicle ? 'partner' : 'operator';
    final firstReviewerId = isPartnerVehicle
        ? owner['id']?.toString() ?? ''
        : latestContext['operator_id']?.toString() ??
              operatorUser['id']?.toString() ??
              '';
    final driverUserId =
        driverUser['id']?.toString() ??
        latestContext['driver_id']?.toString() ??
        '';
    final renterPrimaryTargetId = isPartnerVehicle
        ? owner['id']?.toString() ?? ''
        : latestContext['operator_id']?.toString() ??
              operatorUser['id']?.toString() ??
              '';
    final requiredPairs =
        <
          ({
            String reviewerRole,
            String reviewerId,
            String targetRole,
            String targetId,
          })
        >[
          (
            reviewerRole: firstReviewerRole,
            reviewerId: firstReviewerId,
            targetRole: 'renter',
            targetId: renterId,
          ),
          if (driverUser.isNotEmpty)
            (
              reviewerRole: 'driver',
              reviewerId: driverUserId,
              targetRole: 'renter',
              targetId: renterId,
            ),
          (
            reviewerRole: 'renter',
            reviewerId: renterId,
            targetRole: isPartnerVehicle ? 'partner' : 'operator',
            targetId: renterPrimaryTargetId,
          ),
          if (driverUser.isNotEmpty)
            (
              reviewerRole: 'renter',
              reviewerId: renterId,
              targetRole: 'driver',
              targetId: driverUserId,
            ),
        ];

    if (requiredPairs.any(
      (pair) => pair.reviewerId.isEmpty || pair.targetId.isEmpty,
    )) {
      throw Exception('A required trip participant could not be identified');
    }

    final response = await supabase
        .from('trip_ratings')
        .select('reviewer_user_id, reviewer_role, target_user_id, target_role')
        .eq('booking_id', bookingId);
    final rows = List<Map<String, dynamic>>.from(response);
    for (final pair in requiredPairs) {
      final exists = rows.any(
        (row) =>
            row['reviewer_role']?.toString().trim().toLowerCase() ==
                pair.reviewerRole &&
            row['reviewer_user_id']?.toString() == pair.reviewerId &&
            row['target_role']?.toString().trim().toLowerCase() ==
                pair.targetRole &&
            row['target_user_id']?.toString() == pair.targetId,
      );
      if (!exists) {
        throw Exception(
          'All mandatory participant ratings must be submitted before completion',
        );
      }
    }
    return latestContext;
  }

  Future<Map<String, dynamic>> getRatingSummary(String userId) async {
    try {
      final response = await supabase
          .from('trip_ratings')
          .select('rating')
          .eq('target_user_id', userId);

      final rows = List<Map<String, dynamic>>.from(response);
      if (rows.isEmpty) {
        return {'average': 0.0, 'count': 0};
      }

      double total = 0;
      for (final row in rows) {
        total += (row['rating'] as num?)?.toDouble() ?? 0;
      }

      return {'average': total / rows.length, 'count': rows.length};
    } catch (e) {
      debugPrint('Error fetching rating summary: $e');
      return {'average': 0.0, 'count': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getReceivedRatings(
    String userId, {
    int limit = 20,
  }) async {
    try {
      final response = await supabase
          .from('trip_ratings')
          .select('''
            *,
            reviewer:reviewer_user_id (
              id,
              full_name,
              email,
              role,
              avatar_url,
              profile_picture_url
            )
          ''')
          .eq('target_user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching received ratings: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _findFallbackOperator() async {
    try {
      final operator = await supabase
          .from('users')
          .select('id, full_name, email, role, avatar_url, profile_picture_url')
          .eq('role', 'operator')
          .limit(1)
          .maybeSingle();
      if (operator == null) return null;
      return Map<String, dynamic>.from(operator);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _findAssignedDriverUser(
    String assignedDriverId,
  ) async {
    const columns =
        'id, full_name, email, role, avatar_url, profile_picture_url';
    try {
      final directUser = await supabase
          .from('users')
          .select(columns)
          .eq('id', assignedDriverId)
          .maybeSingle();
      if (directUser != null) return Map<String, dynamic>.from(directUser);

      final driver = await supabase
          .from('drivers')
          .select('users!drivers_user_id_fkey ($columns)')
          .eq('id', assignedDriverId)
          .maybeSingle();
      final user = driver?['users'];
      return user is Map<String, dynamic>
          ? Map<String, dynamic>.from(user)
          : null;
    } catch (_) {
      return null;
    }
  }

  String _ownerRole(Map<String, dynamic> context, Map<String, dynamic> owner) {
    final vehicle = context['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['vehicles'])
        : <String, dynamic>{};
    return (vehicle['owner_role'] ?? owner['role'])
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
  }

  Future<bool> _hasExistingRating({
    required String bookingId,
    required String reviewerUserId,
    required String targetUserId,
    required String targetRole,
  }) async {
    try {
      final existing = await supabase
          .from('trip_ratings')
          .select('id')
          .eq('booking_id', bookingId)
          .eq('reviewer_user_id', reviewerUserId)
          .eq('target_user_id', targetUserId)
          .eq('target_role', targetRole)
          .limit(1);
      return existing.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _uploadReviewImages({
    required String bookingId,
    required String reviewerUserId,
    required String targetRole,
    required List<File> imageFiles,
  }) async {
    final uploadedUrls = <String>[];
    for (var i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final originalBytes = await file.readAsBytes();
      final extension = file.path.contains('.')
          ? file.path.split('.').last.toLowerCase()
          : 'jpg';
      final objectPath =
          '$reviewerUserId/${bookingId}_${targetRole}_${DateTime.now().millisecondsSinceEpoch}_$i.$extension';
      final bytes = await ImageOptimizationService.optimizeForUpload(
        originalBytes,
        fileName: objectPath,
      );

      await supabase.storage
          .from(_bucketName)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              cacheControl: '31536000',
            ),
          );

      uploadedUrls.add(
        supabase.storage.from(_bucketName).getPublicUrl(objectPath),
      );
    }
    return uploadedUrls;
  }

  Future<void> _refreshTargetProfileRating(
    String targetUserId,
    String targetRole,
  ) async {
    final summary = await getRatingSummary(targetUserId);
    final average = (summary['average'] as num?)?.toDouble() ?? 0.0;
    final count = (summary['count'] as num?)?.toInt() ?? 0;

    await _safeUpdateUserRating(targetUserId, average, count);

    switch (targetRole.trim().toLowerCase()) {
      case 'driver':
        await _safeUpdateRoleRatingTable(
          'drivers',
          targetUserId,
          average,
          count,
        );
        break;
      case 'partner':
        await _safeUpdateRoleRatingTable(
          'partners',
          targetUserId,
          average,
          count,
        );
        break;
      case 'renter':
        await _safeUpdateRoleRatingTable(
          'renters',
          targetUserId,
          average,
          count,
        );
        break;
      case 'operator':
        break;
    }
  }

  Future<void> _safeUpdateUserRating(
    String userId,
    double average,
    int count,
  ) async {
    try {
      await supabase
          .from('users')
          .update({'rating': average, 'rating_count': count})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Skipping users rating update: $e');
    }
  }

  Future<void> _safeUpdateRoleRatingTable(
    String table,
    String userId,
    double average,
    int count,
  ) async {
    try {
      await supabase
          .from(table)
          .update({'rating': average, 'rating_count': count})
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Skipping $table rating update: $e');
    }
  }

  String _displayName(Map<String, dynamic> user) {
    final name = user['full_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Mobilis User';
  }

  String _displayAvatar(Map<String, dynamic> user) {
    final avatar = user['avatar_url']?.toString().trim();
    if (avatar != null && avatar.isNotEmpty) return avatar;
    return user['profile_picture_url']?.toString().trim() ?? '';
  }
}
