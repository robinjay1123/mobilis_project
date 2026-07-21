import 'dart:typed_data';

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
  }) async {
    final safeExtension = extension.replaceAll('.', '').toLowerCase();
    final objectPath =
        '$userId/$bookingId/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    final optimizedBytes = await ImageOptimizationService.optimizeForUpload(
      bytes,
      fileName: objectPath,
      preset: UploadImagePreset.standard,
    );
    await supabase.storage
        .from('booking_evidence')
        .uploadBinary(
          objectPath,
          optimizedBytes,
          fileOptions: const FileOptions(
            upsert: true,
            cacheControl: '31536000',
          ),
        );

    return supabase.storage.from('booking_evidence').getPublicUrl(objectPath);
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
    final missingItems = requiredChecklistKeys
        .where((key) => checklistItems[key] != true)
        .toList();
    if (missingItems.isNotEmpty) {
      throw Exception('Complete every checklist item before submitting');
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
    final expectedInspectorId = await _requiredInspectorId(
      booking,
      fallbackInspectorId: inspectorId,
    );
    if (expectedInspectorId != inspectorId) {
      final isPartnerVehicle = _isPartnerVehicle(booking);
      throw Exception(
        isPartnerVehicle
            ? 'Only the partner who owns this vehicle can submit its checklist'
            : 'Only the operator assigned to this PSDC booking can submit its checklist',
      );
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
    final expectedInspectorId = await _requiredInspectorId(booking);
    final row = await supabase
        .from('booking_vehicle_inspections')
        .select()
        .eq('booking_id', bookingId)
        .eq('inspection_type', inspectionType.trim().toLowerCase())
        .eq('inspector_id', expectedInspectorId)
        .maybeSingle();

    if (row == null || !_isCompleteInspection(row)) {
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
    return Map<String, dynamic>.from(response);
  }

  bool _isPartnerVehicle(Map<String, dynamic> booking) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final owner = vehicle?['owner'] as Map<String, dynamic>?;
    final ownerRole = owner?['role']?.toString().trim().toLowerCase();
    return ownerRole == 'partner' ||
        vehicle?['is_partner_vehicle'] == true ||
        vehicle?['partner_vehicle_id'] != null;
  }

  Future<String> _requiredInspectorId(
    Map<String, dynamic> booking, {
    String? fallbackInspectorId,
  }) async {
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final owner = vehicle?['owner'] as Map<String, dynamic>?;
    final ownerId = vehicle?['owner_id']?.toString();
    if (_isPartnerVehicle(booking) && ownerId?.isNotEmpty == true) {
      return ownerId!;
    }

    final operatorId = booking['operator_id']?.toString();
    if (operatorId?.isNotEmpty == true) return operatorId!;

    final ownerRole = owner?['role']?.toString().trim().toLowerCase();
    if ((ownerRole == 'operator' || ownerRole == 'admin') &&
        ownerId?.isNotEmpty == true) {
      return ownerId!;
    }

    if (fallbackInspectorId != null && fallbackInspectorId.isNotEmpty) {
      final user = await supabase
          .from('users')
          .select('role')
          .eq('id', fallbackInspectorId)
          .maybeSingle();
      final role = user?['role']?.toString().trim().toLowerCase();
      if (role == 'operator' || role == 'admin') return fallbackInspectorId;
    }
    throw Exception('No responsible operator is assigned to this PSDC booking');
  }

  bool _isCompleteInspection(Map<String, dynamic> row) {
    final evidence = row['evidence_urls'];
    final hasEvidence = evidence is List && evidence.isNotEmpty;
    final rawItems = row['checklist_items'];
    final items = rawItems is Map
        ? Map<String, dynamic>.from(rawItems)
        : <String, dynamic>{};
    bool isChecked(String key) {
      if (key == 'airtag') {
        return items['airtag'] == true || items['airbag'] == true;
      }
      if (key == 'other_item_checked' && !items.containsKey(key)) {
        return true;
      }
      return items[key] == true;
    }

    final allChecked = requiredChecklistKeys.every(isChecked);
    return hasEvidence &&
        allChecked &&
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
