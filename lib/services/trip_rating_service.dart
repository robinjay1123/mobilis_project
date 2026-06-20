import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            renter:renter_id (
              id,
              full_name,
              email,
              role,
              avatar_url,
              profile_picture_url
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
    final ownerRole = owner['role']?.toString().trim().toLowerCase() ?? '';
    final hasDriver = driverUser.isNotEmpty;

    if (cleanRole == 'renter') {
      if (hasDriver) {
        addTarget(
          driverUser,
          'driver',
          'How was your experience with the driver?',
        );
      }
      addTarget(
        operatorUser,
        'operator',
        'How was the operator support and service?',
      );
      if (ownerRole == 'partner') {
        addTarget(owner, 'partner', 'How was the partner and vehicle care?');
      }
    } else if (cleanRole == 'driver') {
      if (ownerRole == 'partner') {
        addTarget(owner, 'partner', 'How was the partner coordination?');
      }
      addTarget(operatorUser, 'operator', 'How was the operator support?');
      addTarget(renter, 'renter', 'How was the renter during the trip?');
    } else if (cleanRole == 'partner') {
      if (hasDriver) {
        addTarget(
          driverUser,
          'driver',
          'How was the driver handling your car?',
        );
      }
      addTarget(operatorUser, 'operator', 'How was the operator service?');
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

    return uniqueTargets
        .where((target) => target['alreadyRated'] != true)
        .toList();
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
    final uploadedUrls = imageFiles == null || imageFiles.isEmpty
        ? <String>[]
        : await _uploadReviewImages(
            bookingId: bookingId,
            reviewerUserId: reviewerUserId,
            targetRole: targetRole,
            imageFiles: imageFiles,
          );

    await supabase.from('trip_ratings').insert({
      'booking_id': bookingId,
      'reviewer_user_id': reviewerUserId,
      'reviewer_role': reviewerRole,
      'target_user_id': targetUserId,
      'target_role': targetRole,
      'rating': rating,
      'comment': (comment ?? '').trim(),
      'tags': tags ?? <String>[],
      'image_urls': uploadedUrls,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _refreshTargetProfileRating(targetUserId, targetRole);
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
      final bytes = await file.readAsBytes();
      final extension = file.path.contains('.')
          ? file.path.split('.').last.toLowerCase()
          : 'jpg';
      final objectPath =
          '$reviewerUserId/${bookingId}_${targetRole}_${DateTime.now().millisecondsSinceEpoch}_$i.$extension';

      await supabase.storage
          .from(_bucketName)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
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
