import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class ProfilePictureUploadScreen extends StatefulWidget {
  const ProfilePictureUploadScreen({super.key});

  @override
  State<ProfilePictureUploadScreen> createState() =>
      _ProfilePictureUploadScreenState();
}

class _ProfilePictureUploadScreenState
    extends State<ProfilePictureUploadScreen> {
  File? _selectedPhoto;
  bool _isUploaded = false;
  bool _isSaving = false;

  Future<void> _pickProfilePhoto({
    ImageSource source = ImageSource.gallery,
  }) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedPhoto = File(picked.path);
      _isUploaded = true;
    });
  }

  Future<void> _showPhotoSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update profile photo',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _buildSourceTile(
                icon: Icons.photo_camera_outlined,
                title: 'Take Photo',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _buildSourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Choose from Gallery',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      await _pickProfilePhoto(source: source);
    }
  }

  String _safeExtensionForPath(String path) {
    final rawExtension = path.split('.').last.toLowerCase().trim();
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    return allowed.contains(rawExtension) ? rawExtension : 'jpg';
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _syncProfilePhotoUrl({
    required SupabaseClient supabase,
    required User user,
    required String publicUrl,
  }) async {
    var databaseUpdated = false;

    try {
      await supabase
          .from('users')
          .update({'avatar_url': publicUrl, 'profile_picture_url': publicUrl})
          .eq('id', user.id);
      databaseUpdated = true;
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('avatar_url')) {
        try {
          await supabase
              .from('users')
              .update({'profile_picture_url': publicUrl})
              .eq('id', user.id);
          databaseUpdated = true;
        } catch (fallbackError) {
          final fallbackMessage = fallbackError.toString().toLowerCase();
          if (!fallbackMessage.contains('profile_picture_url')) {
            rethrow;
          }
        }
      } else {
        rethrow;
      }
    }

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'avatar_url': publicUrl,
            'profile_picture_url': publicUrl,
          },
        ),
      );
    } catch (_) {
      if (!databaseUpdated) rethrow;
    }
  }

  Future<void> _saveProfilePhoto() async {
    final user = AuthService().currentUser;
    final file = _selectedPhoto;
    if (user == null || file == null) return;

    setState(() => _isSaving = true);
    try {
      final safeExtension = _safeExtensionForPath(file.path);
      final objectPath =
          'profile_pictures/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
      final supabase = Supabase.instance.client;

      await supabase.storage
          .from('id_images')
          .upload(
            objectPath,
            file,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: _contentTypeForExtension(safeExtension),
            ),
          );

      final publicUrl = supabase.storage
          .from('id_images')
          .getPublicUrl(objectPath);

      await _syncProfilePhotoUrl(
        supabase: supabase,
        user: user,
        publicUrl: publicUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile picture: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload or change the photo shown on your profile.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: _showPhotoSourcePicker,
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _isUploaded
                            ? AppColors.success
                            : AppColors.borderColor,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Container(
                            width: 124,
                            height: 124,
                            color: AppColors.primary.withValues(alpha: 0.18),
                            child: _selectedPhoto == null
                                ? const Icon(
                                    Icons.camera_alt_outlined,
                                    color: AppColors.primary,
                                    size: 52,
                                  )
                                : Image.file(
                                    _selectedPhoto!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isUploaded
                              ? 'Photo selected'
                              : 'Tap to upload photo',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Use camera or gallery',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Opacity(
                  opacity: _isUploaded ? 1.0 : 0.5,
                  child: CustomButton(
                    label: _isSaving ? 'Saving...' : 'Save Profile Picture',
                    onPressed: _isUploaded && !_isSaving
                        ? _saveProfilePhoto
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
