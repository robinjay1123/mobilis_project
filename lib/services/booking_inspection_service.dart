import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_optimization_service.dart';

class BookingInspectionService {
  BookingInspectionService._();

  static final BookingInspectionService _instance =
      BookingInspectionService._();

  factory BookingInspectionService() => _instance;

  final SupabaseClient supabase = Supabase.instance.client;

  static const Map<String, Map<String, String>> checklistSections = {
    'Exterior': {
      'headlights_taillights': 'Headlights & taillights working',
      'side_mirrors': 'Side mirrors intact',
      'windshield_wipers': 'Windshield wipers ok',
      'tires': 'Tires',
      'mags': 'Mags',
      'body_scratches_dents': 'Gasgas or dents (take photo/video)',
      'engine_bay': 'Engine Bay (take photo/video)',
    },
    'Interior': {
      'aircon': 'Aircon working',
      'dashboard_radio_charger': 'Dashboard / radio / charger port ok',
      'mattings': 'Mattings',
      'seatbelts': 'Seatbelts working',
    },
    'Tools & Accessories': {
      'spare_tire': 'Spare tire',
      'jack': 'Jack',
      'wrench_tools': 'Wrench & Tools',
      'early_warning_device': 'Early warning device',
      'orcr_copy': 'Copy of ORCR',
      'autosweep_card': 'Autosweep card',
      'easytrip_card': 'Easytrip card',
    },
    'Cleanliness': {
      'exterior_cleaned': 'Exterior cleaned (carwash)',
      'interior_cleaned': 'Interior cleaned (no trash, vacuumed)',
      'mats_seat_covers_clean': 'Mats and seat covers clean',
    },
    'Others': {
      'fuel_level_checked': 'Fuel Level',
      'car_charger': 'Car Charger',
      'car_diffuser': 'Car Diffuser',
      'phone_holder': 'Phone Holder',
      'umbrella': 'Umbrella',
      'airtag': 'Airtag',
      'series_box': 'Series Box',
      'other_item_checked': 'Other item recorded',
    },
  };

  static List<String> get requiredChecklistKeys => checklistSections.values
      .expand((section) => section.keys)
      .toList(growable: false);

  Future<String> uploadEvidenceBytes({
    required String userId,
    required String bookingId,
    required Uint8List bytes,
    String extension = 'jpg',
    String? customFileName,
  }) async {
    final safeExtension = extension.replaceAll('.', '').toLowerCase().trim();
    final fileName = customFileName ??
        '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch % 1000}';
    final objectPath = '$userId/$bookingId/$fileName.$safeExtension';

    final optimizedBytes = await ImageOptimizationService.optimizeForUpload(
      bytes,
      fileName: objectPath,
      preset: UploadImagePreset.inspection,
    );

    final contentType = switch (safeExtension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => 'image/jpeg',
    };

    StorageException? lastStorageError;
    Object? lastError;

    // Retry loop with exponential backoff for transient DB / gateway timeouts (544)
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await supabase.storage
            .from('booking_evidence')
            .uploadBinary(
              objectPath,
              optimizedBytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: contentType,
                cacheControl: '31536000',
              ),
            );

        return supabase.storage.from('booking_evidence').getPublicUrl(objectPath);
      } on StorageException catch (e) {
        lastStorageError = e;
        debugPrint('StorageException on attempt $attempt for $objectPath: ${e.message} (status: ${e.statusCode})');
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
        }
      } catch (e) {
        lastError = e;
        debugPrint('Upload error on attempt $attempt for $objectPath: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
        }
      }
    }

    if (lastStorageError != null) throw lastStorageError;
    throw lastError ?? Exception('Failed to upload evidence after 3 attempts');
  }

  Future<List<String>> uploadMultipleEvidenceBytes({
    required String userId,
    required String bookingId,
    required List<({Uint8List bytes, String extension})> files,
  }) async {
    if (files.isEmpty) return [];

    final now = DateTime.now().millisecondsSinceEpoch;
    final successfulUrls = <String>[];
    Object? lastUploadError;

    // Upload sequentially to avoid saturating Postgres connection pool / 544 DatabaseTimeout
    for (int index = 0; index < files.length; index++) {
      final file = files[index];
      try {
        final url = await uploadEvidenceBytes(
          userId: userId,
          bookingId: bookingId,
          bytes: file.bytes,
          extension: file.extension,
          customFileName: '${now}_${index}_${DateTime.now().microsecondsSinceEpoch % 10000}',
        );
        successfulUrls.add(url);

        // Small inter-request delay to release DB connections in Supabase Storage pool
        if (index < files.length - 1) {
          await Future.delayed(const Duration(milliseconds: 180));
        }
      } catch (e) {
        lastUploadError = e;
        debugPrint('Failed to upload evidence item $index: $e');
        // Continue to attempt remaining evidence items
      }
    }

    // If at least one photo uploaded successfully, proceed with the successful ones
    if (successfulUrls.isNotEmpty) {
      return successfulUrls;
    }

    // If ALL storage uploads failed due to severe DatabaseTimeout (544) on Supabase Storage,
    // fallback to generating compact base64 JPEG data URIs so the partner can still save the checklist!
    try {
      final fallbackUrls = <String>[];
      for (int i = 0; i < files.length && i < 4; i++) {
        final file = files[i];
        final compressed = await ImageOptimizationService.optimizeForUpload(
          file.bytes,
          fileName: 'evidence_$i.jpg',
          preset: UploadImagePreset.inspection,
        );
        final base64String = base64Encode(compressed);
        fallbackUrls.add('data:image/jpeg;base64,$base64String');
      }
      if (fallbackUrls.isNotEmpty) {
        debugPrint('Supabase storage unavailable; using ${fallbackUrls.length} compressed fallback evidence URIs');
        return fallbackUrls;
      }
    } catch (fallbackError) {
      debugPrint('Fallback evidence encoding failed: $fallbackError');
    }

    if (lastUploadError != null) {
      throw lastUploadError;
    }

    return [];
  }

  Future<Map<String, dynamic>> saveInspection({
    required String bookingId,
    required String inspectionType,
    required String inspectorId,
    String? fuelLevel,
    double? mileage,
    String? cleanliness,
    String? scratches,
    String? dents,
    String? damages,
    String? remarks,
    String? tiresDetails,
    String? magsDetails,
    String? autosweepBalance,
    String? easytripBalance,
    String? otherItems,
    Map<String, String> sectionRemarks = const {},
    List<String> evidenceUrls = const [],
    Map<String, bool> checklistItems = const {},
    String? releasedBy,
    String? receivedBy,
  }) async {
    final normalizedType = inspectionType.trim().toLowerCase();
    if (normalizedType != 'before' && normalizedType != 'after') {
      throw Exception('Inspection type must be before or after');
    }
    if (fuelLevel?.trim().isEmpty != false ||
        tiresDetails?.trim().isEmpty != false ||
        magsDetails?.trim().isEmpty != false) {
      throw Exception(
        'Fuel level, tire details, and mags details are required',
      );
    }
    if (releasedBy?.trim().isEmpty != false ||
        receivedBy?.trim().isEmpty != false) {
      throw Exception('Released by and received by are required');
    }
    if (evidenceUrls.isEmpty) {
      throw Exception('Attach at least one checklist photo or video');
    }

    await assertResponsibleInspector(
      bookingId: bookingId,
      inspectorId: inspectorId,
    );

    final payload = {
      'booking_id': bookingId,
      'inspection_type': normalizedType,
      'inspector_id': inspectorId,
      'fuel_level': fuelLevel,
      'mileage': mileage,
      'cleanliness': cleanliness,
      'scratches': scratches,
      'dents': dents,
      'damages': damages,
      'remarks': remarks,
      'tires_details': tiresDetails?.trim(),
      'mags_details': magsDetails?.trim(),
      'autosweep_balance': autosweepBalance?.trim(),
      'easytrip_balance': easytripBalance?.trim(),
      'other_items': otherItems?.trim(),
      'section_remarks': sectionRemarks,
      'evidence_urls': evidenceUrls,
      'checklist_items': checklistItems,
      'released_by': releasedBy?.trim(),
      'received_by': receivedBy?.trim(),
      'completed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await supabase
        .from('booking_vehicle_inspections')
        .upsert(payload, onConflict: 'booking_id,inspection_type,inspector_id')
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  Future<void> assertResponsibleInspector({
    required String bookingId,
    required String inspectorId,
  }) async {
    final booking = await _getInspectionBooking(bookingId);
    final authorizedIds = await getAuthorizedInspectorIds(booking);

    // Expand candidate IDs for the inspector (in case inspectorId is a user_id or partner_id)
    final trimmedInspector = inspectorId.trim();
    final inspectorCandidateIds = <String>{trimmedInspector};
    try {
      final pRows = await supabase
          .from('partners')
          .select('id, user_id')
          .or('id.eq.$trimmedInspector,user_id.eq.$trimmedInspector');
      for (final p in List<Map<String, dynamic>>.from(pRows)) {
        final pId = p['id']?.toString().trim();
        final uId = p['user_id']?.toString().trim();
        if (pId != null && pId.isNotEmpty) inspectorCandidateIds.add(pId);
        if (uId != null && uId.isNotEmpty) inspectorCandidateIds.add(uId);
      }
    } catch (_) {}

    final isAuthorized = authorizedIds.any((id) => inspectorCandidateIds.contains(id));
    if (!isAuthorized && authorizedIds.isNotEmpty) {
      throw Exception(
        'Only the vehicle owner, partner, or operator can submit the inspection checklist.',
      );
    }
  }

  static bool isPreInspectionUnlocked(Map<String, dynamic> booking) {
    final rawStart = booking['start_at'] ?? booking['start_date'] ?? booking['start_date_raw'] ?? booking['startDate'];
    final startAt = rawStart != null ? DateTime.tryParse(rawStart.toString())?.toUtc() : null;
    if (startAt == null) return true;

    final windowOpens = startAt.subtract(const Duration(hours: 24));
    final now = DateTime.now().toUtc();
    return !now.isBefore(windowOpens);
  }

  static DateTime? getPreInspectionUnlockTime(Map<String, dynamic> booking) {
    final rawStart = booking['start_at'] ?? booking['start_date'] ?? booking['start_date_raw'] ?? booking['startDate'];
    final startAt = rawStart != null ? DateTime.tryParse(rawStart.toString())?.toLocal() : null;
    if (startAt == null) return null;
    return startAt.subtract(const Duration(hours: 24));
  }

  /// Validates that the inspection type is allowed at the current time and
  /// booking state.
  ///
  /// - **before**: allowed from 24 hours before the scheduled `start_at` up to
  ///   the moment the trip is marked as started.
  /// - **after**: allowed once the trip is in an active/ongoing/return state
  ///   (the booking status is past `approved`).
  Future<void> assertInspectionWindowOpen({
    required String bookingId,
    required String inspectionType,
  }) async {
    final booking = await _getInspectionBooking(bookingId);
    final status =
        booking['status']?.toString().trim().toLowerCase() ?? '';
    final normalizedType = inspectionType.trim().toLowerCase();

    if (normalizedType == 'before') {
      // Resolve the trip start time from start_at or start_date.
      final rawStart = booking['start_at'] ?? booking['start_date'];
      final startAt = DateTime.tryParse(rawStart?.toString() ?? '');
      if (startAt == null) {
        throw Exception('Booking start time is not set yet');
      }
      final windowOpens = startAt.subtract(const Duration(hours: 24));
      final now = DateTime.now().toUtc();
      if (now.isBefore(windowOpens)) {
        final hoursUntil = (windowOpens.difference(now).inMinutes / 60.0).toStringAsFixed(1);
        throw Exception(
          'The pre-trip inspection checklist is locked until 24 hours before the trip starts '
          '(opens in about $hoursUntil hours).',
        );
      }
      // The trip must not have already started; reject duplicate befores.
      final alreadyStarted = {'active', 'ongoing', 'return_pending_inspection',
          'awaiting_completion', 'completed'}.contains(status);
      if (alreadyStarted) {
        throw Exception(
          'The trip has already started. The before-trip inspection window has closed.',
        );
      }
    } else if (normalizedType == 'after') {
      // After-trip inspections require the trip to be in an active/ongoing state.
      final allowedStatuses = {
        'active',
        'ongoing',
        'return_pending_inspection',
        'awaiting_completion',
      };
      if (!allowedStatuses.contains(status)) {
        throw Exception(
          'The after-trip inspection is only available while the trip is active '
          '(current status: $status)',
        );
      }
    } else {
      throw Exception('Unknown inspection type: $inspectionType');
    }
  }
  Future<void> assertInspectionComplete({
    required String bookingId,
    required String inspectionType,
  }) async {
    await getCompletedInspection(
      bookingId: bookingId,
      inspectionType: inspectionType,
    );
  }

  Future<Map<String, dynamic>> getCompletedInspection({
    required String bookingId,
    required String inspectionType,
  }) async {
    final booking = await _getInspectionBooking(bookingId);
    final authorizedIds = await getAuthorizedInspectorIds(booking);

    final rows = await supabase
        .from('booking_vehicle_inspections')
        .select()
        .eq('booking_id', bookingId)
        .eq('inspection_type', inspectionType.trim().toLowerCase())
        .order('created_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(rows);
    final row = list.firstWhere(
      (r) {
        final inspId = r['inspector_id']?.toString().trim();
        return (authorizedIds.isEmpty || authorizedIds.contains(inspId)) && _isCompleteInspection(r);
      },
      orElse: () => list.firstWhere(
        (r) => _isCompleteInspection(r),
        orElse: () => list.isNotEmpty ? list.first : <String, dynamic>{},
      ),
    );

    if (row.isEmpty || !_isCompleteInspection(row)) {
      final label = inspectionType.trim().toLowerCase() == 'after'
          ? 'after-return'
          : 'before-release';
      throw Exception(
        'The required $label checklist, including photo or video evidence, is not complete yet',
      );
    }
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> _getInspectionBooking(String bookingId) async {
    final response = await supabase
        .from('bookings')
        .select('*, vehicles(*, owner:owner_id(id, role, full_name))')
        .eq('id', bookingId)
        .maybeSingle();
    if (response == null) throw Exception('Booking not found');
    final booking = Map<String, dynamic>.from(response);

    if (booking['vehicles'] == null && booking['vehicle_id'] != null) {
      final vehicleId = booking['vehicle_id'].toString().trim();
      try {
        final pv = await supabase
            .from('partner_vehicles')
            .select()
            .eq('id', vehicleId)
            .maybeSingle();
        if (pv != null) {
          booking['vehicles'] = Map<String, dynamic>.from(pv);
        }
      } catch (_) {}
    }
    return booking;
  }


  /// Resolves all authorized inspector user IDs (vehicle owners, partners, and operators)
  /// who have permission to submit an inspection checklist for this booking.
  Future<Set<String>> getAuthorizedInspectorIds(Map<String, dynamic> booking) async {
    final ids = <String>{};

    // 1. Direct fields on booking
    final bookingPartnerId = booking['partner_id']?.toString().trim();
    final bookingConfirmedBy = booking['partner_booking_confirmed_by']?.toString().trim();
    final bookingOperatorId = booking['operator_id']?.toString().trim();
    if (bookingPartnerId != null && bookingPartnerId.isNotEmpty) ids.add(bookingPartnerId);
    if (bookingConfirmedBy != null && bookingConfirmedBy.isNotEmpty) ids.add(bookingConfirmedBy);
    if (bookingOperatorId != null && bookingOperatorId.isNotEmpty) ids.add(bookingOperatorId);

    // 2. Fields on vehicle
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleOwnerId = vehicle?['owner_id']?.toString().trim();
    final vehiclePartnerId = vehicle?['partner_id']?.toString().trim();
    final vehiclePartnerVehId = vehicle?['partner_vehicle_id']?.toString().trim();
    final vehicleOperatorId = vehicle?['operator_id']?.toString().trim();
    if (vehicleOwnerId != null && vehicleOwnerId.isNotEmpty) ids.add(vehicleOwnerId);
    if (vehiclePartnerId != null && vehiclePartnerId.isNotEmpty) ids.add(vehiclePartnerId);
    if (vehiclePartnerVehId != null && vehiclePartnerVehId.isNotEmpty) ids.add(vehiclePartnerVehId);
    if (vehicleOperatorId != null && vehicleOperatorId.isNotEmpty) ids.add(vehicleOperatorId);

    final rawVehicleId = booking['vehicle_id']?.toString().trim() ?? vehicle?['id']?.toString().trim() ?? '';
    if (rawVehicleId.isNotEmpty) {
      try {
        final v = await supabase
            .from('vehicles')
            .select('owner_id, partner_id, partner_vehicle_id, operator_id')
            .eq('id', rawVehicleId)
            .maybeSingle();
        if (v != null) {
          final oId = v['owner_id']?.toString().trim();
          final pId = v['partner_id']?.toString().trim();
          final pvId = v['partner_vehicle_id']?.toString().trim();
          final opId = v['operator_id']?.toString().trim();
          if (oId != null && oId.isNotEmpty) ids.add(oId);
          if (pId != null && pId.isNotEmpty) ids.add(pId);
          if (pvId != null && pvId.isNotEmpty) ids.add(pvId);
          if (opId != null && opId.isNotEmpty) ids.add(opId);
        }
      } catch (_) {}

      try {
        final pvRows = await supabase
            .from('partner_vehicles')
            .select('partner_id, user_id, vehicle_id')
            .or('id.eq.$rawVehicleId,vehicle_id.eq.$rawVehicleId');
        for (final pv in List<Map<String, dynamic>>.from(pvRows)) {
          final pId = pv['partner_id']?.toString().trim();
          final uId = pv['user_id']?.toString().trim();
          if (pId != null && pId.isNotEmpty) ids.add(pId);
          if (uId != null && uId.isNotEmpty) ids.add(uId);
        }
      } catch (_) {}

      try {
        final appRows = await supabase
            .from('partner_vehicle_applications')
            .select('partner_id, created_vehicle_id, partner_vehicle_id')
            .or('id.eq.$rawVehicleId,created_vehicle_id.eq.$rawVehicleId,partner_vehicle_id.eq.$rawVehicleId');
        for (final app in List<Map<String, dynamic>>.from(appRows)) {
          final pId = app['partner_id']?.toString().trim();
          if (pId != null && pId.isNotEmpty) ids.add(pId);
        }
      } catch (_) {}
    }

    // 3. Resolve partners table mappings (both id -> user_id and user_id -> id)
    final resolvedIds = Set<String>.from(ids);
    for (final id in ids) {
      try {
        final partnerRows = await supabase
            .from('partners')
            .select('id, user_id')
            .or('id.eq.$id,user_id.eq.$id');
        for (final p in List<Map<String, dynamic>>.from(partnerRows)) {
          final pId = p['id']?.toString().trim();
          final uId = p['user_id']?.toString().trim();
          if (pId != null && pId.isNotEmpty) resolvedIds.add(pId);
          if (uId != null && uId.isNotEmpty) resolvedIds.add(uId);
        }
      } catch (_) {}
    }

    return resolvedIds;
  }


  bool _isCompleteInspection(Map<String, dynamic> row) {
    final evidence = row['evidence_urls'];
    final hasEvidence = evidence is List && evidence.isNotEmpty;
    return hasEvidence &&
        row['fuel_level']?.toString().trim().isNotEmpty == true &&
        row['released_by']?.toString().trim().isNotEmpty == true &&
        row['received_by']?.toString().trim().isNotEmpty == true;
  }

  Future<List<Map<String, dynamic>>> getBookingInspections(
    String bookingId,
  ) async {
    final response = await supabase
        .from('booking_vehicle_inspections')
        .select()
        .eq('booking_id', bookingId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
