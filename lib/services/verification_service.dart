import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class VerificationService {
  static final supabase = Supabase.instance.client;
  static final imagePicker = ImagePicker();

  /// Upload ID verification documents and face photo
  static Future<Map<String, dynamic>> submitVerification({
    required String userId,
    required File idFrontFile,
    required File idBackFile,
    required File facePhotoFile,
  }) async {
    try {
      // Upload ID front
      final idFrontPath =
          'verifications/$userId/id_front_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final idFrontUrl = await _uploadFile(idFrontPath, idFrontFile);

      // Upload ID back
      final idBackPath =
          'verifications/$userId/id_back_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final idBackUrl = await _uploadFile(idBackPath, idBackFile);

      // Upload face photo
      final facePath =
          'verifications/$userId/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final faceUrl = await _uploadFile(facePath, facePhotoFile);

      // Check if verification record exists
      final existing = await supabase
          .from('user_verifications')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update existing verification
        final response = await supabase
            .from('user_verifications')
            .update({
              'id_document_url':
                  '$idFrontUrl|$idBackUrl', // Store both as pipe-separated
              'face_photo_url': faceUrl,
              'verification_status': 'pending',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .select()
            .single();

        return {
          'success': true,
          'message': 'Verification documents submitted successfully',
          'data': response,
        };
      } else {
        // Create new verification
        final response = await supabase
            .from('user_verifications')
            .insert({
              'user_id': userId,
              'id_document_url':
                  '$idFrontUrl|$idBackUrl', // Store both as pipe-separated
              'face_photo_url': faceUrl,
              'verification_status': 'pending',
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        return {
          'success': true,
          'message': 'Verification submitted for admin review',
          'data': response,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to submit verification: $e',
        'data': null,
      };
    }
  }

  /// Upload file to Supabase storage
  static Future<String> _uploadFile(String path, File file) async {
    await supabase.storage
        .from('verification-documents')
        .upload(
          path,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    final publicUrl = supabase.storage
        .from('verification-documents')
        .getPublicUrl(path);

    return publicUrl;
  }

  /// Get user's verification status
  static Future<Map<String, dynamic>?> getUserVerification(
    String userId,
  ) async {
    try {
      return await supabase
          .from('user_verifications')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  /// Get all pending verifications (admin)
  static Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    try {
      return await supabase
          .from('user_verifications')
          .select(
            '*, users:user_id(id, full_name, email, role, application_status)',
          )
          .eq('verification_status', 'pending')
          .order('created_at', ascending: false);
    } catch (e) {
      return [];
    }
  }

  /// Admin approve verification
  static Future<Map<String, dynamic>> approveVerification({
    required String verificationId,
    required String adminId,
    required double faceMatchPercentage,
  }) async {
    try {
      final response = await supabase
          .from('user_verifications')
          .update({
            'verification_status': 'verified',
            'face_match_percentage': faceMatchPercentage,
            'verified_at': DateTime.now().toIso8601String(),
            'verified_by': adminId,
          })
          .eq('id', verificationId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'Verification approved',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to approve verification: $e',
        'data': null,
      };
    }
  }

  /// Admin reject verification
  static Future<Map<String, dynamic>> rejectVerification({
    required String verificationId,
    required String rejectionReason,
    required String adminId,
  }) async {
    try {
      final response = await supabase
          .from('user_verifications')
          .update({
            'verification_status': 'rejected',
            'rejection_reason': rejectionReason,
            'verified_at': DateTime.now().toIso8601String(),
            'verified_by': adminId,
          })
          .eq('id', verificationId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'Verification rejected',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to reject verification: $e',
        'data': null,
      };
    }
  }

  /// Pick image from camera or gallery
  static Future<File?> pickImage({
    ImageSource source = ImageSource.camera,
  }) async {
    try {
      final pickedFile = await imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
