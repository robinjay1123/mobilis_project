import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../../services/trip_rating_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/optimized_network_image.dart';
import '../../widgets/vehicle_image_carousel.dart';

class TripRatingFlowScreen extends StatefulWidget {
  final String bookingId;
  final String reviewerRole;
  final String title;
  final String subtitle;

  const TripRatingFlowScreen({
    super.key,
    required this.bookingId,
    required this.reviewerRole,
    this.title = 'Trip Successfully Completed',
    this.subtitle = 'Leave ratings for this completed trip.',
  });

  @override
  State<TripRatingFlowScreen> createState() => _TripRatingFlowScreenState();
}

class _TripRatingFlowScreenState extends State<TripRatingFlowScreen> {
  final TripRatingService _tripRatingService = TripRatingService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _commentController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  final bool _completionRecovered = false;
  List<Map<String, dynamic>> _targets = [];
  int _currentIndex = 0;
  double _selectedRating = 0;
  String _emptyTitle = 'Ratings already completed';
  String _emptyMessage =
      'There are no pending reviews for you at this trip stage.';
  IconData _emptyIcon = Icons.check_circle_outline_rounded;
  Color _emptyIconColor = AppColors.success;
  final List<File> _selectedImages = [];
  final List<String> _existingImageUrls = [];
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    final reviewerId = AuthService().currentUser?.id;
    if (reviewerId == null) {
      if (!mounted) return;
      setState(() {
        _emptyTitle = 'Sign in required';
        _emptyMessage = 'Please sign in again before rating this trip.';
        _emptyIcon = Icons.lock_outline_rounded;
        _emptyIconColor = AppColors.error;
        _isLoading = false;
      });
      return;
    }

    final cleanReviewerRole = widget.reviewerRole.trim().toLowerCase();
    final operatorFallbackUserId = cleanReviewerRole == 'operator'
        ? reviewerId
        : null;

    final targets = await _tripRatingService.buildTargetsForBooking(
      bookingId: widget.bookingId,
      reviewerUserId: reviewerId,
      reviewerRole: widget.reviewerRole,
      operatorFallbackUserId: operatorFallbackUserId,
      includePreviouslySubmittedForRecovery: true,
    );

    for (final target in targets) {
      try {
        final existing = await Supabase.instance.client
            .from('trip_ratings')
            .select()
            .eq('booking_id', widget.bookingId)
            .eq('reviewer_user_id', reviewerId)
            .eq('target_user_id', target['userId'].toString())
            .eq('target_role', target['role'].toString())
            .maybeSingle();
        if (existing != null) {
          target['existingRating'] = Map<String, dynamic>.from(existing);
          target['alreadyRated'] = true;
        }
      } catch (_) {}
    }

    if (targets.isNotEmpty) {
      final firstUnrated = targets.indexWhere((t) => t['alreadyRated'] != true);
      if (firstUnrated >= 0) {
        _currentIndex = firstUnrated;
      } else {
        _currentIndex = 0;
      }
    }

    var emptyTitle = 'No Rating Targets';
    var emptyMessage = 'No rating targets available for this booking.';
    var emptyIcon = Icons.hourglass_bottom_rounded;
    var emptyIconColor = AppColors.warning;

    if (targets.isEmpty) {
      final bookingContext = await _tripRatingService.getBookingContext(
        widget.bookingId,
      );
      final status =
          bookingContext?['status']?.toString().trim().toLowerCase() ?? '';
      if (status == 'cancelled') {
        emptyTitle = 'Booking Cancelled';
        emptyMessage =
            'This booking was cancelled and is not eligible for trip reviews.';
        emptyIcon = Icons.cancel_outlined;
        emptyIconColor = AppColors.error;
      } else {
        emptyTitle = 'Rating Not Ready Yet';
        emptyMessage =
            'Vehicle return and inspection must be completed before trip ratings can begin.';
        emptyIcon = Icons.hourglass_bottom_rounded;
        emptyIconColor = AppColors.warning;
      }
    }

    if (!mounted) return;
    setState(() {
      _targets = targets;
      _emptyTitle = emptyTitle;
      _emptyMessage = emptyMessage;
      _emptyIcon = emptyIcon;
      _emptyIconColor = emptyIconColor;
      _isLoading = false;
      _populateFieldsForCurrentTarget();
    });
  }

  void _populateFieldsForCurrentTarget() {
    final target = _currentTarget;
    if (target != null && target['existingRating'] is Map<String, dynamic>) {
      final existing = target['existingRating'] as Map<String, dynamic>;
      _selectedRating = (existing['rating'] as num?)?.toDouble() ?? 0.0;
      _commentController.text = existing['comment']?.toString() ?? '';
      final rawTags = existing['tags'];
      _selectedTags.clear();
      if (rawTags is List) {
        _selectedTags.addAll(rawTags.map((e) => e.toString()));
      }
      final rawImages = existing['image_urls'];
      _existingImageUrls.clear();
      if (rawImages is List) {
        _existingImageUrls.addAll(
          rawImages.map((e) => e.toString().trim()).where((s) => s.isNotEmpty),
        );
      }
      _selectedImages.clear();
    } else {
      _selectedRating = 0.0;
      _commentController.clear();
      _selectedTags.clear();
      _selectedImages.clear();
      _existingImageUrls.clear();
    }
  }

  Map<String, dynamic>? get _currentTarget {
    if (_currentIndex < 0 || _currentIndex >= _targets.length) return null;
    return _targets[_currentIndex];
  }

  bool get _isCurrentTargetReadOnly {
    final target = _currentTarget;
    return target != null && target['alreadyRated'] == true;
  }

  bool get _areAllTargetsRated {
    return _targets.isNotEmpty &&
        _targets.every((t) => t['alreadyRated'] == true);
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _populateFieldsForCurrentTarget();
      });
    }
  }

  void _goToNext() {
    if (_currentIndex < _targets.length - 1) {
      setState(() {
        _currentIndex++;
        _populateFieldsForCurrentTarget();
      });
    }
  }

  Future<void> _pickImages() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;

    final newImages = files.map((file) => File(file.path)).toList();
    setState(() {
      _selectedImages.addAll(newImages);
    });
  }

  Future<void> _submitCurrentRating() async {
    final target = _currentTarget;
    final reviewerId = AuthService().currentUser?.id;
    if (target == null || reviewerId == null) return;

    if (_selectedRating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a star rating first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _tripRatingService.submitRating(
        bookingId: widget.bookingId,
        reviewerUserId: reviewerId,
        reviewerRole: widget.reviewerRole,
        targetUserId: target['userId'].toString(),
        targetRole: target['role'].toString(),
        rating: _selectedRating,
        comment: _commentController.text.trim(),
        tags: _selectedTags.toList(),
        imageFiles: _selectedImages,
      );

      target['alreadyRated'] = true;
      target['existingRating'] = {
        'rating': _selectedRating,
        'comment': _commentController.text.trim(),
        'tags': _selectedTags.toList(),
        'image_urls': _existingImageUrls,
      };

      _moveNextOrFinish();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit rating: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  void _moveNextOrFinish() {
    final nextUnrated = _targets.indexWhere((t) => t['alreadyRated'] != true);
    if (nextUnrated == -1 || _currentIndex >= _targets.length - 1) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _currentIndex = nextUnrated >= 0 ? nextUnrated : _currentIndex + 1;
      _isSubmitting = false;
      _populateFieldsForCurrentTarget();
    });
  }

  void _showImagePreviewDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: OptimizedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = _currentTarget;
    final isReadOnly = _isCurrentTargetReadOnly;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        title: Text(
          isReadOnly
              ? 'View Rating'
              : _reviewTitleForTarget(target),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : target == null
          ? _buildNoTargetsState()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSuccessHeader(),
                  const SizedBox(height: 18),
                  if (isReadOnly) ...[
                    _buildReadOnlyStatusBadge(),
                    const SizedBox(height: 12),
                  ],
                  _buildTargetCard(target),
                  const SizedBox(height: 22),
                  Text(
                    isReadOnly
                        ? 'Rating Score'
                        : (target['prompt']?.toString() ??
                            'How was your experience?'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildStarRow(isReadOnly: isReadOnly),
                  const SizedBox(height: 24),
                  Text(
                    isReadOnly ? 'Review Comment' : 'Leave a review (optional)',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isReadOnly)
                    _buildReadOnlyComment()
                  else
                    TextField(
                      controller: _commentController,
                      maxLines: 5,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: _reviewHintForTarget(
                          target['role']?.toString(),
                        ),
                        hintStyle:
                            const TextStyle(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.darkBgSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.borderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.borderColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (isReadOnly) ...[
                    if (_selectedTags.isNotEmpty) ...[
                      const Text(
                        'Selected Tags',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedTags
                            .map((tag) => _buildTagChip(tag, isReadOnly: true))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedTagsForRole(
                        target['role']?.toString(),
                      ).map((tag) => _buildTagChip(tag, isReadOnly: false)).toList(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(
                              Icons.add_a_photo_outlined,
                              size: 18,
                            ),
                            label: const Text('Add Photos'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_existingImageUrls.isNotEmpty && isReadOnly) ...[
                    const Text(
                      'Review Photos',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _existingImageUrls.map((imageUrl) {
                        return GestureDetector(
                          onTap: () => _showImagePreviewDialog(imageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: OptimizedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedImages.isNotEmpty && !isReadOnly) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(_selectedImages.length, (index) {
                        final image = _selectedImages[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                image,
                                width: 78,
                                height: 78,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 26),
                  _buildBottomActionButtons(isReadOnly: isReadOnly),
                  if (!isReadOnly) ...[
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'A rating is required to complete this trip.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildReadOnlyStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
          SizedBox(width: 8),
          Text(
            'Submitted Rating (View Only)',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyComment() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: const Text(
          'No written review comment provided.',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontStyle: FontStyle.italic,
            fontSize: 14,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Text(
        comment,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildBottomActionButtons({required bool isReadOnly}) {
    if (isReadOnly) {
      final isLastTarget = _currentIndex >= _targets.length - 1;
      return Row(
        children: [
          if (_currentIndex > 0) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _goToPrevious,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: _currentIndex > 0 ? 2 : 1,
            child: ElevatedButton.icon(
              onPressed: () {
                if (isLastTarget) {
                  Navigator.pop(context, false);
                } else {
                  _goToNext();
                }
              },
              icon: Icon(
                isLastTarget
                    ? Icons.check_circle_outline_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(isLastTarget ? 'Done' : 'Next Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (_currentIndex > 0) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _goToPrevious,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: _currentIndex > 0 ? 2 : 1,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitCurrentRating,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            child: Text(
              _isSubmitting ? 'Submitting...' : 'Submit Rating',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoTargetsState() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_emptyIcon, color: _emptyIconColor, size: 58),
                const SizedBox(height: 14),
                Text(
                  _emptyTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, _completionRecovered),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Back to Bookings',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    final allRated = _areAllTargetsRated;
    return Column(
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              allRated ? Icons.star_rounded : Icons.check,
              color: AppColors.primary,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          allRated ? 'Trip Reviews Completed' : widget.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          allRated
              ? 'You have completed all reviews for this trip.'
              : widget.subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTargetCard(Map<String, dynamic> target) {
    final name = target['name']?.toString() ?? 'Mobilis User';
    final avatarUrl = (target['avatarUrl'] ?? target['imageUrl'])?.toString().trim() ?? '';
    final isVehicle =
        target['role']?.toString().trim().toLowerCase() == 'vehicle';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          if (isVehicle) ...[
            // ── Vehicle image carousel ──────────────────────────────────────
            Builder(builder: (context) {
              final rawImages = target['vehicleImages'] ?? target['vehicle_images'];
              final List<Map<String, dynamic>> vehicleImages = [];
              if (rawImages is List) {
                for (final item in rawImages) {
                  if (item is Map) {
                    vehicleImages.add(Map<String, dynamic>.from(item));
                  } else if (item is String && item.trim().isNotEmpty) {
                    vehicleImages.add({'image_url': item.trim()});
                  }
                }
              }
              var avatarUrlForFallback = avatarUrl;
              if (avatarUrlForFallback.isEmpty && target['imageUrl'] != null) {
                avatarUrlForFallback = target['imageUrl'].toString().trim();
              }
              if (avatarUrlForFallback.isEmpty && target['image_url'] != null) {
                avatarUrlForFallback = target['image_url'].toString().trim();
              }
              if (avatarUrlForFallback.isEmpty && vehicleImages.isNotEmpty) {
                avatarUrlForFallback = vehicleImages.first['image_url']?.toString().trim() ?? '';
              }

              final vehicleId = target['userId']?.toString().trim() ?? '';

              // Build a minimal vehicle-like map for VehicleImageCarousel
              final vehicleMap = <String, dynamic>{
                'image_url': avatarUrlForFallback,
                'vehicle_images': vehicleImages,
              };

              Widget renderCarousel(Map<String, dynamic> vMap) {
                final list = vMap['vehicle_images'] as List?;
                final single = vMap['image_url']?.toString().trim() ?? '';
                final hasImages = (list != null && list.isNotEmpty) || single.isNotEmpty;

                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: hasImages
                        ? VehicleImageCarousel(
                            vehicle: vMap,
                            height: 180,
                            backgroundColor: AppColors.darkBg,
                            iconColor: AppColors.textSecondary,
                          )
                        : Container(
                            color: AppColors.darkBg,
                            child: const Center(
                              child: Icon(
                                Icons.directions_car_rounded,
                                color: AppColors.primary,
                                size: 56,
                              ),
                            ),
                          ),
                  ),
                );
              }

              if (vehicleImages.isNotEmpty || avatarUrlForFallback.isNotEmpty || vehicleId.isEmpty) {
                return renderCarousel(vehicleMap);
              }

              return FutureBuilder<Map<String, dynamic>?>(
                future: _fetchVehicleImagesFallback(vehicleId),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return renderCarousel(snapshot.data!);
                  }
                  return renderCarousel(vehicleMap);
                },
              );
            }),
            const SizedBox(height: 16),
          ] else ...[
            // User avatar display — shows profile photo with initials fallback
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Initials backdrop (shown when no photo or photo fails)
                    Container(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      alignment: Alignment.center,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    // Profile photo on top — error stays transparent so initials show
                    if (avatarUrl.isNotEmpty)
                      OptimizedNetworkImage(
                        imageUrl: avatarUrl,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        isThumbnail: true,
                        errorWidget: const SizedBox.shrink(),
                        placeholder: const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

          ],
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isVehicle
                ? 'Vehicle Review • Step ${_currentIndex + 1} of ${_targets.length}'
                : '${_formatRoleName(target['role']?.toString())} • Step ${_currentIndex + 1} of ${_targets.length}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRoleName(String? role) {
    switch (role?.toLowerCase().trim()) {
      case 'renter':
        return 'Renter Review';
      case 'partner':
        return 'Vehicle Partner Review';
      case 'operator':
        return 'PSDC Operator Review';
      case 'driver':
        return 'Assigned Driver Review';
      default:
        return 'Trip Review';
    }
  }

  Widget _buildStarRow({required bool isReadOnly}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final value = index + 1;
            final isSelected = value <= _selectedRating;
            return IconButton(
              onPressed: isReadOnly
                  ? null
                  : () => setState(() => _selectedRating = value.toDouble()),
              icon: Icon(
                isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                color: isSelected ? AppColors.ratingGold : AppColors.textTertiary,
                size: 38,
              ),
            );
          }),
        ),
        if (isReadOnly && _selectedRating > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${_selectedRating.toStringAsFixed(1)} / 5.0 Stars',
            style: const TextStyle(
              color: AppColors.ratingGold,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTagChip(String tag, {required bool isReadOnly}) {
    final isSelected = _selectedTags.contains(tag);
    if (isReadOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primary),
        ),
        child: Text(
          tag,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTags.remove(tag);
          } else {
            _selectedTags.add(tag);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderColor,
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<String> _suggestedTagsForRole(String? role) {
    switch (role?.toLowerCase().trim()) {
      case 'vehicle':
        return [
          'Clean interior',
          'Smooth drive',
          'Fuel efficient',
          'Cold AC',
          'Well maintained',
          'Reliable',
        ];
      case 'driver':
        return [
          'Punctual',
          'Safe driver',
          'Clean car',
          'Great communicator',
          'Polite & helpful',
        ];
      case 'partner':
        return [
          'Well-maintained car',
          'Helpful owner',
          'Smooth turnover',
          'Professional',
        ];
      case 'operator':
        return [
          'Responsive',
          'Helpful support',
          'Professional service',
          'Fast coordination',
        ];
      case 'renter':
        return [
          'Followed rules',
          'Respectful',
          'Returned on time',
          'Easy to coordinate',
        ];
      default:
        return ['Professional', 'Responsive', 'Smooth trip'];
    }
  }

  String _reviewTitleForTarget(Map<String, dynamic>? target) {
    final role = target?['role']?.toString().trim().toLowerCase();
    switch (role) {
      case 'vehicle':
        return 'Rate Vehicle';
      case 'renter':
        return 'Rate Renter';
      case 'driver':
        return 'Rate Driver';
      case 'partner':
        return 'Rate Partner';
      case 'operator':
        return 'Rate Operator';
      default:
        return 'Rate Trip';
    }
  }

  String _reviewHintForTarget(String? role) {
    switch (role?.toLowerCase().trim()) {
      case 'vehicle':
        return 'Describe vehicle cleanliness, driving performance, and air conditioning...';
      case 'renter':
        return 'Describe their communication, punctuality, and care during the trip...';
      case 'driver':
        return 'Describe the driver communication, safety, and punctuality...';
      case 'partner':
        return 'Describe the vehicle condition and partner coordination...';
      case 'operator':
        return 'Describe the service, support, and overall coordination...';
      default:
        return 'Share your review...';
    }
  }

  Future<Map<String, dynamic>?> _fetchVehicleImagesFallback(String vehicleId) async {
    try {
      final client = Supabase.instance.client;
      // 1. Direct vehicles table
      var vRow = await client
          .from('vehicles')
          .select('id, image_url')
          .eq('id', vehicleId)
          .maybeSingle();

      String parentVId = vehicleId;
      if (vRow == null) {
        // Check partner_vehicles
        final pv = await client
            .from('partner_vehicles')
            .select('id, vehicle_id')
            .eq('id', vehicleId)
            .maybeSingle();
        if (pv != null && pv['vehicle_id'] != null) {
          parentVId = pv['vehicle_id'].toString().trim();
          vRow = await client
              .from('vehicles')
              .select('id, image_url')
              .eq('id', parentVId)
              .maybeSingle();
        }
      }

      final imgRows = await client
          .from('vehicle_images')
          .select('id, image_url, display_order')
          .or('vehicle_id.eq.$vehicleId,vehicle_id.eq.$parentVId')
          .order('display_order', ascending: true);

      final List<Map<String, dynamic>> images = [];
      if (imgRows is List) {
        for (final r in imgRows) {
          if (r is Map) images.add(Map<String, dynamic>.from(r));
        }
      }

      var mainImg = vRow?['image_url']?.toString().trim() ?? '';
      if (mainImg.isEmpty && images.isNotEmpty) {
        mainImg = images.first['image_url']?.toString().trim() ?? '';
      }

      if (mainImg.isNotEmpty || images.isNotEmpty) {
        return {
          'image_url': mainImg,
          'vehicle_images': images,
        };
      }
    } catch (_) {}
    return null;
  }
}
