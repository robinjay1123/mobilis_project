import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'notification_service.dart';
import 'user_restriction_service.dart';

class VerificationService {
  static final supabase = Supabase.instance.client;
  static final imagePicker = ImagePicker();
  static const String _idImagesBucket = 'id_images';

  static bool isVerifiedStatus(dynamic status) {
    final normalized = status?.toString().trim().toLowerCase() ?? '';
    return normalized == 'verified' ||
        normalized == 'approved' ||
        normalized == 'certified';
  }

  /// Read verification from both the users row and the verification request.
  ///
  /// Older approval flows can leave users.id_verified stale even when the
  /// user_verifications row is already verified, so booking/profile gates should
  /// use this combined state.
  static Future<Map<String, dynamic>> getUserVerificationState(
    String userId,
  ) async {
    Map<String, dynamic>? userRecord;
    Map<String, dynamic>? verificationRecord;

    try {
      userRecord = await supabase
          .from('users')
          .select('role, id_verified, verification_status')
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Unable to read user verification fields: $e');
    }

    try {
      verificationRecord = await supabase
          .from('user_verifications')
          .select('verification_status')
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Unable to read verification record: $e');
    }

    final userStatus = userRecord?['verification_status'];
    final requestStatus = verificationRecord?['verification_status'];
    final idVerified = userRecord?['id_verified'] as bool? ?? false;
    final isVerified =
        idVerified ||
        isVerifiedStatus(userStatus) ||
        isVerifiedStatus(requestStatus);

    if (isVerified && !idVerified) {
      try {
        await supabase
            .from('users')
            .update({'id_verified': true, 'verification_status': 'verified'})
            .eq('id', userId);
      } catch (e) {
        debugPrint('Unable to sync verified status to users row: $e');
      }
    }

    return {
      'role': (userRecord?['role'] ?? 'renter').toString().toLowerCase(),
      'is_verified': isVerified,
      'verification_status': isVerified
          ? 'verified'
          : (requestStatus ?? userStatus ?? 'unverified').toString(),
    };
  }

  /// Upload ID verification documents.
  static Future<Map<String, dynamic>> submitVerification({
    required String userId,
    required File idFrontFile,
    required File idBackFile,
  }) async {
    try {
      final userProfile = await supabase
          .from('users')
          .select('email, phone, full_name')
          .eq('id', userId)
          .maybeSingle();
      final blockedMatch = await UserRestrictionService()
          .findBlockedIdentityMatch(
            email: userProfile?['email']?.toString(),
            phone: userProfile?['phone']?.toString(),
            fullName: userProfile?['full_name']?.toString(),
          );
      if (blockedMatch != null) {
        await UserRestrictionService().markUserAsBlockedMatch(
          userId: userId,
          matchedBlockedUserId: blockedMatch['id']?.toString() ?? '',
          reason:
              'Verification was automatically rejected because this identity matches a permanently blocked user.',
        );

        final rejected = await supabase
            .from('user_verifications')
            .upsert({
              'user_id': userId,
              'rejection_reason':
                  'Automatically rejected because this identity matches a permanently blocked user.',
              'verified_at': DateTime.now().toIso8601String(),
              'verification_status': 'rejected',
            }, onConflict: 'user_id')
            .select()
            .single();

        return {
          'success': false,
          'message':
              'Verification was automatically rejected because this identity matches a blocked user record.',
          'data': rejected,
        };
      }

      // Upload ID front
      final idFrontPath =
          'verifications/$userId/id_front_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final idFrontUrl = await _uploadFile(idFrontPath, idFrontFile);

      // Upload ID back
      final idBackPath =
          'verifications/$userId/id_back_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final idBackUrl = await _uploadFile(idBackPath, idBackFile);

      final response = await supabase
          .from('user_verifications')
          .upsert({
            'user_id': userId,
            'rejection_reason': null,
            'verified_at': null,
            'id_document_url': '$idFrontUrl|$idBackUrl',
            'verification_status': 'pending',
          }, onConflict: 'user_id')
          .select()
          .single();

      return {
        'success': true,
        'message': 'Verification submitted for admin review',
        'data': response,
      };
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
        .from(_idImagesBucket)
        .upload(
          path,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    final publicUrl = supabase.storage.from(_idImagesBucket).getPublicUrl(path);

    return publicUrl;
  }

  /// Upload a single identity document photo for ID verification.
  static Future<Map<String, dynamic>> uploadIdentityPhoto({
    required String userId,
    required File idPhotoFile,
    String photoType = 'id_photo',
  }) async {
    try {
      final safePhotoType = photoType.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final path =
          'verifications/$userId/${safePhotoType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final idPhotoUrl = await _uploadFile(path, idPhotoFile);

      return {
        'success': true,
        'message': 'ID photo uploaded successfully',
        'file_url': idPhotoUrl,
        'data': {'id_photo_url': idPhotoUrl, 'storage_path': path},
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to upload ID photo: $e',
        'file_url': null,
        'data': null,
      };
    }
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
  }) async {
    try {
      final payload = <String, dynamic>{
        'verification_status': 'verified',
        'verified_at': DateTime.now().toIso8601String(),
      };

      final response = await supabase
          .from('user_verifications')
          .update(payload)
          .eq('id', verificationId)
          .select()
          .single();

      // Sync approval status to the users table so the app gate reads correctly
      final userId = response['user_id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        final userRecord = await supabase
            .from('users')
            .select('id, role, full_name, location')
            .eq('id', userId)
            .maybeSingle();
        final role = (userRecord?['role'] ?? '').toString().toLowerCase();

        // Get the full_name from verification and sync to users table
        final fullName = response['full_name']?.toString() ?? '';
        await supabase
            .from('users')
            .update({
              'id_verified': true,
              'verification_status': 'verified',
              if (role == 'driver') 'is_available': true,
              if (fullName.isNotEmpty) 'full_name': fullName,
            })
            .eq('id', userId);

        // Partner role: ensure profile exists and mirror verification details.
        if (role == 'partner') {
          await _syncPartnerProfileFromVerification(
            userId: userId,
            fallbackFullName: fullName.isNotEmpty
                ? fullName
                : (userRecord?['full_name']?.toString() ?? ''),
            fallbackLocation: userRecord?['location']?.toString() ?? '',
            verificationRecord: response,
            status: 'verified',
          );
        } else if (role == 'driver') {
          await _syncDriverProfileFromVerification(
            userId: userId,
            status: 'verified',
          );
        }
      }

      try {
        if (userId != null && userId.isNotEmpty) {
          final userRecord = await supabase
              .from('users')
              .select('role')
              .eq('id', userId)
              .maybeSingle();
          await NotificationService().notifyVerificationApproved(
            userId: userId,
            role: userRecord?['role']?.toString() ?? 'account',
            verificationId: response['id']?.toString(),
          );
        }
      } catch (notificationError) {
        debugPrint(
          'Failed to create approval notification: $notificationError',
        );
      }

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
      final payload = <String, dynamic>{
        'verification_status': 'rejected',
        'rejection_reason': rejectionReason,
        'verified_at': DateTime.now().toIso8601String(),
      };

      final response = await supabase
          .from('user_verifications')
          .update(payload)
          .eq('id', verificationId)
          .select()
          .single();

      // Sync rejection status to the users table so the app gate reads correctly
      final userId = response['user_id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        final userRecord = await supabase
            .from('users')
            .select('id, role, full_name, location')
            .eq('id', userId)
            .maybeSingle();

        await supabase
            .from('users')
            .update({'id_verified': false, 'verification_status': 'rejected'})
            .eq('id', userId);

        final role = (userRecord?['role'] ?? '').toString().toLowerCase();
        if (role == 'partner') {
          await _syncPartnerProfileFromVerification(
            userId: userId,
            fallbackFullName: userRecord?['full_name']?.toString() ?? '',
            fallbackLocation: userRecord?['location']?.toString() ?? '',
            verificationRecord: response,
            status: 'rejected',
          );
        } else if (role == 'driver') {
          await _syncDriverProfileFromVerification(
            userId: userId,
            status: 'rejected',
          );
        }
      }

      try {
        if (userId != null && userId.isNotEmpty) {
          await NotificationService().createNotification(
            userId: userId,
            title: 'Verification Rejected',
            message:
                'Your verification has been rejected. Reason: $rejectionReason',
            type: 'verification',
            data: {'verification_id': response['id'], 'status': 'rejected'},
          );
        }
      } catch (notificationError) {
        debugPrint(
          'Failed to create rejection notification: $notificationError',
        );
      }

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

  static Future<void> _syncPartnerProfileFromVerification({
    required String userId,
    required String fallbackFullName,
    required String fallbackLocation,
    required Map<String, dynamic> verificationRecord,
    required String status,
  }) async {
    final partnerStatus = _profileStatusFromVerificationStatus(status);
    final submittedFullName =
        verificationRecord['full_name']?.toString().trim() ?? '';
    final submittedLocation =
        verificationRecord['location']?.toString().trim() ?? '';

    final businessName = submittedFullName.isNotEmpty
        ? submittedFullName
        : fallbackFullName;
    final address = submittedLocation.isNotEmpty
        ? submittedLocation
        : fallbackLocation;

    final existingPartner = await supabase
        .from('partners')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    final payload = <String, dynamic>{
      'user_id': userId,
      if (businessName.isNotEmpty) 'business_name': businessName,
      if (address.isNotEmpty) ...{
        'address': address,
        'business_address': address,
      },
      'verification_status': partnerStatus,
    };

    if (existingPartner == null) {
      await supabase.from('partners').insert(payload);
    } else {
      await supabase
          .from('partners')
          .update(payload)
          .eq('id', existingPartner['id']);
    }
  }

  static Future<void> _syncDriverProfileFromVerification({
    required String userId,
    required String status,
  }) async {
    final driverStatus = _profileStatusFromVerificationStatus(status);
    final existingDriver = await supabase
        .from('drivers')
        .select('id, license_number, nbi_clearance_number')
        .eq('user_id', userId)
        .maybeSingle();

    final payload = <String, dynamic>{
      'user_id': userId,
      'verification_status': driverStatus,
    };

    if (existingDriver == null) {
      await supabase.from('drivers').insert({
        ...payload,
        'license_number': 'PENDING',
        'nbi_clearance_number': 'PENDING',
        'license_verified': false,
        'nbi_verified': false,
        'driver_tier': 'standard',
        'rating': 0.0,
        'total_trips': 0,
      });
    } else {
      final updatePayload = <String, dynamic>{...payload};
      if ((existingDriver['license_number']?.toString().trim() ?? '').isEmpty) {
        updatePayload['license_number'] = 'PENDING';
      }
      if ((existingDriver['nbi_clearance_number']?.toString().trim() ?? '')
          .isEmpty) {
        updatePayload['nbi_clearance_number'] = 'PENDING';
      }

      await supabase
          .from('drivers')
          .update(updatePayload)
          .eq('id', existingDriver['id']);
    }
  }

  static String _profileStatusFromVerificationStatus(String status) {
    // user_verifications accepts "verified"; partners/drivers accept "approved".
    return status == 'verified' ? 'approved' : status;
  }

  /// Submit verification with complete form details (name, location, ID type, ID number, image)
  static Future<Map<String, dynamic>> submitVerificationWithDetails({
    required String userId,
    required String fullName,
    required String location,
    required String idType,
    required String idNumber,
    required String idDocumentUrl,
    required String idFrontUrl,
    required String idBackUrl,
    required String faceSelfieUrl,
    required String selfieWithIdUrl,
  }) async {
    try {
      debugPrint('Submitting verification with details for user: $userId');

      final userProfile = await supabase
          .from('users')
          .select('email, phone')
          .eq('id', userId)
          .maybeSingle();
      final blockedMatch = await UserRestrictionService()
          .findBlockedIdentityMatch(
            email: userProfile?['email']?.toString(),
            phone: userProfile?['phone']?.toString(),
            fullName: fullName,
          );
      if (blockedMatch != null) {
        await UserRestrictionService().markUserAsBlockedMatch(
          userId: userId,
          matchedBlockedUserId: blockedMatch['id']?.toString() ?? '',
          reason:
              'Verification was automatically rejected because this account matches a permanently blocked user.',
        );

        final rejected = await supabase
            .from('user_verifications')
            .upsert({
              'user_id': userId,
              'full_name': fullName,
              'location': location,
              'id_type': idType,
              'id_number': idNumber,
              'id_document_url': idDocumentUrl,
              'id_front_url': idFrontUrl,
              'id_back_url': idBackUrl,
              'face_selfie_url': faceSelfieUrl,
              'selfie_with_id_url': selfieWithIdUrl,
              'verification_status': 'rejected',
              'rejection_reason':
                  'Automatically rejected because this identity matches a permanently blocked user.',
              'created_at': DateTime.now().toIso8601String(),
            }, onConflict: 'user_id')
            .select()
            .single();

        return {
          'success': false,
          'message':
              'Verification was automatically rejected because this identity matches a blocked user record.',
          'data': rejected,
        };
      }

      final response = await supabase
          .from('user_verifications')
          .upsert({
            'user_id': userId,
            'full_name': fullName,
            'location': location,
            'id_type': idType,
            'id_number': idNumber,
            'id_document_url': idDocumentUrl,
            'id_front_url': idFrontUrl,
            'id_back_url': idBackUrl,
            'face_selfie_url': faceSelfieUrl,
            'selfie_with_id_url': selfieWithIdUrl,
            'verification_status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id')
          .select()
          .single();

      debugPrint('Verification submitted with details successfully');
      return {
        'success': true,
        'message': 'Verification submitted for admin review',
        'data': response,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error submitting verification: ${e.message}');
      return {
        'success': false,
        'message': 'Failed to submit verification: ${e.message}',
        'data': null,
      };
    } catch (e) {
      debugPrint('Error submitting verification: $e');
      return {
        'success': false,
        'message': 'Failed to submit verification: $e',
        'data': null,
      };
    }
  }
}
