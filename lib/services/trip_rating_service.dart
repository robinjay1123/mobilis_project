import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_service.dart';
import 'booking_settlement_service.dart';
import 'image_optimization_service.dart';
import 'notification_service.dart';
import 'loyalty_service.dart';

class TripRatingService {
  static final TripRatingService _instance = TripRatingService._internal();

  factory TripRatingService() {
    return _instance;
  }

  TripRatingService._internal();

  final SupabaseClient supabase = Supabase.instance.client;

  /// Synchronizes and advances the rating flow stage for a given booking.
  Future<void> syncRatingFlowForBooking(
    String bookingId, {
    String? operatorFallbackUserId,
  }) async {
    final context = await getBookingContext(bookingId);
    if (context == null) return;
    final nextReviewer = await _nextPendingRatingReviewer(
      bookingId: bookingId,
      context: context,
      operatorFallbackUserId: operatorFallbackUserId,
    );
    final currentStage = context['completion_stage']?.toString() ?? '';
    if (nextReviewer != null && currentStage != '${nextReviewer.role}_rating') {
      await supabase
          .from('bookings')
          .update({
            'completion_stage': '${nextReviewer.role}_rating',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', bookingId);
    }
  }

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
            returned_at,
            completed_at,
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

      var vehicle = booking['vehicles'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(booking['vehicles'])
          : <String, dynamic>{};
      final rawVehicleId = context['vehicle_id']?.toString();
      if (vehicle.isEmpty && rawVehicleId != null && rawVehicleId.isNotEmpty) {
        try {
          final fetchedVehicle = await supabase
              .from('vehicles')
              .select(
                'id, owner_id, owner_role, operator_id, brand, model, year, vehicle_name, image_url, transmission, fuel_type, seats',
              )
              .eq('id', rawVehicleId)
              .maybeSingle();
          if (fetchedVehicle != null) {
            vehicle = Map<String, dynamic>.from(fetchedVehicle);
          }
        } catch (_) {}
      }

      final resolvedVehicleId = vehicle['id']?.toString() ?? rawVehicleId;
      var vImg = (vehicle['image_url']?.toString() ?? '').trim();
      if (vImg.isEmpty &&
          resolvedVehicleId != null &&
          resolvedVehicleId.isNotEmpty) {
        try {
          final imgRow = await supabase
              .from('vehicle_images')
              .select('image_url')
              .eq('vehicle_id', resolvedVehicleId)
              .order('display_order', ascending: true)
              .limit(1)
              .maybeSingle();
          if (imgRow != null && imgRow['image_url'] != null) {
            vImg = imgRow['image_url'].toString().trim();
            vehicle['image_url'] = vImg;
          }
        } catch (_) {}
      }
      context['vehicles'] = vehicle;

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
      return _loadBookingContextFallback(bookingId);
    } catch (e) {
      debugPrint('Unexpected error loading booking context: $e');
      return _loadBookingContextFallback(bookingId);
    }
  }

  /// Loads the booking context without relying on PostgREST's nested
  /// relationship aliases. Older booking rows can have a driver relationship
  /// that is valid in the database but cannot be embedded consistently by the
  /// client query, which previously made every rating target disappear.
  Future<Map<String, dynamic>?> _loadBookingContextFallback(
    String bookingId,
  ) async {
    try {
      final booking = await supabase
          .from('bookings')
          .select('*')
          .eq('id', bookingId)
          .maybeSingle();
      if (booking == null) return null;

      final context = Map<String, dynamic>.from(booking);
      final vehicleId = context['vehicle_id']?.toString().trim() ?? '';
      if (vehicleId.isNotEmpty) {
        final vehicle = await supabase
            .from('vehicles')
            .select('*')
            .eq('id', vehicleId)
            .maybeSingle();
        if (vehicle != null) {
          context['vehicles'] = Map<String, dynamic>.from(vehicle);

          final ownerId = vehicle['owner_id']?.toString().trim() ?? '';
          if (ownerId.isNotEmpty) {
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
        }
      }

      final renterId = context['renter_id']?.toString().trim() ?? '';
      if (renterId.isNotEmpty) {
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

      // bookings.driver_id references users.id in the current schema.
      final driverId = context['driver_id']?.toString().trim() ?? '';
      if (driverId.isNotEmpty) {
        final driver = await supabase
            .from('users')
            .select(
              'id, full_name, email, role, avatar_url, profile_picture_url',
            )
            .eq('id', driverId)
            .maybeSingle();
        if (driver != null) {
          context['driver'] = {
            'user_id': driver['id'],
            'users': Map<String, dynamic>.from(driver),
          };
        }
      }

      final vehicle = context['vehicles'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(context['vehicles'])
          : <String, dynamic>{};
      final operatorId = (context['operator_id'] ?? vehicle['operator_id'])
          ?.toString()
          .trim();
      if (operatorId != null && operatorId.isNotEmpty) {
        final operator = await supabase
            .from('users')
            .select(
              'id, full_name, email, role, avatar_url, profile_picture_url',
            )
            .eq('id', operatorId)
            .maybeSingle();
        if (operator != null) {
          context['operator_user'] = Map<String, dynamic>.from(operator);
        }
      }
      context['operator_user'] ??= await _findFallbackOperator();

      return context;
    } catch (error) {
      debugPrint('Fallback booking context failed: $error');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> buildTargetsForBooking({
    required String bookingId,
    required String reviewerUserId,
    required String reviewerRole,
    bool includePreviouslySubmittedForRecovery = true,
    String? operatorFallbackUserId,
  }) async {
    final context = await getBookingContext(bookingId);
    if (context == null) return [];

    String text(dynamic value) => value?.toString().trim() ?? '';
    String firstText(Iterable<dynamic> values) {
      for (final value in values) {
        final cleaned = text(value);
        if (cleaned.isNotEmpty) return cleaned;
      }
      return '';
    }

    var renter = context['renter'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['renter'])
        : <String, dynamic>{};
    final driverWrap = context['driver'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['driver'])
        : <String, dynamic>{};
    var driverUser = driverWrap['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(driverWrap['users'])
        : <String, dynamic>{};
    var owner = context['vehicle_owner'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['vehicle_owner'])
        : <String, dynamic>{};
    var operatorUser = context['operator_user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['operator_user'])
        : <String, dynamic>{};
    if (operatorUser.isEmpty) {
      final fallbackOp = await _findFallbackOperator(
        preferredUserId: operatorFallbackUserId,
      );
      if (fallbackOp != null) {
        operatorUser = fallbackOp;
      }
    }
    final vehicle = context['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['vehicles'])
        : <String, dynamic>{};

    final inferredOwnerRole = _ownerRole(context, owner);
    final renterId = firstText([
      context['renter_id'],
      renter['id'],
      renter['user_id'],
    ]);
    if (renter.isEmpty && renterId.isNotEmpty) {
      renter = {'id': renterId, 'full_name': 'Renter', 'role': 'renter'};
    }

    final driverUserId = firstText([
      driverUser['id'],
      driverUser['user_id'],
      driverWrap['user_id'],
      context['driver_id'],
    ]);
    if (driverUser.isEmpty && driverUserId.isNotEmpty) {
      driverUser = {
        'id': driverUserId,
        'full_name': 'Driver',
        'role': 'driver',
      };
    }

    final ownerId = firstText([
      owner['id'],
      owner['user_id'],
      vehicle['owner_id'],
    ]);
    if (owner.isEmpty && ownerId.isNotEmpty) {
      owner = {
        'id': ownerId,
        'full_name': inferredOwnerRole == 'partner'
            ? 'Partner'
            : 'Vehicle Owner',
        'role': inferredOwnerRole,
      };
    }

    final rawRole = reviewerRole.trim().toLowerCase();
    final cleanRole = (rawRole == 'admin' || rawRole == 'super_admin')
        ? 'operator'
        : rawRole;

    final resolvedRenterId = firstText([
      renter['id'],
      renter['user_id'],
      context['renter_id'],
    ]);
    final resolvedRenter = <String, dynamic>{
      if (renter.isNotEmpty) ...renter,
      if (resolvedRenterId.isNotEmpty) 'id': resolvedRenterId,
      'full_name': renter['full_name'] ?? context['renter_name'] ?? 'Renter',
    };

    final resolvedOperatorId = firstText([
      operatorUser['id'],
      operatorUser['user_id'],
      context['operator_id'],
      vehicle['operator_id'],
      operatorFallbackUserId,
      context['approved_by'],
      context['processed_by'],
      context['operator_user_id'],
    ]);
    final resolvedOperator = <String, dynamic>{
      if (operatorUser.isNotEmpty) ...operatorUser,
      if (resolvedOperatorId.isNotEmpty) 'id': resolvedOperatorId,
      'full_name': operatorUser['full_name'] ?? 'PSDC Operator',
    };

    final resolvedOwnerId = firstText([
      owner['id'],
      owner['user_id'],
      vehicle['owner_id'],
    ]);
    final resolvedOwner = <String, dynamic>{
      if (owner.isNotEmpty) ...owner,
      if (resolvedOwnerId.isNotEmpty) 'id': resolvedOwnerId,
      'full_name': owner['full_name'] ?? 'Vehicle Partner',
    };

    final resolvedDriverId = firstText([
      driverUser['id'],
      driverUser['user_id'],
      context['driver_id'],
    ]);
    final resolvedDriver = <String, dynamic>{
      if (driverUser.isNotEmpty) ...driverUser,
      if (resolvedDriverId.isNotEmpty) 'id': resolvedDriverId,
      'full_name': driverUser['full_name'] ?? 'Driver',
    };

    final targets = <Map<String, dynamic>>[];

    void addTarget(
      Map<String, dynamic> user,
      String role,
      String prompt, {
      bool allowSelf = false,
    }) {
      final userId = firstText([user['id'], user['user_id']]);
      if (userId.isEmpty) return;
      if (userId == reviewerUserId && !allowSelf) return;
      targets.add({
        'userId': userId,
        'role': role,
        'name': _displayName(user),
        'avatarUrl': _displayAvatar(user),
        'prompt': prompt,
        'alreadyRated': false,
      });
    }

    final ownerRole = _ownerRole(context, owner);
    final bool hasDriverFlag = context['with_driver'] == true ||
        context['with_driver']?.toString().toLowerCase() == 'true' ||
        context['with_driver']?.toString().toLowerCase() == 'yes' ||
        (context['driver_id'] != null &&
            context['driver_id'].toString().trim().isNotEmpty);
    final hasDriver = hasDriverFlag && resolvedDriverId.isNotEmpty;

    final bool isPartnerVehicle = ownerRole == 'partner' ||
        owner['role']?.toString().trim().toLowerCase() == 'partner' ||
        vehicle['owner_role']?.toString().trim().toLowerCase() == 'partner' ||
        vehicle['is_partner_vehicle'] == true ||
        vehicle['partner_vehicle_id'] != null;

    if (cleanRole == 'renter') {
      if (isPartnerVehicle && resolvedOwnerId.isNotEmpty) {
        addTarget(resolvedOwner, 'partner', 'How was the partner and vehicle service?', allowSelf: true);
      }
      if (resolvedOperatorId.isNotEmpty) {
        addTarget(resolvedOperator, 'operator', 'How was the PSDC operator and rental service?', allowSelf: true);
      }
      if (hasDriver) {
        addTarget(
          resolvedDriver,
          'driver',
          'How was your experience with the driver?',
          allowSelf: true,
        );
      }
      // Renter also rates the vehicle
      final vehicleId = firstText([vehicle['id'], context['vehicle_id']]);
      if (vehicleId.isNotEmpty) {
        final vehicleName = text(vehicle['vehicle_name']).isNotEmpty
            ? text(vehicle['vehicle_name'])
            : [text(vehicle['brand']), text(vehicle['model']), text(vehicle['year'])]
                  .where((s) => s.isNotEmpty)
                  .join(' ');
        final fallbackName = text(context['car_name']).isNotEmpty
            ? text(context['car_name'])
            : text(context['carName']);
        var imageUrl = text(vehicle['image_url']);
        if (imageUrl.isEmpty) {
          imageUrl = text(context['vehicle_image_url']).isNotEmpty
              ? text(context['vehicle_image_url'])
              : text(context['car_image_url']);
        }
        // Collect all vehicle images for the carousel
        final rawVehicleImages = vehicle['vehicle_images'];
        final List<Map<String, dynamic>> vehicleImages =
            (rawVehicleImages is List)
                ? rawVehicleImages
                    .whereType<Map<String, dynamic>>()
                    .toList()
                : <Map<String, dynamic>>[];

        targets.add({
          'userId': vehicleId,
          'role': 'vehicle',
          'name': vehicleName.isNotEmpty
              ? vehicleName
              : (fallbackName.isNotEmpty ? fallbackName : 'Rental Vehicle'),
          'avatarUrl': imageUrl,
          'imageUrl': imageUrl,
          'vehicleImages': vehicleImages,
          'brand': text(vehicle['brand']),
          'model': text(vehicle['model']),
          'year': text(vehicle['year']),
          'prompt': 'How was the vehicle overall?',
          'alreadyRated': false,
        });

      }
    } else if (cleanRole == 'driver') {
      addTarget(resolvedRenter, 'renter', 'How was the renter during the trip?');
      if (resolvedOperatorId.isNotEmpty) {
        addTarget(resolvedOperator, 'operator', 'How was the operator support?');
      }
      if (isPartnerVehicle && resolvedOwnerId.isNotEmpty) {
        addTarget(resolvedOwner, 'partner', 'How was the partner vehicle support?');
      }
    } else if (cleanRole == 'partner') {
      if (resolvedRenterId.isNotEmpty) {
        addTarget(resolvedRenter, 'renter', 'How was the renter during this booking?', allowSelf: true);
      }
      if (hasDriver) {
        addTarget(resolvedDriver, 'driver', 'How was the assigned driver?');
      }
      if (resolvedOperatorId.isNotEmpty) {
        addTarget(resolvedOperator, 'operator', 'How was the operator support?');
      }
    } else if (cleanRole == 'operator') {
      // 1. Operator ALWAYS rates Renter
      if (resolvedRenterId.isNotEmpty) {
        addTarget(resolvedRenter, 'renter', 'How was the renter during this booking?', allowSelf: true);
      }
      // 2. Operator rates Partner ONLY if Partner Vehicle
      if (isPartnerVehicle && resolvedOwnerId.isNotEmpty && resolvedOwnerId != reviewerUserId) {
        addTarget(resolvedOwner, 'partner', 'How was the partner coordination and vehicle?');
      }
      // 3. Operator rates Driver ONLY if Driver was used
      if (hasDriver && resolvedDriverId.isNotEmpty && resolvedDriverId != reviewerUserId) {
        addTarget(resolvedDriver, 'driver', 'How was the assigned driver during this trip?');
      }
      // Operator NEVER rates the vehicle
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

    if (includePreviouslySubmittedForRecovery) {
      return uniqueTargets;
    }

    final pendingTargets = uniqueTargets
        .where((target) => target['alreadyRated'] != true)
        .toList();
    return pendingTargets;
  }

  Future<bool> isReviewerRatingComplete({
    required String bookingId,
    required String reviewerUserId,
    required String reviewerRole,
    String? operatorFallbackUserId,
  }) async {
    final cleanRole = (reviewerRole == 'admin' || reviewerRole == 'super_admin')
        ? 'operator'
        : reviewerRole.trim().toLowerCase();
    final resolvedOperatorFallback =
        (cleanRole == 'operator' ? reviewerUserId : operatorFallbackUserId)?.trim();

    final remaining = await buildTargetsForBooking(
      bookingId: bookingId,
      reviewerUserId: reviewerUserId,
      reviewerRole: cleanRole,
      includePreviouslySubmittedForRecovery: false,
      operatorFallbackUserId: resolvedOperatorFallback,
    );
    return remaining.isEmpty;
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
    final operatorFallbackUserId = cleanReviewerRole == 'operator'
        ? reviewerUserId
        : null;
    await _assertAuthorizedReviewer(
      context: context,
      reviewerUserId: reviewerUserId,
      reviewerRole: cleanReviewerRole,
    );
    var pendingTargets = await buildTargetsForBooking(
      bookingId: bookingId,
      reviewerUserId: reviewerUserId,
      reviewerRole: cleanReviewerRole,
      includePreviouslySubmittedForRecovery: false,
      operatorFallbackUserId: operatorFallbackUserId,
    );
    if (pendingTargets.isEmpty) {
      pendingTargets = await buildTargetsForBooking(
        bookingId: bookingId,
        reviewerUserId: reviewerUserId,
        reviewerRole: cleanReviewerRole,
        includePreviouslySubmittedForRecovery: true,
        operatorFallbackUserId: operatorFallbackUserId,
      );
    }
    final targetIsPending = pendingTargets.any(
      (target) =>
          target['userId']?.toString() == targetUserId &&
          target['role']?.toString().trim().toLowerCase() ==
              targetRole.trim().toLowerCase(),
    );
    if (!targetIsPending) {
      throw Exception('This rating is already submitted or not required');
    }

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

    if (targetRole.trim().toLowerCase() == 'vehicle') {
      await _refreshVehicleRating(targetUserId);
    } else {
      await _refreshTargetProfileRating(targetUserId, targetRole);
    }
    await _advanceCompletionAfterReviewer(
      context: context,
      reviewerUserId: reviewerUserId,
      reviewerRole: cleanReviewerRole,
      operatorFallbackUserId: operatorFallbackUserId,
    );
  }

  Future<void> _assertAuthorizedReviewer({
    required Map<String, dynamic> context,
    required String reviewerUserId,
    required String reviewerRole,
  }) async {
    String text(dynamic value) => value?.toString().trim() ?? '';
    String firstText(Iterable<dynamic> values) {
      for (final value in values) {
        final cleaned = text(value);
        if (cleaned.isNotEmpty) return cleaned;
      }
      return '';
    }

    final renterId = text(context['renter_id']);
    final owner = context['vehicle_owner'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['vehicle_owner'])
        : <String, dynamic>{};
    final vehicle = context['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['vehicles'])
        : <String, dynamic>{};
    final ownerId = firstText([
      owner['id'],
      owner['user_id'],
      vehicle['owner_id'],
    ]);
    final ownerRole = _ownerRole(context, owner);
    final driver = context['driver'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['driver'])
        : <String, dynamic>{};
    final driverUser = driver['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(driver['users'])
        : <String, dynamic>{};
    final driverUserId = firstText([
      driverUser['id'],
      driverUser['user_id'],
      driver['user_id'],
      context['driver_id'],
    ]);

    var authorized = false;
    final normalizedReviewerRole =
        (reviewerRole == 'admin' || reviewerRole == 'super_admin')
            ? 'operator'
            : reviewerRole.trim().toLowerCase();

    switch (normalizedReviewerRole) {
      case 'renter':
        authorized = reviewerUserId == renterId;
        break;
      case 'driver':
        authorized = reviewerUserId == driverUserId;
        break;
      case 'partner':
        authorized = (ownerRole == 'partner' && reviewerUserId == ownerId);
        if (!authorized) {
          final user = await supabase
              .from('users')
              .select('role')
              .eq('id', reviewerUserId)
              .maybeSingle();
          final role = user?['role']?.toString().trim().toLowerCase();
          authorized = role == 'operator' || role == 'admin' || role == 'super_admin';
        }
        break;
      case 'operator':
        final user = await supabase
            .from('users')
            .select('role')
            .eq('id', reviewerUserId)
            .maybeSingle();
        final role = user?['role']?.toString().trim().toLowerCase();
        final isOpsUser =
            role == 'operator' || role == 'admin' || role == 'super_admin';
        if (isOpsUser) {
          authorized = true;
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
    String? operatorFallbackUserId,
  }) async {
    final bookingId = context['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;
    final resolvedOperatorFallback =
        (reviewerRole == 'operator' ? reviewerUserId : operatorFallbackUserId)
            ?.trim();

    final remainingTargets = await buildTargetsForBooking(
      bookingId: bookingId,
      reviewerUserId: reviewerUserId,
      reviewerRole: reviewerRole,
      includePreviouslySubmittedForRecovery: false,
      operatorFallbackUserId: resolvedOperatorFallback,
    );
    if (remainingTargets.isNotEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final confirmationColumn = '${reviewerRole}_trip_confirmed_at';
    final progressedContext = <String, dynamic>{
      ...context,
      confirmationColumn: now,
    };
    final baseBookingUpdate = <String, dynamic>{
      confirmationColumn: now,
      'updated_at': now,
    };
    if (reviewerRole == 'operator' &&
        (context['operator_id']?.toString().trim().isEmpty ?? true)) {
      progressedContext['operator_id'] =
          resolvedOperatorFallback ?? reviewerUserId;
      baseBookingUpdate['operator_id'] =
          resolvedOperatorFallback ?? reviewerUserId;
    }

    // Persist this reviewer as complete before checking the next stage. The
    // final revenue settlement reloads the booking from Supabase, so relying
    // only on the in-memory context can falsely report "already completed" or
    // block completion after a valid rating.
    await supabase
        .from('bookings')
        .update(baseBookingUpdate)
        .eq('id', bookingId);

    final nextReviewer = await _nextPendingRatingReviewer(
      bookingId: bookingId,
      context: progressedContext,
      operatorFallbackUserId: resolvedOperatorFallback,
    );
    if (nextReviewer != null) {
      final bookingUpdate = <String, dynamic>{
        'completion_stage': '${nextReviewer.role}_rating',
        'updated_at': now,
      };
      await supabase.from('bookings').update(bookingUpdate).eq('id', bookingId);
      await _notifyNextReviewer(
        userId: nextReviewer.userId,
        bookingId: bookingId,
        role: nextReviewer.role,
      );
      return;
    }

    await _finalizeCompletedBooking(
      context: progressedContext,
      reviewerUserId: reviewerUserId,
      completedAt: now,
    );
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

  /// Returns the next pending reviewer in the mandatory sequence, or null when
  /// all reviewers have finished and the booking can be finalized.
  ///
  /// Sequence (non-renter roles always go before the renter):
  ///   1. Partner (if partner-owned vehicle) or Operator (PSDC vehicle)
  ///   2. Driver  (if assigned)
  ///   3. Renter  (always last)
  Future<({String role, String userId})?> _nextPendingRatingReviewer({
    required String bookingId,
    required Map<String, dynamic> context,
    String? operatorFallbackUserId,
  }) async {
    String text(dynamic v) => v?.toString().trim() ?? '';
    String firstText(Iterable<dynamic> values) {
      for (final value in values) {
        final cleaned = text(value);
        if (cleaned.isNotEmpty) return cleaned;
      }
      return '';
    }

    final owner = context['vehicle_owner'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['vehicle_owner'])
        : <String, dynamic>{};
    final vehicle = context['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['vehicles'])
        : <String, dynamic>{};
    final driver = context['driver'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['driver'])
        : <String, dynamic>{};
    final driverUser = driver['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(driver['users'])
        : <String, dynamic>{};

    final isPartnerVehicle = _ownerRole(context, owner) == 'partner';
    final operatorUser = context['operator_user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(context['operator_user'])
        : <String, dynamic>{};
    final ownerId = firstText([
      owner['id'],
      owner['user_id'],
      vehicle['owner_id'],
    ]);
    final operatorId = firstText([
      context['operator_id'],
      operatorFallbackUserId,
      operatorUser['id'],
      operatorUser['user_id'],
      vehicle['operator_id'],
      context['approved_by'],
      context['processed_by'],
      context['operator_user_id'],
    ]);
    final driverUserId = firstText([
      driverUser['id'],
      driverUser['user_id'],
      driver['user_id'],
      context['driver_id'],
    ]);
    final renterId = text(context['renter_id']);

    final firstRole = isPartnerVehicle ? 'partner' : 'operator';
    final firstId = isPartnerVehicle ? ownerId : operatorId;

    final hasDriver = driverUserId.isNotEmpty;

    Future<bool> ratingExists({
      required String reviewerId,
      required String targetId,
      required String targetRole,
    }) async {
      if (reviewerId.isEmpty || targetId.isEmpty) return false;
      return _hasExistingRating(
        bookingId: bookingId,
        reviewerUserId: reviewerId,
        targetUserId: targetId,
        targetRole: targetRole,
      );
    }

    // Rating progress must be based on actual trip_ratings rows. The
    // *_trip_confirmed_at fields are used by checklist/payment stages and can
    // otherwise make the app think a rating was already submitted.
    final firstConfirmed = await ratingExists(
      reviewerId: firstId,
      targetId: renterId,
      targetRole: 'renter',
    );
    final driverConfirmed = hasDriver
        ? await ratingExists(
            reviewerId: driverUserId,
            targetId: renterId,
            targetRole: 'renter',
          )
        : false;

    var renterConfirmed = false;
    if (renterId.isNotEmpty) {
      final renterTargets = <({String id, String role})>[
        if (firstId.isNotEmpty) (id: firstId, role: firstRole),
        if (hasDriver) (id: driverUserId, role: 'driver'),
      ];
      if (renterTargets.isNotEmpty) {
        renterConfirmed = true;
        for (final target in renterTargets) {
          final done = await ratingExists(
            reviewerId: renterId,
            targetId: target.id,
            targetRole: target.role,
          );
          if (!done) {
            renterConfirmed = false;
            break;
          }
        }
      }
    }

    // Step 1 — partner or operator
    if (!firstConfirmed && firstId.isNotEmpty && renterId.isNotEmpty) {
      return (role: firstRole, userId: firstId);
    }

    // Step 2 — driver (only if assigned and step 1 done)
    if (firstConfirmed &&
        hasDriver &&
        !driverConfirmed &&
        renterId.isNotEmpty) {
      return (role: 'driver', userId: driverUserId);
    }

    // Step 3 — renter (after all non-renter reviewers are done)
    final allNonRenterDone = firstConfirmed && (!hasDriver || driverConfirmed);
    if (allNonRenterDone && !renterConfirmed && renterId.isNotEmpty) {
      return (role: 'renter', userId: renterId);
    }

    // All reviewers done — signal finalization.
    return null;
  }

  /// Aggregates all trip_ratings rows for a vehicle (target_role = 'vehicle')
  /// and updates vehicles.rating and vehicles.rating_count.
  Future<void> _refreshVehicleRating(String vehicleId) async {
    try {
      await getVehicleRatingSummary(vehicleId);
    } catch (e) {
      debugPrint('Skipping vehicle rating update: $e');
    }
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

    final completionOperator =
        completionContext['operator_user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(completionContext['operator_user'])
        : <String, dynamic>{};
    final settlementOperatorFallback =
        completionContext['operator_id']?.toString().trim().isNotEmpty == true
        ? completionContext['operator_id'].toString()
        : completionOperator['id']?.toString();

    await _releaseSettlementWithoutBlockingCompletion(
      bookingId: bookingId,
      updatedAt: completedAt,
      operatorFallbackUserId: settlementOperatorFallback,
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

    final renterId = completionContext['renter_id']?.toString();
    if (renterId != null && renterId.isNotEmpty) {
      await LoyaltyService().awardPointsForCompletedBooking(
        bookingId,
        renterId: renterId,
        totalCost: (completionContext['total_price'] as num?)?.toDouble() ?? 0.0,
      );
    }

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
  Future<bool> reconcileCompletedBooking(
    String bookingId, {
    String? operatorFallbackUserId,
  }) async {
    var context = await getBookingContext(bookingId);
    if (context == null) return false;
    final cleanOperatorFallback = operatorFallbackUserId?.trim();
    final status = context['status']?.toString().trim().toLowerCase();
    final now = DateTime.now().toUtc().toIso8601String();
    if (cleanOperatorFallback?.isNotEmpty == true &&
        (context['operator_id']?.toString().trim().isEmpty ?? true)) {
      await supabase
          .from('bookings')
          .update({'operator_id': cleanOperatorFallback, 'updated_at': now})
          .eq('id', bookingId);
      context = {...context, 'operator_id': cleanOperatorFallback};
    }
    if (status == 'completed' || status == 'returned') {
      // A terminal booking can still have stale completion metadata. Verify
      // the actual mandatory rating rows before treating it as fully rated.
      try {
        await _assertAllRequiredRatingsComplete(bookingId);
      } catch (error) {
        debugPrint('Completed booking still has pending ratings: $error');
        return false;
      }
      await _releaseSettlementWithoutBlockingCompletion(
        bookingId: bookingId,
        updatedAt: now,
        operatorFallbackUserId: cleanOperatorFallback,
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
    String? operatorFallbackUserId,
  }) async {
    try {
      await BookingSettlementService().releaseForCompletedBooking(
        bookingId,
        operatorFallbackUserId: operatorFallbackUserId,
      );
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
    if (!_isManualFinalPaymentConfirmed(
      latestContext['final_payment_status'],
    )) {
      throw Exception('The final payment must be confirmed first');
    }

    String text(dynamic value) => value?.toString().trim() ?? '';

    final owner = latestContext['vehicle_owner'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(latestContext['vehicle_owner'])
        : <String, dynamic>{};
    final vehicle = latestContext['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(latestContext['vehicles'])
        : <String, dynamic>{};
    final driver = latestContext['driver'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(latestContext['driver'])
        : <String, dynamic>{};
    final driverUser = driver['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(driver['users'])
        : <String, dynamic>{};
    final isPartnerVehicle = _ownerRole(latestContext, owner) == 'partner';
    final renterId = text(latestContext['renter_id']);
    final operatorUser = latestContext['operator_user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(latestContext['operator_user'])
        : <String, dynamic>{};
    final ownerId = text(owner['id']).isNotEmpty
        ? text(owner['id'])
        : text(vehicle['owner_id']);
    var operatorId = text(latestContext['operator_id']).isNotEmpty
        ? text(latestContext['operator_id'])
        : text(operatorUser['id']).isNotEmpty
        ? text(operatorUser['id'])
        : text(vehicle['operator_id']);
    if (operatorId.isEmpty && !isPartnerVehicle) {
      final fallbackOp = await _findFallbackOperator();
      if (fallbackOp != null) {
        operatorId = text(fallbackOp['id']).isNotEmpty
            ? text(fallbackOp['id'])
            : text(fallbackOp['user_id']);
      }
    }
    final firstReviewerRole = isPartnerVehicle ? 'partner' : 'operator';
    final firstReviewerId = isPartnerVehicle ? ownerId : operatorId;
    final driverUserId = text(driverUser['id']).isNotEmpty
        ? text(driverUser['id'])
        : text(driver['user_id']).isNotEmpty
        ? text(driver['user_id'])
        : text(latestContext['driver_id']);
    final hasDriver = driverUserId.isNotEmpty;
    final renterPrimaryTargetId = isPartnerVehicle ? ownerId : operatorId;
    final requiredPairs =
        <
          ({
            String reviewerRole,
            String reviewerId,
            String targetRole,
            String targetId,
          })
        >[
          if (firstReviewerId.isNotEmpty && renterId.isNotEmpty)
            (
              reviewerRole: firstReviewerRole,
              reviewerId: firstReviewerId,
              targetRole: 'renter',
              targetId: renterId,
            ),
          if (hasDriver && driverUserId.isNotEmpty && renterId.isNotEmpty)
            (
              reviewerRole: 'driver',
              reviewerId: driverUserId,
              targetRole: 'renter',
              targetId: renterId,
            ),
          if (renterId.isNotEmpty && renterPrimaryTargetId.isNotEmpty)
            (
              reviewerRole: 'renter',
              reviewerId: renterId,
              targetRole: isPartnerVehicle ? 'partner' : 'operator',
              targetId: renterPrimaryTargetId,
            ),
          if (hasDriver && renterId.isNotEmpty && driverUserId.isNotEmpty)
            (
              reviewerRole: 'renter',
              reviewerId: renterId,
              targetRole: 'driver',
              targetId: driverUserId,
            ),
        ];

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

  bool _isManualFinalPaymentConfirmed(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return false;
    return const {
      'paid',
      'fully_paid',
      'full_paid',
      'verified',
      'settled',
      'released',
      'completed',
      'confirmed',
      'final_paid',
      'payment_verified',
    }.contains(normalized);
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

  /// Fetches rating summary (average & count) for a specific vehicle.
  Future<Map<String, dynamic>> getVehicleRatingSummary(String vehicleId) async {
    if (vehicleId.trim().isEmpty) return {'average': 0.0, 'count': 0};
    try {
      // 1. Direct query by target_user_id (where target_role is vehicle or default)
      final response = await supabase
          .from('trip_ratings')
          .select('rating')
          .eq('target_user_id', vehicleId);

      var rows = List<Map<String, dynamic>>.from(response);

      // 2. Check linked partner_vehicles or canonical vehicle ID
      String? altVehicleId;
      try {
        final pv = await supabase
            .from('partner_vehicles')
            .select('id, vehicle_id')
            .or('id.eq.$vehicleId,vehicle_id.eq.$vehicleId')
            .maybeSingle();
        if (pv != null) {
          final id1 = pv['id']?.toString();
          final id2 = pv['vehicle_id']?.toString();
          altVehicleId = (id1 != vehicleId ? id1 : id2);
        }
      } catch (_) {}

      if (altVehicleId != null && altVehicleId.isNotEmpty) {
        final altResponse = await supabase
            .from('trip_ratings')
            .select('rating')
            .eq('target_user_id', altVehicleId);
        rows.addAll(List<Map<String, dynamic>>.from(altResponse));
      }

      // 3. If still empty, check bookings with this vehicle_id
      if (rows.isEmpty) {
        final vehicleFilter = altVehicleId != null && altVehicleId.isNotEmpty
            ? [vehicleId, altVehicleId]
            : [vehicleId];
        final bookingRows = await supabase
            .from('bookings')
            .select('id')
            .inFilter('vehicle_id', vehicleFilter);
        final bookingIds = (bookingRows as List)
            .map((b) => b['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        if (bookingIds.isNotEmpty) {
          final ratingsResponse = await supabase
              .from('trip_ratings')
              .select('rating')
              .inFilter('booking_id', bookingIds)
              .eq('target_role', 'vehicle');
          rows = List<Map<String, dynamic>>.from(ratingsResponse);
        }
      }

      if (rows.isEmpty) {
        // Fallback: check stored rating on vehicles table
        try {
          final vRow = await supabase
              .from('vehicles')
              .select('rating, rating_count')
              .eq('id', vehicleId)
              .maybeSingle();
          if (vRow != null) {
            final storedRating = (vRow['rating'] as num?)?.toDouble() ?? 0.0;
            final storedCount = (vRow['rating_count'] as num?)?.toInt() ?? 0;
            if (storedRating > 0) {
              return {
                'average': storedRating,
                'count': storedCount > 0 ? storedCount : 1,
              };
            }
          }
        } catch (_) {}
        return {'average': 0.0, 'count': 0};
      }

      double total = 0;
      for (final row in rows) {
        total += (row['rating'] as num?)?.toDouble() ?? 0;
      }
      final average = total / rows.length;
      final count = rows.length;

      // Sync back to vehicles table for caching
      try {
        await supabase
            .from('vehicles')
            .update({'rating': average, 'rating_count': count})
            .eq('id', vehicleId);
      } catch (_) {}
      try {
        await supabase
            .from('partner_vehicles')
            .update({'rating': average, 'rating_count': count})
            .eq('id', vehicleId);
      } catch (_) {}
      try {
        await supabase
            .from('partner_vehicles')
            .update({'rating': average, 'rating_count': count})
            .eq('vehicle_id', vehicleId);
      } catch (_) {}

      return {'average': average, 'count': count};
    } catch (e) {
      debugPrint('Error fetching vehicle rating summary: $e');
      return {'average': 0.0, 'count': 0};
    }
  }

  /// Batch hydrates real ratings and counts for a list of vehicle records
  Future<void> batchHydrateVehicleRatings(
    List<Map<String, dynamic>> vehicles,
  ) async {
    if (vehicles.isEmpty) return;
    try {
      final vehicleIds = vehicles
          .map((v) => v['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (vehicleIds.isEmpty) return;

      final ratingsResponse = await supabase
          .from('trip_ratings')
          .select('target_user_id, rating')
          .inFilter('target_user_id', vehicleIds)
          .eq('target_role', 'vehicle');

      final ratingsByVehicle = <String, List<double>>{};
      for (final r in ratingsResponse) {
        final id = r['target_user_id']?.toString();
        final score = (r['rating'] as num?)?.toDouble();
        if (id != null && score != null && score > 0) {
          ratingsByVehicle.putIfAbsent(id, () => []).add(score);
        }
      }

      for (final v in vehicles) {
        final id = v['id']?.toString() ?? '';
        final scores = ratingsByVehicle[id];
        if (scores != null && scores.isNotEmpty) {
          final avg = scores.reduce((a, b) => a + b) / scores.length;
          v['rating'] = avg;
          v['rating_count'] = scores.length;
        } else {
          final rawRating = (v['rating'] as num?)?.toDouble() ?? 0.0;
          final rawCount = (v['rating_count'] as num?)?.toInt() ?? 0;
          if (rawRating > 0) {
            v['rating'] = rawRating;
            v['rating_count'] = rawCount > 0 ? rawCount : 1;
          }
        }
      }
    } catch (e) {
      debugPrint('batchHydrateVehicleRatings error: $e');
    }
  }

  /// Fetches received reviews/ratings for a specific vehicle.
  Future<List<Map<String, dynamic>>> getVehicleReceivedRatings(
    String vehicleId, {
    int limit = 30,
  }) async {
    if (vehicleId.trim().isEmpty) return [];
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
          .eq('target_user_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(limit);

      var ratings = List<Map<String, dynamic>>.from(response);

      // Check partner_vehicles or canonical vehicle link
      String? altVehicleId;
      try {
        final pv = await supabase
            .from('partner_vehicles')
            .select('id, vehicle_id')
            .or('id.eq.$vehicleId,vehicle_id.eq.$vehicleId')
            .maybeSingle();
        if (pv != null) {
          final id1 = pv['id']?.toString();
          final id2 = pv['vehicle_id']?.toString();
          altVehicleId = (id1 != vehicleId ? id1 : id2);
        }
      } catch (_) {}

      if (altVehicleId != null && altVehicleId.isNotEmpty) {
        final altResponse = await supabase
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
            .eq('target_user_id', altVehicleId)
            .order('created_at', ascending: false)
            .limit(limit);
        ratings.addAll(List<Map<String, dynamic>>.from(altResponse));
      }

      if (ratings.isEmpty) {
        final vehicleFilter = altVehicleId != null && altVehicleId.isNotEmpty
            ? [vehicleId, altVehicleId]
            : [vehicleId];
        final bookingRows = await supabase
            .from('bookings')
            .select('id')
            .inFilter('vehicle_id', vehicleFilter);
        final bookingIds = (bookingRows as List)
            .map((b) => b['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        if (bookingIds.isNotEmpty) {
          final bookingRatingsResponse = await supabase
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
              .inFilter('booking_id', bookingIds)
              .eq('target_role', 'vehicle')
              .order('created_at', ascending: false)
              .limit(limit);
          ratings = List<Map<String, dynamic>>.from(bookingRatingsResponse);
        }
      }

      // Deduplicate by rating id
      final seenIds = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final r in ratings) {
        final id = r['id']?.toString() ?? '';
        if (id.isNotEmpty && seenIds.contains(id)) continue;
        if (id.isNotEmpty) seenIds.add(id);
        deduped.add(r);
      }

      return deduped;
    } catch (e) {
      debugPrint('Error fetching vehicle received ratings: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _findFallbackOperator({
    String? preferredUserId,
  }) async {
    try {
      const columns =
          'id, full_name, email, role, avatar_url, profile_picture_url';
      if (preferredUserId != null && preferredUserId.isNotEmpty) {
        final directUser = await supabase
            .from('users')
            .select(columns)
            .eq('id', preferredUserId)
            .maybeSingle();
        if (directUser != null) {
          return Map<String, dynamic>.from(directUser);
        }
      }
      final operators = await supabase
          .from('users')
          .select(columns)
          .or('role.eq.operator,role.eq.admin,role.eq.super_admin')
          .limit(1);
      if ((operators as List).isNotEmpty) {
        return Map<String, dynamic>.from(operators.first);
      }
      return null;
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
