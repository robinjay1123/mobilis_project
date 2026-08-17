import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_optimization_service.dart';

class BookingEvidenceService {
  BookingEvidenceService._();

  static final BookingEvidenceService _instance = BookingEvidenceService._();

  factory BookingEvidenceService() => _instance;

  final SupabaseClient supabase = Supabase.instance.client;

  Future<String> uploadEvidenceFile({
    required String userId,
    required XFile file,
    required String evidenceType,
  }) async {
    final extension = file.path.contains('.')
        ? file.path.split('.').last.toLowerCase()
        : 'jpg';
    final objectPath =
        '$userId/${evidenceType}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final originalBytes = await file.readAsBytes();
    final bytes = await ImageOptimizationService.optimizeForUpload(
      originalBytes,
      fileName: objectPath,
      preset: UploadImagePreset.sensitiveDocument,
    );

    await supabase.storage
        .from('booking_evidence')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: file.mimeType ?? 'image/$extension',
            cacheControl: '31536000',
          ),
        );

    return supabase.storage.from('booking_evidence').getPublicUrl(objectPath);
  }

  Future<String> uploadEvidenceBytes({
    required String userId,
    required Uint8List bytes,
    required String evidenceType,
    String extension = 'png',
    String contentType = 'image/png',
  }) async {
    final objectPath =
        '$userId/${evidenceType}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final optimizedBytes = await ImageOptimizationService.optimizeForUpload(
      bytes,
      fileName: objectPath,
      preset: UploadImagePreset.signature,
    );
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
  }
}
