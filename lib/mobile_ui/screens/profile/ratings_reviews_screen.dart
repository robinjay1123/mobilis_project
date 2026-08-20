import 'package:flutter/material.dart';

import '../../../services/trip_rating_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/optimized_network_image.dart';

class RatingsReviewsScreen extends StatefulWidget {
  final String userId;
  final String? vehicleId;
  final String title;
  final bool embedded;

  const RatingsReviewsScreen({
    super.key,
    required this.userId,
    this.vehicleId,
    this.title = 'Ratings & Reviews',
    this.embedded = false,
  });

  @override
  State<RatingsReviewsScreen> createState() => _RatingsReviewsScreenState();
}

class _RatingsReviewsScreenState extends State<RatingsReviewsScreen> {
  final TripRatingService _tripRatingService = TripRatingService();
  bool _isLoading = true;
  Map<String, dynamic> _summary = {'average': 0.0, 'count': 0};
  List<Map<String, dynamic>> _ratings = [];

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    Map<String, dynamic> summary = {'average': 0.0, 'count': 0};
    List<Map<String, dynamic>> ratings = [];

    if (widget.vehicleId != null && widget.vehicleId!.isNotEmpty) {
      summary = await _tripRatingService.getVehicleRatingSummary(
        widget.vehicleId!,
      );
      ratings = await _tripRatingService.getVehicleReceivedRatings(
        widget.vehicleId!,
      );

      // If no vehicle ratings found directly, fall back to owner user ratings if userId is provided
      if (ratings.isEmpty && widget.userId.isNotEmpty) {
        final userSummary = await _tripRatingService.getRatingSummary(
          widget.userId,
        );
        final userRatings = await _tripRatingService.getReceivedRatings(
          widget.userId,
        );
        if (userRatings.isNotEmpty) {
          summary = userSummary;
          ratings = userRatings;
        }
      }
    } else {
      summary = await _tripRatingService.getRatingSummary(widget.userId);
      ratings = await _tripRatingService.getReceivedRatings(widget.userId);
    }

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _ratings = ratings;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        : RefreshIndicator(
            onRefresh: _loadRatings,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSummaryCard(),
                const SizedBox(height: 18),
                if (_ratings.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: const Text(
                      'No ratings yet. Reviews from completed trips will appear here.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ..._ratings.map(_buildRatingCard),
              ],
            ),
          );

    if (widget.embedded) {
      return ColoredBox(color: AppColors.darkBg, child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      appBar: AppBar(
        backgroundColor: AppColors.bgOf(context),
        elevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorderOf(context)),
              boxShadow: AppColors.cardShadowOf(context),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimaryOf(context),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: AppColors.textPrimaryOf(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _buildSummaryCard() {
    final average = (_summary['average'] as num?)?.toDouble() ?? 0.0;
    final count = (_summary['count'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0 ? 'No rating yet' : average.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Reviews will appear after completed trips.'
                      : '$count review${count == 1 ? '' : 's'} received',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(Map<String, dynamic> rating) {
    final reviewer = rating['reviewer'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(rating['reviewer'])
        : <String, dynamic>{};
    final reviewerName =
        reviewer['full_name']?.toString().trim().isNotEmpty == true
        ? reviewer['full_name'].toString().trim()
        : reviewer['email']?.toString().trim().isNotEmpty == true
        ? reviewer['email'].toString().trim()
        : 'Reviewer';
    final score = (rating['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = rating['comment']?.toString().trim() ?? '';
    final imageUrls = rating['image_urls'] is List
        ? List<String>.from(
            (rating['image_urls'] as List)
                .map((item) => item?.toString() ?? '')
                .where((url) => url.trim().isNotEmpty),
          )
        : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : 'R',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCreatedAt(rating['created_at']?.toString()),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                score.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < score.round() ? Icons.star : Icons.star_border,
                color: AppColors.primary,
                size: 18,
              ),
            ),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imageUrls
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: OptimizedNetworkImage(
                        imageUrl: url,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          width: 72,
                          height: 72,
                          color: AppColors.darkBgTertiary,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCreatedAt(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return 'Recently';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
