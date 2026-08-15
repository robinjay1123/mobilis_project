import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../../services/trip_rating_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/optimized_network_image.dart';

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
  bool _completionRecovered = false;
  List<Map<String, dynamic>> _targets = [];
  int _currentIndex = 0;
  double _selectedRating = 0;
  String _emptyTitle = 'Ratings already completed';
  String _emptyMessage =
      'There are no pending reviews for you at this trip stage.';
  IconData _emptyIcon = Icons.check_circle_outline_rounded;
  Color _emptyIconColor = AppColors.success;
  final List<File> _selectedImages = [];
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
      includePreviouslySubmittedForRecovery: false,
    );

    var completionRecovered = false;
    var emptyTitle = 'Ratings Already Completed';
    var emptyMessage =
        'You have already submitted all your reviews for this trip. Thank you!';
    var emptyIcon = Icons.check_circle_outline_rounded;
    var emptyIconColor = AppColors.success;

    if (targets.isEmpty) {
      // Check if this reviewer has already submitted any ratings for this booking
      var hasAlreadySubmitted = false;
      try {
        final existingRatings = await Supabase.instance.client
            .from('trip_ratings')
            .select('id')
            .eq('booking_id', widget.bookingId)
            .eq('reviewer_user_id', reviewerId);
        hasAlreadySubmitted = (existingRatings as List).isNotEmpty;
      } catch (_) {}

      final bookingContext = await _tripRatingService.getBookingContext(
        widget.bookingId,
      );
      final status =
          bookingContext?['status']?.toString().trim().toLowerCase() ?? '';

      if (hasAlreadySubmitted) {
        completionRecovered = await _tripRatingService.reconcileCompletedBooking(
          widget.bookingId,
          operatorFallbackUserId: operatorFallbackUserId,
        );
        emptyTitle = 'Ratings Already Completed';
        emptyMessage = completionRecovered
            ? 'This trip is completed and its revenue and ratings are finalized.'
            : 'You have already submitted all your reviews for this trip. Thank you!';
        emptyIcon = Icons.check_circle_outline_rounded;
        emptyIconColor = AppColors.success;
      } else {
        // Reviewer has NOT rated yet. Try to load targets for recovery / direct rating
        final retryTargets = await _tripRatingService.buildTargetsForBooking(
          bookingId: widget.bookingId,
          reviewerUserId: reviewerId,
          reviewerRole: widget.reviewerRole,
          operatorFallbackUserId: operatorFallbackUserId,
          includePreviouslySubmittedForRecovery: true,
        );

        if (retryTargets.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _targets = retryTargets;
            _isLoading = false;
          });
          return;
        }

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
    }

    if (!mounted) return;
    setState(() {
      _targets = targets;
      _completionRecovered = completionRecovered;
      _emptyTitle = emptyTitle;
      _emptyMessage = emptyMessage;
      _emptyIcon = emptyIcon;
      _emptyIconColor = emptyIconColor;
      _isLoading = false;
    });
  }

  Map<String, dynamic>? get _currentTarget {
    if (_currentIndex < 0 || _currentIndex >= _targets.length) return null;
    return _targets[_currentIndex];
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
    if (_currentIndex >= _targets.length - 1) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _currentIndex++;
      _selectedRating = 0;
      _commentController.clear();
      _selectedImages.clear();
      _selectedTags.clear();
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = _currentTarget;

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
          _reviewTitleForTarget(target),
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
                  _buildTargetCard(target),
                  const SizedBox(height: 22),
                  Text(
                    target['prompt']?.toString() ?? 'How was your experience?',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStarRow(),
                  const SizedBox(height: 24),
                  const Text(
                    'Leave a review (optional)',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 5,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: _reviewHintForTarget(
                        target['role']?.toString(),
                      ),
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
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
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedTagsForRole(
                      target['role']?.toString(),
                    ).map(_buildTagChip).toList(),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImages.isNotEmpty) ...[
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
                  SizedBox(
                    width: double.infinity,
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
              ),
            ),
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
            child: const Icon(Icons.check, color: AppColors.primary, size: 38),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTargetCard(Map<String, dynamic> target) {
    final name = target['name']?.toString() ?? 'Mobilis User';
    final avatarUrl = target['avatarUrl']?.toString().trim() ?? '';
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
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(24),
              image: avatarUrl.isNotEmpty
                  ? DecorationImage(
                      image: OptimizedNetworkImageProvider(avatarUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
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
            'Trip review ${_currentIndex + 1} of ${_targets.length}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final value = index + 1;
        final isSelected = value <= _selectedRating;
        return IconButton(
          onPressed: () => setState(() => _selectedRating = value.toDouble()),
          icon: Icon(
            isSelected ? Icons.star : Icons.star_border,
            color: AppColors.primary,
            size: 36,
          ),
        );
      }),
    );
  }

  Widget _buildTagChip(String tag) {
    final isSelected = _selectedTags.contains(tag);
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
      case 'driver':
        return [
          'Punctual',
          'Cleaned car',
          'Great communicator',
          'Handled vehicle well',
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
}
