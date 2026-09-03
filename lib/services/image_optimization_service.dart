import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum UploadImagePreset { standard, profile, sensitiveDocument, signature, inspection }

class ImageOptimizationService {
  ImageOptimizationService._();

  static Future<Uint8List> optimizeForUpload(
    Uint8List bytes, {
    required String fileName,
    UploadImagePreset preset = UploadImagePreset.standard,
  }) async {
    if (bytes.isEmpty || !_isSupportedRaster(fileName)) return bytes;

    final limits = switch (preset) {
      UploadImagePreset.profile => (maxDimension: 720, targetBytes: 250000),
      UploadImagePreset.signature => (maxDimension: 1000, targetBytes: 120000),
      UploadImagePreset.sensitiveDocument => (
        maxDimension: 1800,
        targetBytes: 500000,
      ),
      UploadImagePreset.inspection => (
        maxDimension: 1280,
        targetBytes: 250000,
      ),
      UploadImagePreset.standard => (maxDimension: 1600, targetBytes: 500000),
    };

    // Fast-path: If the image is already below or near the target byte size, skip heavy compute
    if (bytes.lengthInBytes <= limits.targetBytes) {
      return bytes;
    }

    try {
      return await compute(_optimizeImage, {
        'bytes': bytes,
        'fileName': fileName,
        'maxDimension': limits.maxDimension,
        'targetBytes': limits.targetBytes,
        'preset': preset.name,
      });
    } catch (error) {
      debugPrint('Image optimization skipped for $fileName: $error');
      return bytes;
    }
  }

  static bool _isSupportedRaster(String fileName) {
    final extension = fileName.split('.').last.toLowerCase().trim();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension);
  }
}

Uint8List _optimizeImage(Map<String, dynamic> request) {
  final original = request['bytes'] as Uint8List;
  final fileName = request['fileName'] as String;
  final maxDimension = request['maxDimension'] as int;
  final targetBytes = request['targetBytes'] as int;

  if (original.lengthInBytes <= targetBytes) {
    return original;
  }

  final decoded = img.decodeImage(original);
  if (decoded == null) return original;

  final oriented = img.bakeOrientation(decoded);
  final longestSide = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longestSide > maxDimension
      ? (oriented.width >= oriented.height
            ? img.copyResize(
                oriented,
                width: maxDimension,
                interpolation: img.Interpolation.linear,
              )
            : img.copyResize(
                oriented,
                height: maxDimension,
                interpolation: img.Interpolation.linear,
              ))
      : oriented;

  final extension = fileName.split('.').last.toLowerCase().trim();
  final presetName = request['preset'] as String?;
  final quality = presetName == 'inspection' ? 72 : 78;
  Uint8List optimized;
  if (extension == 'png') {
    optimized = img.encodePng(resized, level: 4);
  } else {
    optimized = img.encodeJpg(resized, quality: quality);
  }

  return optimized.lengthInBytes < original.lengthInBytes
      ? optimized
      : original;
}
