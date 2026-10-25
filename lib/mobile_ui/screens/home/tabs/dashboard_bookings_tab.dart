part of '../dashboard_screen.dart';

extension _DashboardBookingsTab on _DashboardScreenState {
  Widget _buildBookingsTab() {
    final uiBookings = _uiBookings();
    final visibleBookings = uiBookings
        .where((booking) => booking['statusGroup'] == _selectedBookingStatus)
        .toList();

    return Column(
      children: [
        _buildCenteredTabHeader('My Bookings'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBookings,
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              children: [
                RoleTabHeader(
                  title: 'Rental Bookings',
                  subtitle:
                      'Requests, ongoing rentals, completed trips, and tracking',
                  icon: Icons.calendar_month_outlined,
                  badge: '${uiBookings.length} total',
                ),
                const SizedBox(height: 12),
                _buildRenterBookingStatusTabs(uiBookings),
                const SizedBox(height: 14),
                _buildBookingsList(visibleBookings),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRenterBookingStatusTabs(List<Map<String, dynamic>> bookings) {
    const statuses = [
      'Pending',
      'Approved',
      'Ongoing',
      'Completed',
      'Cancelled',
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((status) {
          final selected = _selectedBookingStatus == status;
          final count = bookings
              .where((booking) => booking['statusGroup'] == status)
              .length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _selectedBookingStatus = status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: status == 'Cancelled' ? 108 : 96,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBg : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.borderColor
                              : AppColors.lightBorderColor),
                  ),
                ),
                child: Text(
                  '$status ($count)',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.black
                        : (isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return RoleEmptyStateCard(
        icon: Icons.route_outlined,
        title: 'No ${_selectedBookingStatus.toLowerCase()} bookings',
        message:
            'Bookings with this status will appear here once available. Pull down to refresh.',
      );
    }

    return Column(
      children: List.generate(
        bookings.length,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () {
              setState(() => selectedBookingIndex = index);
              final booking = bookings[index];
              _isCancelledBooking(booking)
                  ? _showCancellationDetails(booking)
                  : _showBookingDetails(booking);
            },
            child: Builder(
              builder: (context) {
                final booking = bookings[index];
                final isCompleted = booking['statusGroup'] == 'Completed';
                final isCancelled = _isCancelledBooking(booking);
                final rawStatus =
                    booking['rawStatus']?.toString().toLowerCase() ?? '';
                final isNavigable =
                    booking['statusGroup'] == 'Ongoing' &&
                    {'active', 'ongoing'}.contains(rawStatus);

                final bookingIdStr = booking['id'].toString();
                final isReturnSubmitted =
                    rawStatus == 'return_pending_inspection' ||
                    rawStatus == 'awaiting_completion' ||
                    rawStatus == 'completed' ||
                    rawStatus == 'returned' ||
                    rawStatus == 'successful' ||
                    rawStatus == 'success' ||
                    rawStatus == 'awaiting_ratings' ||
                    booking['returned_at'] != null ||
                    booking['returnedAt'] != null;
                final isRated = _isRenterBookingFullyRated(booking);

                final isPaidInFull = BookingService().isBookingFullyPaid(booking) ||
                    BookingService().getBookingRemainingBalance(booking) <= 0.01;
                final isApprovedOrReady = booking['statusGroup'] == 'Approved' ||
                    rawStatus == 'approved' ||
                    rawStatus == 'confirmed' ||
                    rawStatus == 'pending_release';
                final showPayNow = isApprovedOrReady && !isPaidInFull;

                return BookingCard(
                  carName: booking['carName'],
                  rentalPartner: booking['rentalPartner'],
                  status: booking['status'],
                  days: (booking['days'] as num?)?.toInt() ?? 0,
                  pickupLocation: booking['pickupLocation'],
                  dropoffLocation: booking['dropoffLocation'],
                  totalCost: (booking['totalCost'] as num?)?.toInt() ?? 0,
                  rating: (booking['rating'] as num?)?.toDouble() ?? 0.0,
                  isActive: booking['statusGroup'] == 'Ongoing',
                  ongoingSummary: booking['statusGroup'] == 'Ongoing'
                      ? BookingReturnCountdown(booking: booking, compact: true)
                      : null,
                  carImageUrl: booking['imageUrl'] as String?,
                  showRating:
                      booking['statusGroup'] == 'Completed' &&
                      ((booking['rating'] as num?)?.toDouble() ?? 0) > 0,
                  showRateButton: isReturnSubmitted,
                  isAlreadyRated: isRated,
                  isPaidInFull: isPaidInFull,
                  showPayNowButton: showPayNow,
                  onPayNow: () => _handlePreTripReleasePayment(booking),
                  onRateTrip: () async {
                    final submitted = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => TripRatingFlowScreen(
                          bookingId: bookingIdStr,
                          reviewerRole: 'renter',
                          title: 'Rate Trip',
                          subtitle: 'Leave your ratings and reviews for this trip.',
                        ),
                      ),
                    );
                    if (submitted == true) {
                      await TripRatingService().reconcileCompletedBooking(bookingIdStr);
                      _loadBookings();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Rating saved successfully! Thank you.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  },
                  showTrackButton: isNavigable,
                  trackButtonLabel: 'Navigate',
                  onTrack: isNavigable
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TripNavigationScreen(
                              bookingId: booking['id'].toString(),
                              participantRole: 'renter',
                            ),
                          ),
                        )
                      : null,
                  detailsButtonLabel: isCompleted
                      ? 'View Receipt'
                      : isCancelled
                      ? 'Details'
                      : 'View Details',
                  onTap: () => isCancelled
                      ? _showCancellationDetails(booking)
                      : _showBookingDetails(booking),
                  onViewDetails: () => isCompleted
                      ? _showTripReceipt(booking)
                      : isCancelled
                      ? _showCancellationDetails(booking)
                      : _showBookingDetails(booking),
                  showMessageButton: _canOpenBookingConversation(booking),
                  isMessageLocked:
                      !BookingService().isEligibleForBookingChat(booking),
                  messageLockedReason:
                      'Group chat will automatically unlock 72 hours (3 days) before your trip starts.',
                  onMessage: () => _openBookingConversation(booking),
                  showCancelButton:
                      booking['statusGroup'] == 'Pending' &&
                      _canCancelBooking(booking),
                  onCancel: () => _handleBookingCancellation(booking),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

