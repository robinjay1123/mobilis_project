import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_optimization_service.dart';

class BookingInspectionService {
  BookingInspectionService._();

  static final BookingInspectionService _instance =
      BookingInspectionService._();

  factory BookingInspectionService() => _instance;

  final SupabaseClient supabase = Supabase.instance.client;

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
    List<String> evidenceUrls = const [],
  }) async {
    final payload = {
      'booking_id': bookingId,
      'inspection_type': inspectionType,
      'inspector_id': inspectorId,
      'fuel_level': fuelLevel,
      'mileage': mileage,
      'cleanliness': cleanliness,
      'scratches': scratches,
      'dents': dents,
      'damages': damages,
      'remarks': remarks,
      'evidence_urls': evidenceUrls,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await supabase
        .from('booking_vehicle_inspections')
        .upsert(payload, onConflict: 'booking_id,inspection_type,inspector_id')
        .select()
        .single();

    return Map<String, dynamic>.from(response);
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
