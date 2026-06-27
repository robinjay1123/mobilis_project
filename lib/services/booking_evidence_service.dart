import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final bytes = await File(file.path).readAsBytes();

    await supabase.storage
        .from('booking_evidence')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: file.mimeType ?? 'image/$extension',
          ),
        );

    return supabase.storage.from('booking_evidence').getPublicUrl(objectPath);
  }
}
