part of '../operator_web_screen.dart';

extension OperatorBookingsTab on _OperatorWebScreenState {
  Widget _buildBookingsContent(bool isDark) {
    final filteredBookings = _recentBookings.where((booking) {
      final matchesStatus = _bookingFilterMatches(booking, _bookingFilter);
      if (!matchesStatus) return false;
      if (!_bookingDateFilterMatches(booking, _bookingDateFilter)) return false;
      if (!_bookingVehicleTypeFilterMatches(
        booking,
        _bookingVehicleTypeFilter,
      )) {
        return false;
      }
      final query = _bookingSearchQuery.toLowerCase();
      if (query.isEmpty) return true;
      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final renter = booking['renter'] as Map<String, dynamic>? ?? {};
      final haystack = [
        booking['id'],
        renter['full_name'],
        renter['email'],
        _vehicleTitle(vehicle),
        vehicle['plate_number'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    final totalPages = filteredBookings.isEmpty
        ? 1
        : ((filteredBookings.length - 1) ~/ _bookingPageSize) + 1;
    final safePage = _bookingPage.clamp(0, totalPages - 1);
    final pagedBookings = filteredBookings
        .skip(safePage * _bookingPageSize)
        .take(_bookingPageSize)
        .toList();

    final extensionRequestsCount = _recentBookings.where(_hasTripExtension).length;
    final pendingExtensionRequestsCount = _recentBookings.where((b) {
      final category = _getExtensionCategory(b);
      return category == 'pending_review' ||
          category == 'payment_review' ||
          category == 'payment_approved';
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bookings Management',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : _operatorInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review reservations, assign drivers, and monitor trips.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : _operatorInk,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Top Segment Switch: [ Bookings ] | [ Extend Trip Requests ]
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _bookingMainSubSection = 'bookings'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _bookingMainSubSection == 'bookings'
                          ? (_operatorGold)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.book_online_rounded,
                          size: 18,
                          color: _bookingMainSubSection == 'bookings'
                              ? _operatorNavyDeep
                              : (isDark ? Colors.grey[400] : Colors.grey.shade700),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bookings',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _bookingMainSubSection == 'bookings'
                                ? _operatorNavyDeep
                                : (isDark ? Colors.grey[300] : Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _bookingMainSubSection = 'extensions'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _bookingMainSubSection == 'extensions'
                          ? (_operatorGold)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.update_rounded,
                          size: 18,
                          color: _bookingMainSubSection == 'extensions'
                              ? _operatorNavyDeep
                              : (isDark ? Colors.grey[400] : Colors.grey.shade700),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Extend Trip Requests',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _bookingMainSubSection == 'extensions'
                                ? _operatorNavyDeep
                                : (isDark ? Colors.grey[300] : Colors.grey.shade800),
                          ),
                        ),
                        if (pendingExtensionRequestsCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _bookingMainSubSection == 'extensions'
                                  ? Colors.redAccent
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$pendingExtensionRequestsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_bookingMainSubSection == 'extensions')
            _buildExtendTripRequestsSection(isDark)
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBookingFilterTab('all', 'All Bookings', isDark),
                    _buildBookingFilterTab('pending', 'Pending', isDark),
                    _buildBookingFilterTab('approved', 'Approved', isDark),
                    _buildBookingFilterTab('ongoing', 'Ongoing', isDark),
                    _buildBookingFilterTab('completed', 'Completed', isDark),
                    _buildBookingFilterTab('cancelled', 'Cancelled', isDark),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          _buildBookingReportFilters(filteredBookings, isDark),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bookingSearchController,
                    onChanged: (value) => setState(() {
                      _bookingSearchQuery = value.trim();
                      _bookingPage = 0;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search booking ID, renter, or vehicle',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : const Color(0xFFF2F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${filteredBookings.length} result${filteredBookings.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildOperatorBookingsResult(
            pagedBookings,
            isDark,
            totalFiltered: filteredBookings.length,
            currentPage: safePage,
            totalPages: totalPages,
          ),
        ],
        ],
      ),
    );
  }

  bool _hasTripExtension(Map<String, dynamic> booking) {
    final extStatus =
        booking['extension_status']?.toString().toLowerCase().trim() ?? '';
    if (extStatus.isNotEmpty && extStatus != 'none') return true;
    final extReqAt =
        booking['extension_requested_at']?.toString().trim() ?? '';
    final extEndAt =
        booking['extension_requested_end_at']?.toString().trim() ?? '';
    final extDays = booking['extension_days'];
    if ((extReqAt.isNotEmpty || extEndAt.isNotEmpty) &&
        extDays != null &&
        (extDays is num && extDays > 0)) {
      return true;
    }
    return false;
  }

  String _getExtensionCategory(Map<String, dynamic> booking) {
    final extStatus =
        booking['extension_status']?.toString().toLowerCase().trim() ?? '';
    final payStatus =
        booking['extension_payment_status']?.toString().toLowerCase().trim() ?? '';
    final proofUrl =
        booking['extension_payment_proof_url']?.toString().trim() ?? '';

    // 1. Finalized
    if (extStatus == 'finalized' ||
        extStatus == 'approved' ||
        extStatus == 'completed') {
      return 'finalized';
    }

    // 2. Rejected / Cancelled
    if (extStatus == 'rejected' ||
        extStatus == 'cancelled' ||
        extStatus == 'declined') {
      return 'rejected';
    }

    // 3. Payment Approved (Payment confirmed, awaiting final schedule confirmation)
    if (extStatus == 'pending_final_confirmation' ||
        extStatus == 'payment_approved' ||
        extStatus == 'payment_verified' ||
        payStatus == 'verified') {
      return 'payment_approved';
    }

    // 4. Payment Review (Renter uploaded payment proof, awaiting operator verification)
    if (extStatus == 'payment_completed' ||
        extStatus == 'payment_submitted' ||
        extStatus == 'pending_payment_review' ||
        payStatus == 'pending_review' ||
        (proofUrl.isNotEmpty && payStatus != 'paid' && payStatus != 'verified')) {
      return 'payment_review';
    }

    // 5. Pending Payment (Accepted, waiting for renter to pay)
    if (extStatus == 'accepted' ||
        extStatus == 'payment_pending' ||
        extStatus == 'pending_payment' ||
        extStatus == 'awaiting_payment') {
      return 'payment_pending';
    }

    // 6. Pending Review (Initial request, waiting for operator/partner approval)
    if (extStatus == 'pending' ||
        extStatus == 'pending_operator' ||
        extStatus == 'pending_partner' ||
        extStatus == 'under_review' ||
        extStatus == 'requested') {
      return 'pending_review';
    }

    if (_hasTripExtension(booking)) {
      return 'pending_review';
    }

    return 'none';
  }

  Widget _buildExtensionFilterTab(
    String key,
    String label,
    bool isDark, {
    int? count,
  }) {
    final isSelected = _extensionFilter == key ||
        (key == 'pending_review' && _extensionFilter == 'pending') ||
        (key == 'payment_pending' && _extensionFilter == 'pending_payment') ||
        (key == 'payment_review' && _extensionFilter == 'payment_completed') ||
        (key == 'payment_approved' && _extensionFilter == 'pending_final_confirmation');
    final countText = count != null ? ' ($count)' : '';
    final displayText = label.contains('(') ? label : '$label$countText';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          displayText,
          style: TextStyle(
            color: isSelected
                ? _operatorNavyDeep
                : (isDark ? Colors.grey[300] : Colors.grey.shade800),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _extensionFilter = key),
        selectedColor: _operatorGold,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected
                ? _operatorGold
                : (isDark ? Colors.white10 : Colors.grey.shade300),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }

  Widget _buildExtendTripRequestsSection(bool isDark) {
    try {
      final allExtensionBookings =
          _recentBookings.where(_hasTripExtension).toList();

      final pendingReviewCount = allExtensionBookings
          .where((b) => _getExtensionCategory(b) == 'pending_review')
          .length;
      final paymentPendingCount = allExtensionBookings
          .where((b) => _getExtensionCategory(b) == 'payment_pending')
          .length;
      final paymentReviewCount = allExtensionBookings
          .where((b) => _getExtensionCategory(b) == 'payment_review')
          .length;
      final paymentApprovedCount = allExtensionBookings
          .where((b) => _getExtensionCategory(b) == 'payment_approved')
          .length;
      final finalizedCount = allExtensionBookings
          .where((b) => _getExtensionCategory(b) == 'finalized')
          .length;
      final rejectedCount = allExtensionBookings
          .where((b) => _getExtensionCategory(b) == 'rejected')
          .length;

      final filteredExtensions = allExtensionBookings.where((booking) {
        final category = _getExtensionCategory(booking);
        final matchesFilter = switch (_extensionFilter) {
          'all' => true,
          'pending' || 'pending_review' => category == 'pending_review',
          'payment_pending' || 'pending_payment' => category == 'payment_pending',
          'payment_completed' || 'payment_review' => category == 'payment_review',
          'pending_final_confirmation' || 'payment_approved' =>
            category == 'payment_approved',
          'finalized' => category == 'finalized',
          'rejected' => category == 'rejected',
          _ => true,
        };
        if (!matchesFilter) return false;

        if (_extensionSearchQuery.isNotEmpty) {
          final query = _extensionSearchQuery.toLowerCase();
          final vehicleRaw = booking['vehicles'] ?? booking['partner_vehicles'];
          final vehicle = vehicleRaw is Map<String, dynamic>
              ? vehicleRaw
              : (vehicleRaw is Map ? Map<String, dynamic>.from(vehicleRaw) : <String, dynamic>{});
          final renterRaw = booking['renter'] ?? booking['users'];
          final renter = renterRaw is Map<String, dynamic>
              ? renterRaw
              : (renterRaw is Map ? Map<String, dynamic>.from(renterRaw) : <String, dynamic>{});
          final ownerRaw = vehicle['owner'] ?? vehicle['partners'] ?? booking['partner'];
          final owner = ownerRaw is Map<String, dynamic>
              ? ownerRaw
              : (ownerRaw is Map ? Map<String, dynamic>.from(ownerRaw) : <String, dynamic>{});
          final bId = booking['id']?.toString() ?? '';
          final shortBId = bId.length >= 8 ? bId.substring(0, 8) : bId;
          final haystack = [
            bId,
            'EXT-$shortBId',
            renter['full_name'],
            renter['email'],
            renter['phone'],
            _vehicleTitle(vehicle),
            vehicle['plate_number'],
            owner['full_name'],
            booking['dropoff_location'],
            booking['extension_requested_destination'],
          ].whereType<Object>().join(' ').toLowerCase();
          if (!haystack.contains(query)) return false;
        }

        return true;
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildExtensionFilterTab(
                    'all',
                    'All Requests',
                    isDark,
                    count: allExtensionBookings.length,
                  ),
                  _buildExtensionFilterTab(
                    'pending_review',
                    'Pending Review',
                    isDark,
                    count: pendingReviewCount,
                  ),
                  _buildExtensionFilterTab(
                    'payment_pending',
                    'Pending Payment',
                    isDark,
                    count: paymentPendingCount,
                  ),
                  _buildExtensionFilterTab(
                    'payment_review',
                    'Payment Review',
                    isDark,
                    count: paymentReviewCount,
                  ),
                  _buildExtensionFilterTab(
                    'payment_approved',
                    'Payment Approved',
                    isDark,
                    count: paymentApprovedCount,
                  ),
                  _buildExtensionFilterTab(
                    'finalized',
                    'Finalized',
                    isDark,
                    count: finalizedCount,
                  ),
                  _buildExtensionFilterTab(
                    'rejected',
                    'Rejected / Cancelled',
                    isDark,
                    count: rejectedCount,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _extensionSearchController,
                    onChanged: (value) => setState(() {
                      _extensionSearchQuery = value.trim();
                    }),
                    decoration: InputDecoration(
                      hintText:
                          'Search request ID, renter, vehicle, destination, or owner...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : const Color(0xFFF2F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${filteredExtensions.length} request${filteredExtensions.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (filteredExtensions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.update_disabled_rounded,
                    size: 56,
                    color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No trip extension requests found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _extensionFilter == 'all'
                        ? 'When renters request to extend their active rentals, they will appear here.'
                        : 'No extension requests currently match the selected filter.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            ...filteredExtensions.map(
              (booking) {
                try {
                  return _buildExtendTripRequestCard(booking, isDark);
                } catch (e) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Error displaying extension request (${booking['id']}): $e',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  );
                }
              },
            ),
        ],
      );
    } catch (err, stack) {
      debugPrint('Error building extension requests section: $err\n$stack');
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unable to display Extend Trip Requests',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            Text(
              'Details: $err',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[800]),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildExtendTripRequestCard(
    Map<String, dynamic> booking,
    bool isDark,
  ) {
    final bookingId = booking['id']?.toString() ?? '';
    final shortBId =
        bookingId.length >= 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase();
    final requestId = 'EXT-$shortBId';

    final vehicleRaw = booking['vehicles'] ?? booking['partner_vehicles'];
    final vehicle = vehicleRaw is Map<String, dynamic>
        ? vehicleRaw
        : (vehicleRaw is Map ? Map<String, dynamic>.from(vehicleRaw) : <String, dynamic>{});
    final renterRaw = booking['renter'] ?? booking['users'];
    final renter = renterRaw is Map<String, dynamic>
        ? renterRaw
        : (renterRaw is Map ? Map<String, dynamic>.from(renterRaw) : <String, dynamic>{});
    final ownerRaw = vehicle['owner'] ?? vehicle['partners'] ?? booking['partner'];
    final owner = ownerRaw is Map<String, dynamic>
        ? ownerRaw
        : (ownerRaw is Map ? Map<String, dynamic>.from(ownerRaw) : <String, dynamic>{});
    final isPartner = _isPartnerOwnedBooking(booking);

    final extStatus =
        booking['extension_status']?.toString().toLowerCase().trim() ?? 'pending';
    final payStatus =
        booking['extension_payment_status']?.toString().toLowerCase().trim() ?? 'unpaid';
    final category = _getExtensionCategory(booking);

    final requestedAt = DateTime.tryParse(
      booking['extension_requested_at']?.toString() ?? '',
    );
    final requestedEndAt = DateTime.tryParse(
      booking['extension_requested_end_at']?.toString() ?? '',
    );
    final currentStartAt = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );
    final currentEndAt = DateTime.tryParse(
      (booking['end_at'] ?? booking['end_date'])?.toString() ?? '',
    );

    final extensionDays = int.tryParse(booking['extension_days']?.toString() ?? '') ??
        (booking['extension_days'] is num ? (booking['extension_days'] as num).toInt() : 1);
    final additionalPrice = double.tryParse(booking['extension_additional_price']?.toString() ?? '') ??
        (booking['extension_additional_price'] is num ? (booking['extension_additional_price'] as num).toDouble() : 0.0);
    final rawPrincipal = double.tryParse((booking['principal_total_price'] ?? booking['total_price'])?.toString() ?? '') ?? 0.0;
    final originalPrice = rawPrincipal - (extStatus == 'finalized' ? additionalPrice : 0.0);
    final updatedTotalPrice = extStatus == 'finalized'
        ? (double.tryParse(booking['total_price']?.toString() ?? '') ?? (originalPrice + additionalPrice))
        : (originalPrice + additionalPrice);

    final currentDestination =
        booking['dropoff_location']?.toString().trim() ?? 'PSDC Main Garage';
    final requestedDestination =
        booking['extension_requested_destination']?.toString().trim() ??
        currentDestination;

    final proofUrl =
        booking['extension_payment_proof_url']?.toString().trim() ?? '';
    final paymentMethod =
        booking['extension_payment_method']?.toString().trim() ?? 'E-Wallet';
    final paymentRef =
        booking['extension_payment_reference']?.toString().trim() ?? 'N/A';

    final renterName = renter['full_name']?.toString().trim().isNotEmpty == true
        ? renter['full_name'].toString().trim()
        : (renter['email']?.toString().trim().isNotEmpty == true
            ? renter['email'].toString().trim()
            : 'Renter');
    final renterPhone = renter['phone']?.toString().trim() ?? 'No phone';
    final renterAvatar = _operatorUserAvatarUrl(renter);

    final vehicleName = _vehicleTitle(vehicle);
    final vehiclePlate = vehicle['plate_number']?.toString().trim() ?? 'No Plate';
    final vehicleImage = _normalizeVehicleImageUrl(vehicle['image_url']);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _operatorGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.update_rounded,
                    color: _operatorGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          requestId,
                          style: TextStyle(
                            color: isDark ? Colors.white : _operatorInk,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• Booking #$shortBId',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      requestedAt != null
                          ? 'Requested ${_formatBookingDateTime(requestedAt)}'
                          : 'Recent request',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Vehicle Ownership Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPartner
                        ? Colors.purple.withOpacity(0.15)
                        : _operatorNavy.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPartner
                          ? Colors.purple.withOpacity(0.4)
                          : _operatorGold.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPartner ? Icons.handshake_outlined : Icons.business_rounded,
                        size: 14,
                        color: isPartner ? Colors.purpleAccent : _operatorGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPartner
                            ? 'PARTNER VEHICLE (READ-ONLY)'
                            : 'OPERATOR VEHICLE (ACTIONABLE)',
                        style: TextStyle(
                          color: isPartner
                              ? (isDark ? Colors.purple[200] : Colors.purple[800])
                              : (isDark ? _operatorGold : _operatorNavy),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content Grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    return isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildRenterInfoSection(renterName, renterPhone, renterAvatar, isDark)),
                              const SizedBox(width: 20),
                              Expanded(flex: 3, child: _buildVehicleInfoSection(vehicleName, vehiclePlate, vehicleImage, isDark)),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: _buildTripExtensionScheduleSection(currentStartAt, currentEndAt, requestedEndAt, extensionDays, currentDestination, requestedDestination, isDark)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRenterInfoSection(renterName, renterPhone, renterAvatar, isDark),
                              const SizedBox(height: 16),
                              _buildVehicleInfoSection(vehicleName, vehiclePlate, vehicleImage, isDark),
                              const SizedBox(height: 16),
                              _buildTripExtensionScheduleSection(currentStartAt, currentEndAt, requestedEndAt, extensionDays, currentDestination, requestedDestination, isDark),
                            ],
                          );
                  },
                ),

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Financial & Status Summary Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Financial summary
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORIGINAL RENTAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'PHP ${originalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Text(
                              '+',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _operatorGold,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EXTENSION FEE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _operatorGold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+PHP ${additionalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: _operatorGold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Text(
                              '=',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'UPDATED TOTAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'PHP ${updatedTotalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Status badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildExtensionStatusPill(extStatus, booking: booking),
                        const SizedBox(height: 6),
                        _buildExtensionPaymentStatusPill(payStatus, method: paymentMethod),
                      ],
                    ),
                  ],
                ),

                // Payment proof snippet if submitted
                if (proofUrl.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Extension Payment Proof Submitted by Renter',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$paymentMethod • Ref: $paymentRef',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showReceiptProofDialog(proofUrl, isDark),
                          icon: const Icon(Icons.open_in_full_rounded, size: 14),
                          label: const Text('View Receipt'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Action Bar
                Row(
                  children: [
                    // Chat button for all
                    ElevatedButton.icon(
                      onPressed: () => _openBookingConversation(booking),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: Text(
                        isPartner
                            ? 'Open Shared Chat (Renter ↔ Partner ↔ Operator)'
                            : 'Open Shared Chat',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                        foregroundColor: isDark ? Colors.white : _operatorInk,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isDark ? Colors.white10 : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Actionable buttons for Operator vs Read-only for Partner
                    if (!isPartner) ...[
                      if (category == 'pending_review') ...[
                        OutlinedButton.icon(
                          onPressed: () => _showOperatorRejectExtensionDialog(booking),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Reject Request'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _handleOperatorAcceptExtension(booking),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: const Text('Accept & Request Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorGold,
                            foregroundColor: _operatorNavyDeep,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ] else if (category == 'payment_pending') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withOpacity(0.35)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_empty_rounded, size: 16, color: Colors.amber),
                              SizedBox(width: 6),
                              Text(
                                'Awaiting Renter Payment Upload',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => _handleOperatorRecordCashPayment(booking),
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: const Text('Verify Cash/Desk Payment'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ] else if (category == 'payment_review') ...[
                        OutlinedButton.icon(
                          onPressed: () => _showOperatorRejectExtensionPaymentDialog(booking),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Reject Payment Proof'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _handleOperatorVerifyExtensionPayment(booking),
                          icon: const Icon(Icons.verified_user_rounded, size: 16),
                          label: const Text('Verify & Approve Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ] else if (category == 'payment_approved') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 6),
                              Text(
                                'Payment Approved • Ready to Finalize',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _handleOperatorFinalizeExtension(booking),
                          icon: const Icon(Icons.task_alt_rounded, size: 16),
                          label: const Text('Confirm & Finalize Extension'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ] else if (category == 'finalized') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 6),
                              Text(
                                'Extension Finalized & Committed',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (category == 'rejected') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                              const SizedBox(width: 6),
                              Text(
                                booking['extension_rejection_reason']?.toString().trim().isNotEmpty == true
                                    ? 'Declined: ${booking['extension_rejection_reason']}'
                                    : 'Extension Request Declined',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_clock_rounded, size: 16, color: Colors.purpleAccent),
                            const SizedBox(width: 8),
                            Text(
                              'Managed by Partner ${owner['full_name'] ?? ''} • Monitoring Mode',
                              style: TextStyle(
                                color: isDark ? Colors.purple[200] : Colors.purple[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenterInfoSection(
    String name,
    String phone,
    String? avatarUrl,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _operatorGold.withOpacity(0.2),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'R',
                    style: TextStyle(
                      color: _operatorGold,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RENTER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoSection(
    String title,
    String plate,
    String imageUrl,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            child: imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: OptimizedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    Icons.directions_car_rounded,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VEHICLE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plate,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _operatorGold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripExtensionScheduleSection(
    DateTime? currentStart,
    DateTime? currentEnd,
    DateTime? requestedEnd,
    int days,
    String currentDest,
    String requestedDest,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORIGINAL SCHEDULE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentEnd != null ? _formatDateShort(currentEnd.toIso8601String()) : 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REQUESTED EXTENSION',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      requestedEnd != null
                          ? '${_formatDateShort(requestedEnd.toIso8601String())} (+$days d)'
                          : 'N/A',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 13, color: isDark ? Colors.grey[400] : Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  requestedDest != currentDest
                      ? 'New Dest: $requestedDest'
                      : 'Dest: $currentDest',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: requestedDest != currentDest ? FontWeight.bold : FontWeight.normal,
                    color: requestedDest != currentDest ? _operatorGold : (isDark ? Colors.grey[400] : Colors.grey.shade600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionStatusPill(
    String status, {
    Map<String, dynamic>? booking,
  }) {
    final category = booking != null
        ? _getExtensionCategory(booking)
        : switch (status) {
            'pending' ||
            'pending_operator' ||
            'pending_partner' ||
            'under_review' ||
            'requested' =>
              'pending_review',
            'accepted' ||
            'payment_pending' ||
            'pending_payment' ||
            'awaiting_payment' =>
              'payment_pending',
            'payment_completed' ||
            'payment_submitted' ||
            'pending_payment_review' =>
              'payment_review',
            'pending_final_confirmation' ||
            'payment_approved' ||
            'payment_verified' =>
              'payment_approved',
            'finalized' || 'approved' || 'completed' => 'finalized',
            'rejected' => 'rejected',
            'cancelled' || 'declined' => 'cancelled',
            _ => status,
          };

    Color bg;
    Color fg;
    String label;

    switch (category) {
      case 'pending_review':
        bg = const Color(0xFFF59E0B).withOpacity(0.15);
        fg = const Color(0xFFF59E0B);
        label = 'Pending Review';
        break;
      case 'payment_pending':
        bg = const Color(0xFF38BDF8).withOpacity(0.15);
        fg = const Color(0xFF38BDF8);
        label = 'Pending Payment';
        break;
      case 'payment_review':
        bg = const Color(0xFFA855F7).withOpacity(0.15);
        fg = const Color(0xFFA855F7);
        label = 'Payment Review';
        break;
      case 'payment_approved':
        bg = const Color(0xFF10B981).withOpacity(0.15);
        fg = const Color(0xFF10B981);
        label = 'Payment Approved';
        break;
      case 'finalized':
        bg = const Color(0xFF059669).withOpacity(0.15);
        fg = const Color(0xFF059669);
        label = 'Finalized';
        break;
      case 'rejected':
        bg = const Color(0xFFEF4444).withOpacity(0.15);
        fg = const Color(0xFFEF4444);
        label = 'Rejected';
        break;
      case 'cancelled':
        bg = Colors.grey.withOpacity(0.15);
        fg = Colors.grey;
        label = 'Cancelled';
        break;
      default:
        bg = Colors.grey.withOpacity(0.15);
        fg = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildExtensionPaymentStatusPill(String status, {required String method}) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'paid':
        bg = const Color(0xFF10B981).withOpacity(0.15);
        fg = const Color(0xFF10B981);
        label = 'Paid ($method)';
        break;
      case 'verified':
        bg = const Color(0xFF6366F1).withOpacity(0.15);
        fg = const Color(0xFF6366F1);
        label = 'Payment Verified';
        break;
      case 'pending_review':
        bg = const Color(0xFFA855F7).withOpacity(0.15);
        fg = const Color(0xFFA855F7);
        label = 'Payment Under Review';
        break;
      case 'unpaid':
      default:
        bg = const Color(0xFFEF4444).withOpacity(0.15);
        fg = const Color(0xFFEF4444);
        label = 'Payment Due';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _handleOperatorAcceptExtension(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final operatorId = Supabase.instance.client.auth.currentUser?.id ?? '';
    try {
      await BookingService().acceptTripExtension(
        bookingId: bookingId,
        reviewerId: operatorId,
        reviewerRole: 'operator',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extension request accepted! Renter notified to complete payment.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadDashboardData();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error accepting extension: $e');
    }
  }

  Future<void> _handleOperatorVerifyExtensionPayment(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final operatorId = Supabase.instance.client.auth.currentUser?.id ?? '';
    try {
      await BookingService().verifyExtensionPayment(
        bookingId: bookingId,
        verifierId: operatorId,
        verifierRole: 'operator',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verified! Request is ready for final confirmation.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadDashboardData();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error verifying payment: $e');
    }
  }

  Future<void> _handleOperatorFinalizeExtension(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    final operatorId = Supabase.instance.client.auth.currentUser?.id ?? '';
    try {
      await BookingService().finalizeTripExtension(
        bookingId: bookingId,
        finalizerId: operatorId,
        finalizerRole: 'operator',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip extension finalized! Booking dates, destination, and pricing committed.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadDashboardData();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error finalizing extension: $e');
    }
  }

  Future<void> _showOperatorRejectExtensionDialog(Map<String, dynamic> booking) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookingId = booking['id']?.toString() ?? '';
    final reasonController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reject Trip Extension'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejecting this extension request:'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Vehicle needed for maintenance or scheduled booking.',
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final operatorId = Supabase.instance.client.auth.currentUser?.id ?? '';
                Navigator.pop(dialogContext);
                try {
                  await BookingService().rejectTripExtension(
                    bookingId: bookingId,
                    reviewerId: operatorId,
                    reviewerRole: 'operator',
                    reason: reasonController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Trip extension rejected.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    _loadDashboardData();
                  }
                } catch (e) {
                  if (mounted) _showErrorSnackBar('Error rejecting extension: $e');
                }
              },
              child: const Text('Reject Request'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOperatorRejectExtensionPaymentDialog(
    Map<String, dynamic> booking,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookingId = booking['id']?.toString() ?? '';
    final reasonController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Reject Payment Proof'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please specify why this extension payment receipt is being declined. The renter will be notified to re-upload a valid proof:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'e.g. Unreadable receipt screenshot or reference number not found.',
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final operatorId =
                    Supabase.instance.client.auth.currentUser?.id ?? '';
                Navigator.pop(dialogContext);
                try {
                  await BookingService().rejectExtensionPayment(
                    bookingId: bookingId,
                    reviewerId: operatorId,
                    reviewerRole: 'operator',
                    reason: reasonController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Payment proof rejected. Renter notified to submit valid receipt.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    _loadDashboardData();
                  }
                } catch (e) {
                  if (mounted) {
                    _showErrorSnackBar('Error rejecting payment proof: $e');
                  }
                }
              },
              child: const Text('Reject Proof'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleOperatorRecordCashPayment(
    Map<String, dynamic> booking,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookingId = booking['id']?.toString() ?? '';
    final refController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Record Cash / Desk Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm receipt of extension fee paid in cash or at the service desk:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refController,
                decoration: InputDecoration(
                  labelText: 'Receipt / Reference # (Optional)',
                  hintText: 'e.g. CASH-DESK-001',
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final operatorId =
                    Supabase.instance.client.auth.currentUser?.id ?? '';
                Navigator.pop(dialogContext);
                try {
                  await BookingService().verifyCashExtensionPayment(
                    bookingId: bookingId,
                    verifierId: operatorId,
                    reference: refController.text.trim(),
                    verifierRole: 'operator',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Cash payment verified! Request is ready for final confirmation.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadDashboardData();
                  }
                } catch (e) {
                  if (mounted) {
                    _showErrorSnackBar('Error recording cash payment: $e');
                  }
                }
              },
              child: const Text('Verify & Approve Payment'),
            ),
          ],
        );
      },
    );
  }

  String _formatDateShort(String? raw) {
    if (raw == null || raw.isEmpty) return 'N/A';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  bool _bookingFilterMatches(Map<String, dynamic> booking, String filter) {
    if (filter == 'all') return true;
    if (filter == 'extension_requests' || filter == 'extension') {
      return _hasTripExtension(booking);
    }
    final group = bookingStatusGroup(booking['status']);
    return switch (filter) {
      'pending' => group == BookingStatusGroup.pending,
      'approved' => group == BookingStatusGroup.approved,
      'ongoing' => group == BookingStatusGroup.ongoing,
      'completed' => group == BookingStatusGroup.completed,
      'cancelled' => group == BookingStatusGroup.cancelled,
      _ => true,
    };
  }

  bool _bookingDateFilterMatches(Map<String, dynamic> booking, String filter) {
    if (filter == 'all') return true;
    final start = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    )?.toLocal();
    if (start == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDay = DateTime(start.year, start.month, start.day);
    return switch (filter) {
      'today' => bookingDay == today,
      'next7' =>
        !bookingDay.isBefore(today) &&
            bookingDay.isBefore(today.add(const Duration(days: 8))),
      'next30' =>
        !bookingDay.isBefore(today) &&
            bookingDay.isBefore(today.add(const Duration(days: 31))),
      'past30' =>
        !bookingDay.isAfter(today) &&
            bookingDay.isAfter(today.subtract(const Duration(days: 31))),
      _ => true,
    };
  }

  bool _bookingVehicleTypeFilterMatches(
    Map<String, dynamic> booking,
    String filter,
  ) {
    if (filter == 'all') return true;
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final type = (vehicle['vehicle_type'] ?? vehicle['category'])
        ?.toString()
        .trim()
        .toLowerCase();
    return type == filter;
  }

  List<String> get _bookingVehicleTypeOptions {
    final types =
        _recentBookings
            .map((booking) {
              final vehicle =
                  booking['vehicles'] as Map<String, dynamic>? ?? {};
              return (vehicle['vehicle_type'] ?? vehicle['category'])
                  ?.toString()
                  .trim()
                  .toLowerCase();
            })
            .whereType<String>()
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['all', ...types];
  }

  String _bookingFilterDisplayName(String value) {
    if (value == 'all') return 'All Types';
    return value
        .split(RegExp(r'[\s_-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Widget _buildBookingReportFilters(
    List<Map<String, dynamic>> filteredBookings,
    bool isDark,
  ) {
    final foreground = isDark ? Colors.grey[300] : Colors.grey.shade700;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list_rounded, size: 17, color: foreground),
              const SizedBox(width: 7),
              Text(
                'Filter by:',
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          _buildBookingDropdownFilter(
            value: _bookingDateFilter,
            items: const {
              'all': 'Date Range: All Dates',
              'today': 'Date Range: Today',
              'next7': 'Date Range: Next 7 Days',
              'next30': 'Date Range: Next 30 Days',
              'past30': 'Date Range: Past 30 Days',
            },
            isDark: isDark,
            onChanged: (value) => setState(() {
              _bookingDateFilter = value;
              _bookingPage = 0;
            }),
          ),
          _buildBookingDropdownFilter(
            value: _bookingVehicleTypeFilter,
            items: {
              for (final type in _bookingVehicleTypeOptions)
                type: 'Vehicle: ${_bookingFilterDisplayName(type)}',
            },
            isDark: isDark,
            onChanged: (value) => setState(() {
              _bookingVehicleTypeFilter = value;
              _bookingPage = 0;
            }),
          ),
          ElevatedButton.icon(
            onPressed: filteredBookings.isEmpty
                ? null
                : () => _exportBookingsReport(filteredBookings),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? _operatorGold : _operatorNavy,
              foregroundColor: isDark ? _operatorNavyDeep : Colors.white,
              disabledBackgroundColor: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade200,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(Icons.download_rounded, size: 17),
            label: const Text(
              'Export Report',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDropdownFilter({
    required String value,
    required Map<String, String> items,
    required bool isDark,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = items.containsKey(value) ? value : items.keys.first;
    return Container(
      height: 42,
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: isDark ? AppColors.darkCard : Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: TextStyle(
            color: isDark ? Colors.white : _operatorInk,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          items: items.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (nextValue) {
            if (nextValue != null) onChanged(nextValue);
          },
        ),
      ),
    );
  }

  Future<void> _exportBookingsReport(
    List<Map<String, dynamic>> bookings,
  ) async {
    String csvCell(Object? value) {
      final text = value?.toString() ?? '';
      return '"${text.replaceAll('"', '""')}"';
    }

    final rows = <String>[
      [
        'Booking ID',
        'Renter',
        'Vehicle',
        'Vehicle Type',
        'Plate Number',
        'Renter Email',
        'Driver',
        'Start',
        'Return',
        'Service',
        'Pickup',
        'Destination',
        'Status',
        'Payment Status',
        'Settlement Status',
        'Total',
        'Completed At',
      ].map(csvCell).join(','),
      ...bookings.map((booking) {
        final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
        final renter = booking['renter'] as Map<String, dynamic>? ?? {};
        final driver = booking['driver'] as Map<String, dynamic>? ?? {};
        final driverUser = driver['user'] as Map<String, dynamic>? ?? {};
        final start = DateTime.tryParse(
          (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
        );
        final end = DateTime.tryParse(
          (booking['end_at'] ?? booking['end_date'])?.toString() ?? '',
        );
        final completedAt = DateTime.tryParse(
          booking['completed_at']?.toString() ?? '',
        );
        return [
          booking['id'],
          renter['full_name'],
          _vehicleTitle(vehicle),
          vehicle['vehicle_type'] ?? vehicle['category'],
          vehicle['plate_number'],
          renter['email'],
          driverUser['full_name'] ??
              (_bookingNeedsDriver(booking['with_driver'])
                  ? 'Unassigned'
                  : 'Self-drive'),
          _formatBookingDateTime(start),
          _formatBookingDateTime(end),
          _bookingNeedsDriver(booking['with_driver'])
              ? 'With professional driver'
              : 'Self-drive',
          booking['pickup_location'],
          booking['dropoff_location'],
          bookingStatusLabel(bookingStatusGroup(booking['status'])),
          booking['final_payment_status'] ?? 'pending',
          booking['commission_status'] ?? 'not_ready',
          booking['total_price'] ?? booking['total_cost'] ?? 0,
          completedAt == null ? '' : _formatBookingDateTime(completedAt),
        ].map(csvCell).join(',');
      }),
    ];
    final bytes = Uint8List.fromList(utf8.encode(rows.join('\r\n')));
    final date = DateTime.now().toIso8601String().split('T').first;

    try {
      await exportCsvFile(fileName: 'mobilis-bookings-$date.csv', bytes: bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking report exported successfully.'),
          ),
        );
      }
    } catch (error) {
      _showErrorSnackBar('Could not export booking report: $error');
    }
  }

  int _bookingFilterCount(String filter) {
    return _recentBookings
        .where((booking) => _bookingFilterMatches(booking, filter))
        .length;
  }

  Widget _buildBookingFilterTab(String value, String label, bool isDark) {
    final selected = _bookingFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: () => setState(() {
          _bookingFilter = value;
          _bookingPage = 0;
        }),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? _operatorGold : _operatorNavy)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$label (${_bookingFilterCount(value)})',
            style: TextStyle(
              color: selected
                  ? (isDark ? _operatorNavyDeep : Colors.white)
                  : (isDark ? Colors.grey[300] : Colors.grey.shade700),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorBookingsResult(
    List<Map<String, dynamic>> bookings,
    bool isDark, {
    required int totalFiltered,
    required int currentPage,
    required int totalPages,
  }) {
    if (bookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _operatorGold.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.event_busy_outlined,
                color: _operatorNavy,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No matching bookings',
              style: TextStyle(
                color: isDark ? Colors.white : _operatorInk,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Try another status or clear the search field.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              ...bookings.map(
                (booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOperatorBookingCard(booking, isDark),
                ),
              ),
              _buildOperatorBookingPaginationFooter(
                visibleCount: bookings.length,
                totalFiltered: totalFiltered,
                currentPage: currentPage,
                totalPages: totalPages,
                isDark: isDark,
              ),
            ],
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.borderColor : Colors.grey.shade200,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildOperatorBookingTableHeader(isDark),
              ...bookings.map(
                (booking) => _buildOperatorBookingTableRow(booking, isDark),
              ),
              _buildOperatorBookingPaginationFooter(
                visibleCount: bookings.length,
                totalFiltered: totalFiltered,
                currentPage: currentPage,
                totalPages: totalPages,
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOperatorBookingPaginationFooter({
    required int visibleCount,
    required int totalFiltered,
    required int currentPage,
    required int totalPages,
    required bool isDark,
  }) {
    final firstItem = totalFiltered == 0
        ? 0
        : (currentPage * _bookingPageSize) + 1;
    final lastItem = totalFiltered == 0 ? 0 : firstItem + visibleCount - 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.025)
            : const Color(0xFFFAFBFC),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Text(
            'Showing $firstItem-$lastItem of $totalFiltered bookings',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (totalPages > 1)
            _buildOperatorBookingPagination(
              currentPage: currentPage,
              totalPages: totalPages,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildOperatorBookingPagination({
    required int currentPage,
    required int totalPages,
    required bool isDark,
  }) {
    final pageItems = _dashboardQueuePageItems(currentPage, totalPages);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dashboardQueuePageButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous page',
          enabled: currentPage > 0,
          isDark: isDark,
          onTap: () => setState(() => _bookingPage = currentPage - 1),
        ),
        const SizedBox(width: 5),
        for (final page in pageItems) ...[
          if (page == -1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Text(
                '...',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            _dashboardQueuePageButton(
              label: '${page + 1}',
              selected: page == currentPage,
              enabled: true,
              isDark: isDark,
              onTap: () => setState(() => _bookingPage = page),
            ),
          const SizedBox(width: 5),
        ],
        _dashboardQueuePageButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next page',
          enabled: currentPage < totalPages - 1,
          isDark: isDark,
          onTap: () => setState(() => _bookingPage = currentPage + 1),
        ),
      ],
    );
  }

  Widget _buildOperatorBookingTableHeader(bool isDark) {
    Widget label(String text, int flex) => Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
          fontSize: 10,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF7F8FA),
      child: Row(
        children: [
          label('Booking ID', 2),
          label('Customer', 3),
          label('Vehicle', 3),
          label('Driver', 3),
          label('Date & Time', 3),
          label('Status', 2),
          label('Actions', 5),
        ],
      ),
    );
  }

  Widget _buildOperatorBookingTableRow(
    Map<String, dynamic> booking,
    bool isDark,
  ) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final driver = booking['driver'] as Map<String, dynamic>?;
    final driverUser = driver?['user'] as Map<String, dynamic>?;
    final bookingId = booking['id']?.toString() ?? '';
    final displayId = bookingId.length > 8
        ? '#${bookingId.substring(0, 8).toUpperCase()}'
        : '#${bookingId.toUpperCase()}';
    final start = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );
    final needsDriver = _bookingNeedsDriver(booking['with_driver']);
    final driverName = driverUser?['full_name']?.toString().trim();

    Widget cell(Widget child, int flex) => Expanded(
      flex: flex,
      child: Align(alignment: Alignment.center, child: child),
    );
    final primaryColor = isDark ? Colors.white : _operatorInk;
    final Color mutedColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setRowHover) {
        return MouseRegion(
          onEnter: (_) => setRowHover(() => isHovered = true),
          onExit: (_) => setRowHover(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: BoxDecoration(
              color: isHovered
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF8FAFC))
                  : Colors.transparent,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                cell(
                  Text(
                    displayId,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  2,
                ),
                cell(
                  _buildOperatorPersonCell(
                    renter['full_name']?.toString() ?? 'Unknown renter',
                    renter['email']?.toString() ?? 'Renter',
                    primaryColor,
                    mutedColor,
                    avatarUrl: _operatorUserAvatarUrl(renter),
                    centered: true,
                  ),
                  3,
                ),
                cell(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 17,
                        color: isDark ? _operatorGold : _operatorNavy,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _vehicleTitle(
                            vehicle.isNotEmpty && vehicle['brand'] != null
                                ? vehicle
                                : booking,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_isPartnerVehicleBooking(booking)) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: Colors.purple.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.handshake_outlined,
                                size: 11,
                                color: Colors.purpleAccent,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Partner',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.purple[200]
                                      : Colors.purple[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  3,
                ),
                cell(
                  Text(
                    needsDriver
                        ? (driverName == null || driverName.isEmpty
                              ? 'Unassigned'
                              : driverName)
                        : 'Self-drive',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: needsDriver && (driverName == null || driverName.isEmpty)
                          ? Colors.red.shade400
                          : primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  3,
                ),
                cell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (UpcomingReleaseCountdownBadge.isWithin24Hours(booking)) ...[
                        UpcomingReleaseCountdownBadge(
                          booking: booking,
                          compact: true,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        _formatBookingDateTime(start),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: primaryColor, fontSize: 11),
                      ),
                      if (_isOngoingBooking(booking)) ...[
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: BookingReturnCountdown(
                            booking: booking,
                            compact: true,
                            lightBackground: !isDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                  3,
                ),
                cell(
                  Align(
                    alignment: Alignment.center,
                    child: _buildStatusBadge(
                      booking['status']?.toString() ?? 'pending',
                    ),
                  ),
                  2,
                ),
                cell(
                  _buildOperatorBookingActions(
                    booking,
                    isDark,
                    compact: true,
                  ),
                  5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOperatorPersonCell(
    String name,
    String detail,
    Color primaryColor,
    Color mutedColor, {
    String? avatarUrl,
    bool centered = false,
  }) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final avatarFallback = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE9FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: _operatorNavy,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (avatarUrl != null && avatarUrl.isNotEmpty)
          OptimizedNetworkImage(
            imageUrl: avatarUrl,
            width: 34,
            height: 34,
            borderRadius: BorderRadius.circular(10),
            placeholder: avatarFallback,
            errorWidget: avatarFallback,
          )
        else
          avatarFallback,
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: centered
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                name,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                detail,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: mutedColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _operatorUserAvatarUrl(dynamic user) {
    if (user == null) return null;
    final map = user is Map<String, dynamic>
        ? user
        : (user is Map ? Map<String, dynamic>.from(user) : <String, dynamic>{});
    for (final key in const ['avatar_url', 'profile_picture_url']) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Widget _buildOperatorBookingCard(Map<String, dynamic> booking, bool isDark) {
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final isPartner = _isPartnerVehicleBooking(booking);
    final start = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _vehicleTitle(vehicle),
                        style: TextStyle(
                          color: isDark ? Colors.white : _operatorInk,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isPartner) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.purple.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.handshake_outlined,
                              size: 12,
                              color: Colors.purpleAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Partner',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.purple[200]
                                    : Colors.purple[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(booking['status']?.toString() ?? 'pending'),
            ],
          ),
          const SizedBox(height: 12),
          _buildOperatorPersonCell(
            renter['full_name']?.toString() ?? 'Unknown renter',
            renter['email']?.toString() ?? 'Renter',
            isDark ? Colors.grey.shade200 : _operatorInk,
            isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            avatarUrl: _operatorUserAvatarUrl(renter),
          ),
          const SizedBox(height: 5),
          if (UpcomingReleaseCountdownBadge.isWithin24Hours(booking)) ...[
            UpcomingReleaseCountdownBadge(booking: booking, isDark: isDark),
            const SizedBox(height: 2),
          ],
          Text(
            _formatBookingDateTime(start),
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          _buildOperatorBookingActions(booking, isDark),
        ],
      ),
    );
  }

  Widget _buildOperatorBookingActions(
    Map<String, dynamic> booking,
    bool isDark, {
    bool compact = false,
  }) {
    final bookingId = booking['id']?.toString() ?? '';
    final group = bookingStatusGroup(booking['status']);
    final needsDriver = _bookingNeedsDriver(booking['with_driver']);
    final latestAssignment = _latestDriverAssignment(booking);
    final assignmentStatus = latestAssignment?['status']
        ?.toString()
        .trim()
        .toLowerCase();
    final waitingForDriver =
        assignmentStatus == 'pending_offer' || assignmentStatus == 'assigned';
    final driverAccepted =
        assignmentStatus == 'accepted' ||
        assignmentStatus == 'confirmed' ||
        booking['status']?.toString().toLowerCase() == 'driver_accepted';
    final assignedAtRaw = booking['driver_assigned_at'] ??
        latestAssignment?['offered_at'] ??
        latestAssignment?['created_at'];
    final assignedAt = assignedAtRaw != null
        ? DateTime.tryParse(assignedAtRaw.toString())?.toLocal()
        : null;
    final offerRemainingSec = (waitingForDriver && assignedAt != null)
        ? (600 - DateTime.now().difference(assignedAt).inSeconds).clamp(0, 600)
        : 0;
    final isOfferExpired =
        assignmentStatus == 'expired' ||
        (waitingForDriver && (assignedAt == null || offerRemainingSec <= 0));
    final effectiveWaitingForDriver = waitingForDriver && !isOfferExpired;
    final driverDeclined = assignmentStatus == 'rejected' ||
        assignmentStatus == 'declined' ||
        isOfferExpired;

    final isPartner = _isPartnerVehicleBooking(booking);
    final depositRefunded = booking['security_deposit_refunded'] == true;
    final partnerDisbursed = booking['partner_payout_disbursed'] == true ||
        (booking['partner_payout_status']?.toString().toLowerCase() ==
            'disbursed');
    final driverDisbursed = booking['driver_payout_disbursed'] == true ||
        (booking['driver_payout_status']?.toString().toLowerCase() ==
            'disbursed');
    final isChatEligible = BookingService().isEligibleForBookingChat(booking);
    final canTrack = _canTrackBooking(booking);
    final hasExtensionPending =
        booking['extension_status'] == 'pending_operator';

    // ── Actions Architecture: 1 Primary + Quick Icons + Dropdown Menu ────────
    Widget? primaryAction;
    final quickIcons = <Widget>[];
    final menuItems = <_OperatorActionMenuItem>[];

    // Common callbacks
    void viewDetails() => ActionGuard.runGuarded(
          'op_booking_details_$bookingId',
          () async => _showOperatorBookingDetailsDialog(booking),
        );

    void openChat() => ActionGuard.runGuarded(
          'op_chat_booking_$bookingId',
          () async => _openBookingConversation(booking),
        );

    void openTracking() => ActionGuard.runGuarded(
          'op_track_booking_$bookingId',
          () async => _openTrackingForBooking(booking),
        );

    // Quick Icon Helpers
    Widget buildDetailsIcon() => _OperatorAnimatedActionButton(
          onPressed: viewDetails,
          icon: Icons.visibility_rounded,
          foregroundColor: isDark ? Colors.white : _operatorInk,
          borderColor: isDark ? Colors.white24 : Colors.grey.shade400,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade100,
          tooltip: 'View details',
          compact: compact,
          isIconOnly: true,
        );

    Widget buildChatIcon() => _OperatorAnimatedActionButton(
          onPressed: openChat,
          icon: Icons.chat_bubble_outline_rounded,
          foregroundColor: _operatorNavyDeep,
          backgroundColor: _operatorGold,
          tooltip: 'Message customer',
          compact: compact,
          isIconOnly: true,
        );

    Widget buildTrackIcon() => _OperatorAnimatedActionButton(
          onPressed: openTracking,
          icon: Icons.near_me_outlined,
          foregroundColor: const Color(0xFFE5A93C),
          backgroundColor: const Color(0xFFE5A93C).withValues(alpha: 0.15),
          borderColor: const Color(0xFFE5A93C).withValues(alpha: 0.45),
          tooltip: 'Track live GPS location',
          compact: compact,
          isIconOnly: true,
        );

    // ── 1. GROUP LOGIC ──────────────────────────────────────────────────────
    if (group == BookingStatusGroup.pending &&
        !_isPartnerOwnedBooking(booking)) {
      final payState = resolveBookingPaymentState(booking);

      if (payState == BookingPaymentState.paymentReview) {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: () => ActionGuard.runGuarded(
            'op_verify_pay_$bookingId',
            () async => _showVerifyPaymentProofDialog(booking),
          ),
          icon: Icons.verified_user_rounded,
          label: compact ? 'Verify Pay' : 'Verify Payment Proof',
          foregroundColor: Colors.black,
          backgroundColor: const Color(0xFF38BDF8),
          compact: compact,
        );
        menuItems.add(
          _OperatorActionMenuItem(
            icon: Icons.check_circle_outline_rounded,
            label: 'Quick Approve',
            color: Colors.green.shade400,
            onTap: () => ActionGuard.runGuarded(
              'op_approve_booking_$bookingId',
              () async => _handleQuickApproveBooking(
                booking,
                needsDriver: needsDriver,
                driverAccepted: driverAccepted,
              ),
            ),
          ),
        );
      } else if (effectiveWaitingForDriver) {
        final mm = (offerRemainingSec ~/ 60).toString().padLeft(2, '0');
        final ss = (offerRemainingSec % 60).toString().padLeft(2, '0');
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: null,
          icon: Icons.hourglass_top_rounded,
          label: 'Awaiting ($mm:$ss)',
          foregroundColor: Colors.white,
          backgroundColor: Colors.amber.shade800,
          compact: compact,
        );
      } else if (waitingForDriver && isOfferExpired) {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: () => ActionGuard.runGuarded(
            'op_approve_booking_$bookingId',
            () async => _handleQuickApproveBooking(
              booking,
              needsDriver: needsDriver,
              driverAccepted: false,
            ),
          ),
          icon: Icons.person_search_rounded,
          label: compact ? 'Reassign' : 'Reassign Driver',
          foregroundColor: Colors.white,
          backgroundColor: Colors.amber.shade900,
          compact: compact,
        );
      } else if (needsDriver && !driverAccepted) {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: () => ActionGuard.runGuarded(
            'op_approve_booking_$bookingId',
            () async => _handleQuickApproveBooking(
              booking,
              needsDriver: needsDriver,
              driverAccepted: driverAccepted,
            ),
          ),
          icon: Icons.person_search_rounded,
          label: driverDeclined
              ? (compact ? 'Reassign' : 'Select Driver')
              : (compact ? 'Select Driver' : 'Assign Driver'),
          foregroundColor: Colors.white,
          backgroundColor: Colors.green.shade600,
          compact: compact,
        );
      } else {
        final approveLabel =
            payState == BookingPaymentState.pendingConfirmation
                ? (compact ? 'Confirm' : 'Confirm & Approve')
                : 'Approve';
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: () => ActionGuard.runGuarded(
            'op_approve_booking_$bookingId',
            () async => _handleQuickApproveBooking(
              booking,
              needsDriver: needsDriver,
              driverAccepted: driverAccepted,
            ),
          ),
          icon: Icons.check_circle_outline_rounded,
          label: approveLabel,
          foregroundColor: Colors.white,
          backgroundColor: Colors.green.shade600,
          compact: compact,
        );
      }

      // Quick Icons for Pending
      quickIcons.add(buildDetailsIcon());
      if (isChatEligible) {
        quickIcons.add(buildChatIcon());
      }

      // Menu: Reject Booking
      menuItems.add(
        _OperatorActionMenuItem(
          icon: Icons.cancel_outlined,
          label: 'Reject Booking',
          isDestructive: true,
          onTap: () => ActionGuard.runGuarded(
            'op_reject_booking_$bookingId',
            () async => _showRejectDialog(booking['id'].toString()),
          ),
        ),
      );
    } else if (group == BookingStatusGroup.approved ||
        group == BookingStatusGroup.ongoing) {
      if (hasExtensionPending) {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: () => ActionGuard.runGuarded(
            'op_extension_$bookingId',
            () async => _showExtensionApprovalDialog(booking),
          ),
          icon: Icons.update_rounded,
          label: compact ? 'Extension' : 'Review Ext.',
          foregroundColor: Colors.amber.shade300,
          backgroundColor: Colors.amber.shade900.withValues(alpha: 0.35),
          borderColor: Colors.amber.shade400,
          compact: compact,
        );
        if (canTrack) {
          quickIcons.add(buildTrackIcon());
        }
      } else if (canTrack) {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: openTracking,
          icon: Icons.near_me_outlined,
          label: compact ? 'Track' : 'Track GPS',
          foregroundColor: const Color(0xFFE5A93C),
          backgroundColor: const Color(0xFFE5A93C).withValues(alpha: 0.14),
          borderColor: const Color(0xFFE5A93C).withValues(alpha: 0.45),
          compact: compact,
        );
      } else {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: viewDetails,
          icon: Icons.visibility_rounded,
          label: compact ? 'Details' : 'View Details',
          foregroundColor: isDark ? Colors.white : _operatorInk,
          borderColor: isDark ? Colors.white24 : Colors.grey.shade400,
          compact: compact,
        );
      }

      // Quick Icons
      if (hasExtensionPending || canTrack) {
        quickIcons.add(buildDetailsIcon());
      }
      if (isChatEligible) {
        quickIcons.add(buildChatIcon());
      }

      // Menu items
      if (hasExtensionPending && primaryAction != null) {
        menuItems.add(
          _OperatorActionMenuItem(
            icon: Icons.update_rounded,
            label: 'Review Trip Extension',
            color: Colors.amber.shade300,
            onTap: () => ActionGuard.runGuarded(
              'op_extension_$bookingId',
              () async => _showExtensionApprovalDialog(booking),
            ),
          ),
        );
      }
      if (canTrack && hasExtensionPending) {
        menuItems.add(
          _OperatorActionMenuItem(
            icon: Icons.near_me_outlined,
            label: 'Track Live GPS',
            color: const Color(0xFFE5A93C),
            onTap: openTracking,
          ),
        );
      }
      menuItems.add(
        _OperatorActionMenuItem(
          icon: Icons.visibility_rounded,
          label: 'View Booking Details',
          onTap: viewDetails,
        ),
      );
    } else if (group == BookingStatusGroup.completed) {
      // Completed state: Determine primary financial action
      if (!depositRefunded) {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: () => ActionGuard.runGuarded(
            'op_deposit_refund_$bookingId',
            () async => _showSecurityDepositRefundDialog(booking),
          ),
          icon: Icons.assignment_return_rounded,
          label: compact ? 'Refund Dep.' : 'Refund Deposit',
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF10B981),
          compact: compact,
        );
      } else if (isPartner && !partnerDisbursed) {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: () => ActionGuard.runGuarded(
            'op_disburse_partner_$bookingId',
            () async => _showDisbursePartnerPayoutDialog(booking),
          ),
          icon: Icons.payments_outlined,
          label: compact ? 'Partner Pay' : 'Disburse Partner',
          foregroundColor: Colors.white,
          backgroundColor: Colors.purple.shade600,
          compact: compact,
        );
      } else if (needsDriver && !driverDisbursed) {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: () => ActionGuard.runGuarded(
            'op_disburse_driver_$bookingId',
            () async => _showDisburseDriverPayoutDialog(booking),
          ),
          icon: Icons.paid_outlined,
          label: compact ? 'Driver Fee' : 'Disburse Driver',
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF0284C7),
          compact: compact,
        );
      } else {
        // All financial duties fulfilled!
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: viewDetails,
          icon: Icons.visibility_rounded,
          label: compact ? 'Details' : 'View Details',
          foregroundColor: isDark ? Colors.white : _operatorInk,
          borderColor: isDark ? Colors.white24 : Colors.grey.shade400,
          compact: compact,
        );
      }

      // Quick Icons
      if (!depositRefunded ||
          (isPartner && !partnerDisbursed) ||
          (needsDriver && !driverDisbursed)) {
        quickIcons.add(buildDetailsIcon());
      }
      if (isChatEligible) {
        quickIcons.add(buildChatIcon());
      }

      // Menu: Additional active financial actions
      if (isPartner && !partnerDisbursed && !depositRefunded) {
        menuItems.add(
          _OperatorActionMenuItem(
            icon: Icons.payments_outlined,
            label: 'Disburse Partner Earnings',
            color: Colors.purple.shade300,
            onTap: () => ActionGuard.runGuarded(
              'op_disburse_partner_$bookingId',
              () async => _showDisbursePartnerPayoutDialog(booking),
            ),
          ),
        );
      }

      if (needsDriver &&
          !driverDisbursed &&
          (!depositRefunded || (isPartner && !partnerDisbursed))) {
        menuItems.add(
          _OperatorActionMenuItem(
            icon: Icons.paid_outlined,
            label: 'Disburse Driver Fee',
            color: const Color(0xFF38BDF8),
            onTap: () => ActionGuard.runGuarded(
              'op_disburse_driver_$bookingId',
              () async => _showDisburseDriverPayoutDialog(booking),
            ),
          ),
        );
      }

      // Menu: Receipts
      if (depositRefunded) {
        menuItems.add(
          _OperatorActionMenuItem(
            icon: Icons.receipt_long_rounded,
            label: 'Deposit Refund Receipt',
            color: const Color(0xFF10B981),
            onTap: () => ActionGuard.runGuarded(
              'op_deposit_refund_view_$bookingId',
              () async => _showSecurityDepositRefundDialog(booking),
            ),
          ),
        );
      }

      if (isPartner && partnerDisbursed) {
        final r = booking['partner_payout_receipt_url']?.toString();
        if (r != null && r.isNotEmpty) {
          menuItems.add(
            _OperatorActionMenuItem(
              icon: Icons.receipt_long_rounded,
              label: 'Partner Payout Receipt',
              color: Colors.purpleAccent,
              onTap: () => _showReceiptProofDialog(r, isDark),
            ),
          );
        }
      }

      if (needsDriver && driverDisbursed) {
        final r = booking['driver_payout_receipt_url']?.toString();
        if (r != null && r.isNotEmpty) {
          menuItems.add(
            _OperatorActionMenuItem(
              icon: Icons.receipt_long_rounded,
              label: 'Driver Fee Receipt',
              color: const Color(0xFF38BDF8),
              onTap: () => _showReceiptProofDialog(r, isDark),
            ),
          );
        }
      }

      menuItems.add(
        _OperatorActionMenuItem(
          icon: Icons.visibility_rounded,
          label: 'View Full Details',
          onTap: viewDetails,
        ),
      );
    } else {
      // Cancelled / Rejected: Check if booking refund is needed
      final payState = resolveBookingPaymentState(booking);
      final refundNeeded = payState == BookingPaymentState.refundRequired ||
          booking['refund_status'] == 'refund_needed' ||
          booking['refund_status'] == 'refund_required' ||
          booking['refund_required'] == true;
      final refundComplete = payState == BookingPaymentState.refunded ||
          booking['refund_status'] == 'refunded' ||
          booking['refund_completed'] == true;

      if (refundNeeded && !refundComplete) {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: () => ActionGuard.runGuarded(
            'op_booking_refund_$bookingId',
            () async => _showBookingRefundDialog(booking),
          ),
          icon: Icons.currency_exchange_rounded,
          label: compact ? 'Refund' : 'Process Refund',
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFFEF4444),
          compact: compact,
        );
        quickIcons.add(buildDetailsIcon());
      } else {
        primaryAction = _buildOperatorBookingActionButton(
          onPressed: viewDetails,
          icon: Icons.visibility_rounded,
          label: compact ? 'Details' : 'View Details',
          foregroundColor: isDark ? Colors.white : _operatorInk,
          borderColor: isDark ? Colors.white24 : Colors.grey.shade400,
          compact: compact,
        );
      }

      if (isChatEligible) {
        quickIcons.add(buildChatIcon());
      }

      if (refundComplete) {
        menuItems.add(
          _OperatorActionMenuItem(
            icon: Icons.receipt_long_rounded,
            label: 'View Refund Proof',
            color: const Color(0xFFA855F7),
            onTap: () => ActionGuard.runGuarded(
              'op_booking_refund_view_$bookingId',
              () async => _showBookingRefundDialog(booking),
            ),
          ),
        );
      }

      if (booking['security_deposit_paid'] == true && !depositRefunded) {
        menuItems.add(
          _OperatorActionMenuItem(
            icon: Icons.assignment_return_rounded,
            label: 'Refund Security Deposit',
            color: const Color(0xFF10B981),
            onTap: () => ActionGuard.runGuarded(
              'op_deposit_refund_$bookingId',
              () async => _showSecurityDepositRefundDialog(booking),
            ),
          ),
        );
      }

      menuItems.add(
        _OperatorActionMenuItem(
          icon: Icons.visibility_rounded,
          label: 'View Booking Details',
          onTap: viewDetails,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (primaryAction != null) ...[
          primaryAction,
          const SizedBox(width: 5),
        ],
        for (final iconBtn in quickIcons) ...[
          iconBtn,
          const SizedBox(width: 4),
        ],
        if (menuItems.isNotEmpty)
          _buildMoreActionsMenu(menuItems, isDark, compact: compact),
      ],
    );
  }

  Widget _buildMoreActionsMenu(
    List<_OperatorActionMenuItem> items,
    bool isDark, {
    bool compact = true,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
        ),
      ),
      child: PopupMenuButton<_OperatorActionMenuItem>(
        tooltip: 'More actions',
        offset: const Offset(0, 36),
        elevation: 12,
        onSelected: (item) => item.onTap(),
        itemBuilder: (context) => items.map((item) {
          final itemColor = item.isDestructive
              ? Colors.red.shade400
              : (item.color ??
                  (isDark ? Colors.grey.shade200 : _operatorInk));
          return PopupMenuItem<_OperatorActionMenuItem>(
            value: item,
            height: 38,
            child: Row(
              children: [
                Icon(item.icon, size: 16, color: itemColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: itemColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        child: _OperatorAnimatedActionButton(
          onPressed: null,
          icon: Icons.more_horiz_rounded,
          foregroundColor: isDark ? Colors.white70 : _operatorInk,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.shade100,
          borderColor: isDark ? Colors.white24 : Colors.grey.shade300,
          tooltip: 'More actions',
          compact: compact,
          isIconOnly: true,
          isMenuTrigger: true,
        ),
      ),
    );
  }

  Widget _buildOperatorBookingActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color foregroundColor,
    Color? backgroundColor,
    Color? borderColor,
    required bool compact,
    bool isIconOnly = false,
  }) {
    final actionDescription = switch (label.toLowerCase()) {
      'details' || 'view details' =>
        'View full booking details and customer info',
      'approve' => 'Approve this reservation and confirm booking',
      _ when label.toLowerCase().startsWith('awaiting') =>
        'Awaiting driver acceptance (10-minute offer countdown)',
      _ when label.toLowerCase().contains('assign') ||
          label.toLowerCase().contains('reassign') =>
        'Click to assign/reassign driver for this trip',
      'extension' || 'review ext.' || 'review extension' =>
        'Review and approve trip extension request',
      'reject' => 'Decline or cancel this booking request',
      'message' => 'Chat directly with customer',
      'track' || 'track gps' => 'Track live GPS location on map',
      'refund dep.' || 'refund deposit' =>
        'Refund security deposit to renter via proof of transfer',
      _ when label.toLowerCase().contains('refunded') =>
        'Security deposit already refunded. Click to view transfer proof receipt.',
      'partner pay' || 'disburse partner' =>
        'Disburse net earnings to vehicle partner',
      _ when label.toLowerCase().contains('partner paid') =>
        'Partner payout already disbursed. Click to view transfer proof receipt.',
      'driver fee' || 'disburse driver' => 'Disburse trip driver fee',
      _ when label.toLowerCase().contains('driver paid') =>
        'Driver fee already disbursed. Click to view transfer proof receipt.',
      _ => label,
    };

    return _OperatorAnimatedActionButton(
      onPressed: onPressed,
      icon: icon,
      label: label,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      tooltip: actionDescription,
      compact: compact,
      isIconOnly: isIconOnly,
    );
  }

  Future<void> _handleQuickApproveBooking(
    Map<String, dynamic> booking, {
    required bool needsDriver,
    required bool driverAccepted,
  }) async {
    if (needsDriver && !driverAccepted) {
      _showApproveDialog(booking);
      return;
    }

    final approvalData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _OperatorBookingApprovalDialog(
        booking: booking,
        state: this,
      ),
    );
    if (approvalData != null && mounted) {
      await _approveBooking(
        booking,
        dailyDestinationSurcharge: approvalData['daily_destination_surcharge'] as double?,
        destinationFee: approvalData['destination_fee'] as double?,
        destinationFeeNotes: approvalData['destination_fee_notes'] as String?,
        updatedTotalPrice: approvalData['updated_total_price'] as double?,
        updatedRentalSubtotal: approvalData['updated_rental_subtotal'] as double?,
        updatedPrincipalTotalPrice: approvalData['updated_principal_total_price'] as double?,
      );
    }
  }

  Future<void> _showOperatorBookingDetailsDialog(
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    return ActionGuard.runGuarded('booking_details_dialog_$bookingId', () async {
      final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final driver = booking['driver'] as Map<String, dynamic>?;
    Map<String, dynamic>? effectiveDriverUser = (driver?['user'] ??
            driver?['users'] ??
            booking['driver_user'] ??
            booking['driver_profile'])
        as Map<String, dynamic>?;
    final driverId = booking['driver_id']?.toString().trim();
    if (effectiveDriverUser == null && driverId != null && driverId.isNotEmpty) {
      try {
        final dRes = await _supabase
            .from('drivers')
            .select(
                'id, user_id, user:users!drivers_user_id_fkey(id, full_name, email, phone, avatar_url)')
            .eq('id', driverId)
            .maybeSingle();
        if (dRes != null && dRes['user'] != null) {
          effectiveDriverUser = dRes['user'] as Map<String, dynamic>?;
        } else {
          final uRes = await _supabase
              .from('users')
              .select(
                  'id, full_name, email, phone, avatar_url')
              .eq('id', driverId)
              .maybeSingle();
          if (uRes != null) {
            effectiveDriverUser = uRes;
          }
        }
      } catch (e) {
        debugPrint('[BookingDetails] Error fetching driver user fallback: $e');
      }
    }

    final isPartnerOwned = _isPartnerOwnedBooking(booking);
    Map<String, dynamic>? effectivePartnerUser;
    String? partnerBusinessName;
    final vehicleOwner = vehicle['owner'] as Map<String, dynamic>?;
    if (vehicleOwner != null) {
      effectivePartnerUser = vehicleOwner;
    }
    final partnerVehicle = booking['partner_vehicles'] as Map<String, dynamic>?;
    final partnersMap = partnerVehicle?['partners'] as Map<String, dynamic>? ??
        vehicle['partners'] as Map<String, dynamic>? ??
        booking['partner'] as Map<String, dynamic>?;
    if (partnersMap != null) {
      partnerBusinessName = partnersMap['business_name']?.toString();
      final pUser = (partnersMap['users'] ?? partnersMap['user'])
          as Map<String, dynamic>?;
      if (pUser != null) {
        effectivePartnerUser = pUser;
      }
    }
    final partnerId =
        booking['partner_id'] ?? vehicle['partner_id'] ?? vehicle['owner_id'];
    if (isPartnerOwned &&
        effectivePartnerUser == null &&
        partnerId != null &&
        partnerId.toString().isNotEmpty) {
      try {
        final uRes = await _supabase
            .from('users')
            .select(
                'id, full_name, email, phone, avatar_url, role')
            .eq('id', partnerId.toString())
            .maybeSingle();
        if (uRes != null) {
          effectivePartnerUser = uRes;
        } else {
          final pRes = await _supabase
              .from('partners')
              .select(
                  'id, business_name, business_phone, user:users(id, full_name, email, phone, avatar_url)')
              .eq('id', partnerId.toString())
              .maybeSingle();
          if (pRes != null) {
            partnerBusinessName = pRes['business_name']?.toString();
            effectivePartnerUser = pRes['user'] as Map<String, dynamic>?;
          }
        }
      } catch (e) {
        debugPrint('[BookingDetails] Error fetching partner user fallback: $e');
      }
    }

    final status = booking['status']?.toString() ?? 'pending';
    final statusLower = status.toLowerCase();
    final group = bookingStatusGroup(status);
    final needsDriver = _bookingNeedsDriver(booking['with_driver']);
    final assignmentStatus = _latestDriverAssignment(
      booking,
    )?['status']?.toString().trim().toLowerCase();
    final waitingForDriver =
        assignmentStatus == 'pending_offer' || assignmentStatus == 'assigned';
    final driverAccepted =
        assignmentStatus == 'accepted' ||
        assignmentStatus == 'confirmed' ||
        statusLower == 'driver_accepted';
    final driverDeclined = assignmentStatus == 'rejected' ||
        assignmentStatus == 'declined' ||
        assignmentStatus == 'expired';
    final completionState = BookingService().getTripCompletionState(booking);
    final completionStage = completionState['completionStage']?.toString();
    final start = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );
    final end = DateTime.tryParse(
      (booking['end_at'] ?? booking['end_date'])?.toString() ?? '',
    );
    final total =
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final imageUrl = _primaryVehicleImageUrl(vehicle);
    final bookingId = booking['id']?.toString() ?? '';
    final shortId = bookingId.length > 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 780),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172235) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      final vehiclePanel = _buildOperatorVehicleDetailPanel(
                        vehicle: vehicle,
                        renter: renter,
                        driverUser: effectiveDriverUser,
                        needsDriver: needsDriver,
                        driverAccepted: driverAccepted,
                        driverDeclined: driverDeclined,
                        waitingForDriver: waitingForDriver,
                        partnerUser: effectivePartnerUser,
                        partnerBusinessName: partnerBusinessName,
                        isPartnerOwned: isPartnerOwned,
                        imageUrl: imageUrl,
                        isDark: isDark,
                        scrollable: !compact,
                      );
                      final detailPanel = _buildOperatorBookingDetailPanel(
                        booking: booking,
                        bookingShortId: shortId,
                        driverName:
                            effectiveDriverUser?['full_name']?.toString() ??
                            (needsDriver ? 'Unassigned' : 'Self-drive'),
                        start: start,
                        end: end,
                        total: total,
                        status: status,
                        isDark: isDark,
                        onClose: () => Navigator.pop(dialogContext),
                        scrollable: !compact,
                      );
                      if (compact) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(children: [vehiclePanel, detailPanel]),
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 320, child: vehiclePanel),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                          Expanded(child: detailPanel),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.12)
                        : const Color(0xFFF8F9FA),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (_isPartnerOwnedBooking(booking))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.purple.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.handshake_outlined,
                                size: 16,
                                color: Colors.purpleAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Partner Unit • View Only Mode',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.purple[200]
                                      : Colors.purple[800],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (group == BookingStatusGroup.pending &&
                          !_isPartnerOwnedBooking(booking))
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showRejectDialog(bookingId);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const Text('Decline'),
                        ),
                      if (group == BookingStatusGroup.pending &&
                          (!needsDriver || driverAccepted) &&
                          !_isPartnerOwnedBooking(booking))
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _approveBooking(booking);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorGold,
                            foregroundColor: _operatorNavyDeep,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 17),
                          label: const Text('Finalize Booking'),
                        ),
                      if (group == BookingStatusGroup.pending &&
                          needsDriver &&
                          !driverAccepted &&
                          !waitingForDriver &&
                          !_isPartnerOwnedBooking(booking))
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showApproveDialog(booking);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorNavy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: const Icon(Icons.person_search, size: 17),
                          label: Text(
                            driverDeclined
                                ? 'Select Another Driver'
                                : 'Assign Driver',
                          ),
                        ),
                      if ((statusLower == 'confirmed' ||
                              statusLower == 'approved' ||
                              group == BookingStatusGroup.approved) &&
                          !_isPartnerOwnedBooking(booking))
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _openOperatorInspectionRecordOrForm(
                              booking,
                              inspectionType: 'before',
                              allowCreate: true,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(Icons.fact_check_outlined, size: 17),
                          label: const Text(
                            'Pre-Checklist & Inspection',
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      if (statusLower == 'active' ||
                          statusLower == 'ongoing' ||
                          statusLower == 'return_pending_inspection' ||
                          group == BookingStatusGroup.ongoing)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _openOperatorInspectionRecordOrForm(
                              booking,
                              inspectionType: 'before',
                              allowCreate: false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 17),
                          label: const Text('View Pre-Trip Checklist'),
                        ),
                      if ((statusLower == 'active' ||
                              statusLower == 'ongoing' ||
                              statusLower == 'return_pending_inspection' ||
                              group == BookingStatusGroup.ongoing ||
                              booking['returned_at'] != null ||
                              booking['returnedAt'] != null) &&
                          statusLower != 'completed' &&
                          group != BookingStatusGroup.completed &&
                          !_isPartnerOwnedBooking(booking))
                        ElevatedButton.icon(
                          onPressed:
                              (statusLower == 'return_pending_inspection' ||
                                  booking['returned_at'] != null ||
                                  booking['returnedAt'] != null)
                              ? () {
                                  Navigator.pop(dialogContext);
                                  _showInspectionDialog(
                                    booking,
                                    inspectionType: 'after',
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (statusLower == 'return_pending_inspection' ||
                                    booking['returned_at'] != null ||
                                    booking['returnedAt'] != null)
                                ? _operatorGold
                                : Colors.grey.shade800,
                            foregroundColor:
                                (statusLower == 'return_pending_inspection' ||
                                    booking['returned_at'] != null ||
                                    booking['returnedAt'] != null)
                                ? _operatorNavyDeep
                                : Colors.grey.shade500,
                            disabledBackgroundColor: Colors.grey.shade800,
                            disabledForegroundColor: Colors.grey.shade500,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: Icon(
                            (statusLower == 'return_pending_inspection' ||
                                    booking['returned_at'] != null ||
                                    booking['returnedAt'] != null)
                                ? Icons.check_circle_outline_rounded
                                : Icons.lock_clock_outlined,
                            size: 17,
                          ),
                          label: Text(
                            (statusLower == 'return_pending_inspection' ||
                                    booking['returned_at'] != null ||
                                    booking['returnedAt'] != null)
                                ? 'Confirm Return Inspection'
                                : 'Confirm Return (Awaiting Renter)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),

                      if (statusLower == 'approved' ||
                          statusLower == 'confirmed' ||
                          statusLower == 'active' ||
                          statusLower == 'ongoing' ||
                          statusLower == 'return_pending_inspection' ||
                          group == BookingStatusGroup.approved ||
                          group == BookingStatusGroup.ongoing)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _openBookingConversation(booking);
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 17,
                          ),
                          label: const Text('Message'),
                        ),
                      if (statusLower == 'active' ||
                          statusLower == 'ongoing' ||
                          statusLower == 'return_pending_inspection' ||
                          group == BookingStatusGroup.ongoing)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _openTrackingForBooking(booking);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorNavy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: const Icon(Icons.explore_outlined, size: 17),
                          label: const Text('Track Trip'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await BookingReceiptService.shareReceipt(booking);
                          } catch (error) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not download receipt: $error',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: const Text('Receipt'),
                      ),
                      if (completionStage == 'awaiting_payment' &&
                          !_isPartnerOwnedBooking(booking))
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _confirmOperatorFinalPayment(booking);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _operatorNavy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: const Icon(Icons.payments_outlined, size: 17),
                          label: const Text('Confirm Full Payment'),
                        ),
                      if (booking['extension_status'] == 'pending_operator' &&
                          !_isPartnerOwnedBooking(booking))
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showExtensionApprovalDialog(booking);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD740),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          icon: const Icon(Icons.update_rounded, size: 17),
                          label: const Text(
                            'Review Extension',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      if ((statusLower == 'active' ||
                              statusLower == 'ongoing' ||
                              statusLower == 'return_pending_inspection' ||
                              statusLower == 'awaiting_completion' ||
                              statusLower == 'completed' ||
                              group == BookingStatusGroup.ongoing ||
                              group == BookingStatusGroup.completed) &&
                          !_isPartnerOwnedBooking(booking)) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            final bId = booking['id']?.toString() ?? '';
                            if (bId.isNotEmpty) {
                              TripRouteHistoryDialog.show(
                                context: context,
                                bookingId: bId,
                                vehicleName: booking['vehicles']?['brand'] != null
                                    ? '${booking['vehicles']['brand']} ${booking['vehicles']['model'] ?? ''}'
                                    : null,
                                plateNumber: booking['vehicles']?['plate_number']?.toString(),
                                renterName: booking['renter']?['full_name']?.toString(),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _operatorGold,
                            side: BorderSide(
                              color: _operatorGold.withValues(alpha: 0.8),
                              width: 1.5,
                            ),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.route_rounded, size: 17),
                          label: const Text(
                            'Audit Route Playback',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (booking['security_deposit_refunded'] != true)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _showSecurityDepositRefundDialog(booking);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            icon: const Icon(Icons.assignment_return_rounded, size: 17),
                            label: const Text(
                              'Return Security Deposit',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (booking['security_deposit_refunded'] == true)
                          OutlinedButton.icon(
                            onPressed: () {
                              _showSecurityDepositRefundDialog(booking);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 17),
                            label: const Text('Deposit Refunded'),
                          ),
                        if (_isPartnerVehicleBooking(booking)) ...[
                          if (booking['partner_payout_disbursed'] == true ||
                              (booking['partner_payout_status']?.toString().toLowerCase() == 'disbursed')) ...[
                            Builder(
                              builder: (context) {
                                final receiptUrl = booking['partner_payout_receipt_url']?.toString();
                                final hasReceipt = receiptUrl != null && receiptUrl.isNotEmpty;
                                return OutlinedButton.icon(
                                  onPressed: hasReceipt
                                      ? () => _showReceiptProofDialog(receiptUrl, isDark)
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.purpleAccent,
                                    disabledForegroundColor: isDark ? Colors.purple.shade300 : Colors.purple.shade700,
                                    side: BorderSide(
                                      color: Colors.purpleAccent.withValues(alpha: hasReceipt ? 1.0 : 0.5),
                                    ),
                                    minimumSize: const Size(0, 44),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded, size: 17),
                                  label: Text(hasReceipt ? 'Partner Disbursed ✓ (View)' : 'Partner Disbursed ✓'),
                                );
                              },
                            ),
                          ]
                          else if (statusLower == 'completed' ||
                              statusLower == 'awaiting_completion' ||
                              group == BookingStatusGroup.completed)
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _showDisbursePartnerPayoutDialog(booking);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade600,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                              ),
                              icon: const Icon(Icons.payments_outlined, size: 17),
                              label: const Text(
                                'Disburse Partner Payout',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                        if (_bookingNeedsDriver(booking['with_driver'])) ...[
                          if (booking['driver_payout_disbursed'] == true ||
                              (booking['driver_payout_status']?.toString().toLowerCase() == 'disbursed')) ...[
                            Builder(
                              builder: (context) {
                                final receiptUrl = booking['driver_payout_receipt_url']?.toString();
                                final hasReceipt = receiptUrl != null && receiptUrl.isNotEmpty;
                                return OutlinedButton.icon(
                                  onPressed: hasReceipt
                                      ? () => _showReceiptProofDialog(receiptUrl, isDark)
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF38BDF8),
                                    disabledForegroundColor: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
                                    side: BorderSide(
                                      color: const Color(0xFF38BDF8).withValues(alpha: hasReceipt ? 1.0 : 0.5),
                                    ),
                                    minimumSize: const Size(0, 44),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded, size: 17),
                                  label: Text(hasReceipt ? 'Driver Fee Disbursed ✓ (View)' : 'Driver Fee Disbursed ✓'),
                                );
                              },
                            ),
                          ]
                          else if (statusLower == 'completed' ||
                              statusLower == 'awaiting_completion' ||
                              group == BookingStatusGroup.completed)
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _showDisburseDriverPayoutDialog(booking);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                              ),
                              icon: const Icon(Icons.paid_outlined, size: 17),
                              label: const Text(
                                'Disburse Driver Fee',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                        if (_isOperatorRatingFullyCompleted(booking))
                          Tooltip(
                            message: 'Rating is complete',
                            child: ElevatedButton.icon(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                                foregroundColor: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                              ),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 17,
                              ),
                              label: const Text('Rating Complete'),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _openOperatorRenterRating(booking);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _operatorNavy,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            ),
                            icon: const Icon(Icons.star_rate_rounded, size: 17),
                            label: const Text('Rate Trip'),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    });
  }

  Future<void> _showExtensionApprovalDialog(Map<String, dynamic> booking) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookingId = booking['id']?.toString() ?? '';
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final currentEndRaw = (booking['end_at'] ?? booking['end_date'])?.toString();
    final requestedEndRaw = booking['extension_requested_end_at']?.toString();
    final additionalPrice = (booking['extension_additional_price'] as num?)?.toDouble() ?? 0.0;
    final extensionDays = (booking['extension_days'] as num?)?.toInt() ?? 1;

    final currentEnd = DateTime.tryParse(currentEndRaw ?? '');
    final requestedEnd = DateTime.tryParse(requestedEndRaw ?? '');

    final renterName = renter['full_name']?.toString().trim().isNotEmpty == true
        ? renter['full_name'].toString().trim()
        : (renter['email']?.toString().trim().isNotEmpty == true
            ? renter['email'].toString().trim()
            : 'Renter');
    final vehicleBrand = vehicle['brand']?.toString().trim() ?? '';
    final vehicleModel = vehicle['model']?.toString().trim() ?? '';
    final vehicleTitle = '$vehicleBrand $vehicleModel'.trim().isNotEmpty
        ? '$vehicleBrand $vehicleModel'.trim()
        : 'Vehicle';

    bool isProcessing = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade200,
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD740).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.update_rounded,
                      color: Color(0xFFFFD740),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Trip Extension Request',
                    style: TextStyle(
                      color: isDark ? Colors.white : _operatorInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Renter $renterName has requested to extend their rental period for $vehicleTitle.',
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Current Return Date:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                currentEnd != null
                                    ? _formatBookingDateTime(currentEnd)
                                    : 'N/A',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : _operatorInk,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Requested Return Date:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                requestedEnd != null
                                    ? _formatBookingDateTime(requestedEnd)
                                    : 'N/A',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Extension Duration:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '+$extensionDays day${extensionDays == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : _operatorInk,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Additional Amount Due:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : _operatorInk,
                                ),
                              ),
                              Text(
                                '+PHP ${additionalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            final operatorId =
                                Supabase.instance.client.auth.currentUser?.id ?? '';
                            await BookingService().rejectTripExtension(
                              bookingId: bookingId,
                              operatorId: operatorId,
                            );
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Trip extension request was declined.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              _loadDashboardData();
                            }
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            _showErrorSnackBar('Error declining extension: $e');
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Decline Request'),
                ),
                FilledButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            final operatorId =
                                Supabase.instance.client.auth.currentUser?.id ?? '';
                            await BookingService().approveTripExtension(
                              bookingId: bookingId,
                              operatorId: operatorId,
                            );
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Trip extension approved successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadDashboardData();
                            }
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            _showErrorSnackBar('Error approving extension: $e');
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD740),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Approve Extension',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOperatorVehicleDetailPanel({
    required Map<String, dynamic> vehicle,
    required Map<String, dynamic> renter,
    Map<String, dynamic>? driverUser,
    bool needsDriver = false,
    bool driverAccepted = false,
    bool driverDeclined = false,
    bool waitingForDriver = false,
    Map<String, dynamic>? partnerUser,
    String? partnerBusinessName,
    bool isPartnerOwned = false,
    required String imageUrl,
    required bool isDark,
    bool scrollable = true,
  }) {
    final foreground = isDark ? Colors.white : _operatorInk;
    final muted = isDark ? Colors.grey[400] : Colors.grey.shade600;
    final panelContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 178,
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              child: imageUrl.isEmpty
                  ? Icon(Icons.directions_car_outlined, color: muted, size: 52)
                  : OptimizedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: Icon(
                        Icons.directions_car_outlined,
                        color: muted,
                        size: 52,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _vehicleTitle(vehicle),
            style: TextStyle(
              color: foreground,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            [
                  vehicle['transmission'],
                  vehicle['vehicle_type'] ?? vehicle['category'],
                  vehicle['plate_number'],
                ]
                .where((value) => value?.toString().trim().isNotEmpty == true)
                .join(' - '),
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 22),
          Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            'RENTER',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _operatorGold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child:
                    (renter['avatar_url'] ?? renter['profile_picture_url'])
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true
                    ? OptimizedNetworkImage(
                        imageUrl:
                            (renter['avatar_url'] ??
                                    renter['profile_picture_url'])
                                .toString(),
                        fit: BoxFit.cover,
                        errorWidget: Icon(
                          Icons.person_outline_rounded,
                          color: _operatorGold,
                        ),
                      )
                    : Icon(Icons.person_outline_rounded, color: _operatorGold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      renter['full_name']?.toString() ?? 'Unknown renter',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      renter['email']?.toString() ?? 'No email provided',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                    if (renter['phone']?.toString().trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 4),
                      Text(
                        renter['phone'].toString(),
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (needsDriver || driverUser != null) ...[
            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'DRIVER ASSIGNED',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (driverAccepted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle_rounded,
                            size: 11, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Accepted',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (driverDeclined)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Declined',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else if (waitingForDriver)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Offer Pending',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: driverAccepted
                        ? Colors.green.withOpacity(0.18)
                        : Colors.blue.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: (driverUser?['avatar_url'] ??
                              driverUser?['profile_picture_url'])
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true
                      ? OptimizedNetworkImage(
                          imageUrl: (driverUser?['avatar_url'] ??
                                  driverUser?['profile_picture_url'])
                              .toString(),
                          fit: BoxFit.cover,
                          errorWidget: Icon(
                            Icons.drive_eta_rounded,
                            color: driverAccepted
                                ? Colors.green
                                : Colors.blue,
                          ),
                        )
                      : Icon(
                          Icons.drive_eta_rounded,
                          color: driverAccepted
                              ? Colors.green
                              : Colors.blue,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverUser?['full_name']?.toString() ??
                            'Awaiting Driver Assignment',
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        driverUser?['email']?.toString() ??
                            (driverUser != null ? 'No email' : 'Offer dispatched'),
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                      if (driverUser?['phone']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 4),
                        Text(
                          driverUser!['phone'].toString(),
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (isPartnerOwned ||
              partnerUser != null ||
              partnerBusinessName != null) ...[
            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'PARTNER / HOST',
              style: TextStyle(
                color: muted,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: (partnerUser?['avatar_url'] ??
                              partnerUser?['profile_picture_url'])
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true
                      ? OptimizedNetworkImage(
                          imageUrl: (partnerUser?['avatar_url'] ??
                                  partnerUser?['profile_picture_url'])
                              .toString(),
                          fit: BoxFit.cover,
                          errorWidget: const Icon(
                            Icons.store_rounded,
                            color: Colors.purple,
                          ),
                        )
                      : const Icon(
                          Icons.store_rounded,
                          color: Colors.purple,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partnerBusinessName?.trim().isNotEmpty == true
                            ? partnerBusinessName!
                            : (partnerUser?['full_name']?.toString() ??
                                'Mobilis Fleet Partner'),
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        partnerUser?['email']?.toString() ??
                            'Partner Managed Vehicle',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                      if (partnerUser?['phone']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 4),
                        Text(
                          partnerUser!['phone'].toString(),
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      );

    if (scrollable) {
      return Container(
        color: isDark ? Colors.black.withOpacity(0.14) : const Color(0xFFF2F4F6),
        child: Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            child: panelContent,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      color: isDark ? Colors.black.withOpacity(0.14) : const Color(0xFFF2F4F6),
      child: panelContent,
    );
  }

  Widget _buildOperatorBookingDetailPanel({
    required Map<String, dynamic> booking,
    required String bookingShortId,
    required String driverName,
    required DateTime? start,
    required DateTime? end,
    required double total,
    required String status,
    required bool isDark,
    required VoidCallback onClose,
    bool scrollable = true,
  }) {
    final foreground = isDark ? Colors.white : _operatorInk;
    final muted = isDark ? Colors.grey[400] : Colors.grey.shade600;
    final pickup = _operatorPickupLabel(booking['pickup_location']?.toString());
    final destination = booking['dropoff_location']?.toString().trim() ?? '';
    final route = pickup.isNotEmpty && destination.isNotEmpty
        ? '$pickup to $destination'
        : destination.isNotEmpty
        ? destination
        : pickup;
    final needsDriver = _bookingNeedsDriver(booking['with_driver']);
    final statusLower = status.trim().toLowerCase();
    final group = bookingStatusGroup(status);
    final service = needsDriver
        ? driverName == 'Unassigned'
              ? 'Professional driver required'
              : 'Professional driver - $driverName'
        : 'Self-drive';
    final detailContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOOKING ID  #$bookingShortId',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Booking Details',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusBadge(status),
                  const SizedBox(height: 7),
                  Text(
                    'PHP ${_formatCurrency(total)}',
                    style: TextStyle(
                      color: _operatorGold,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Close booking details',
                onPressed: onClose,
                style: IconButton.styleFrom(
                  foregroundColor: foreground,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.grey.shade100,
                  minimumSize: const Size(42, 42),
                ),
                icon: const Icon(Icons.close_rounded, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildOperatorDetailTile(
                Icons.map_outlined,
                'ROUTE',
                route,
                isDark,
                onTap: () => _showBookingRouteDialog(booking, isDark),
              ),
              _buildOperatorDetailTile(
                Icons.calendar_month_outlined,
                'SCHEDULE',
                '${_formatBookingDateTime(start)} - ${_formatBookingDateTime(end)}',
                isDark,
              ),
              _buildOperatorDetailTile(
                Icons.airport_shuttle_outlined,
                'SERVICE',
                service,
                isDark,
              ),
            ],
          ),
          if (UpcomingReleaseCountdownBadge.isWithin24Hours(booking)) ...[
            const SizedBox(height: 14),
            UpcomingReleaseCountdownBadge(booking: booking, isDark: isDark),
          ],
          if (_isOngoingBooking(booking)) ...[
            const SizedBox(height: 14),
            BookingReturnCountdown(booking: booking, lightBackground: !isDark),
          ],
          if ((statusLower == 'active' ||
                  statusLower == 'ongoing' ||
                  statusLower == 'return_pending_inspection' ||
                  statusLower == 'awaiting_completion' ||
                  statusLower == 'completed' ||
                  group == BookingStatusGroup.ongoing ||
                  group == BookingStatusGroup.completed) &&
              !_isPartnerOwnedBooking(booking)) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _operatorNavy,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _operatorGold.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _operatorGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.play_circle_fill_rounded, color: _operatorGold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trip Route History & GPS Playback',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Audit vehicle GPS breadcrumb trail, playback route simulation, and check destination deviations.',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final bId = booking['id']?.toString() ?? '';
                      if (bId.isNotEmpty) {
                        TripRouteHistoryDialog.show(
                          context: context,
                          bookingId: bId,
                          vehicleName: booking['vehicles']?['brand'] != null
                              ? '${booking['vehicles']['brand']} ${booking['vehicles']['model'] ?? ''}'
                              : null,
                          plateNumber: booking['vehicles']?['plate_number']?.toString(),
                          renterName: booking['renter']?['full_name']?.toString(),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _operatorGold,
                      foregroundColor: _operatorNavyDeep,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.route_rounded, size: 16),
                    label: const Text(
                      'Audit Route Playback',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          _buildBookingPaymentDetails(booking, isDark),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _operatorNavy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: _operatorGold, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'Renter Safety Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildOperatorSafetyLine(
                  'Digital signature',
                  booking['renter_signature_url']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? 'Captured'
                      : 'Not provided',
                ),
                _buildOperatorSafetyLine(
                  'Emergency contact',
                  booking['emergency_contact_name']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? booking['emergency_contact_name'].toString()
                      : 'Not provided',
                ),
                _buildOperatorSafetyLine(
                  'Contact phone',
                  booking['emergency_contact_phone']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? booking['emergency_contact_phone'].toString()
                      : 'Not provided',
                ),
                _buildOperatorSafetyLine(
                  'Co-traveler',
                  booking['co_traveler_name']?.toString().trim().isNotEmpty ==
                          true
                      ? booking['co_traveler_name'].toString()
                      : 'Not provided',
                ),
                _buildOperatorSafetyLine(
                  'Co-traveler license',
                  booking['co_traveler_license']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? booking['co_traveler_license'].toString()
                      : 'Not provided',
                ),
                _buildOperatorSafetyLine(
                  'Co-traveler signature',
                  booking['co_traveler_signature_url']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? 'Captured'
                      : 'Not provided',
                ),
                Divider(color: Colors.white.withOpacity(0.12), height: 22),
                const Text(
                  'VERIFICATION EVIDENCE',
                  style: TextStyle(
                    color: Color(0xFF91A9BE),
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildOperatorEvidenceChip(
                      Icons.draw_outlined,
                      'Signature',
                      booking['renter_signature_url'],
                    ),
                    _buildOperatorEvidenceChip(
                      Icons.badge_outlined,
                      'Valid ID',
                      booking['renter_valid_id_url'],
                    ),
                    _buildOperatorEvidenceChip(
                      Icons.camera_alt_outlined,
                      'Selfie',
                      booking['renter_selfie_url'],
                    ),
                    _buildOperatorEvidenceChip(
                      Icons.draw_outlined,
                      'Co-traveler Signature',
                      booking['co_traveler_signature_url'],
                    ),
                    _buildOperatorEvidenceChip(
                      Icons.badge_outlined,
                      'Co-traveler ID',
                      booking['co_traveler_valid_id_url'],
                    ),
                    _buildOperatorEvidenceChip(
                      Icons.camera_alt_outlined,
                      'Co-traveler Selfie',
                      booking['co_traveler_selfie_url'],
                    ),
                  ],
                ),
                Divider(color: Colors.white.withOpacity(0.12), height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FINAL PAYMENT & PENALTY BREAKDOWN',
                      style: TextStyle(
                        color: Color(0xFF91A9BE),
                        fontSize: 9,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (booking['final_payment_status'] == 'paid' ||
                        status.trim().toLowerCase() == 'completed')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.5),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.greenAccent,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Payment Verified',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                () {
                  final vehicle = booking['vehicles'] is Map<String, dynamic>
                      ? Map<String, dynamic>.from(booking['vehicles'])
                      : <String, dynamic>{};
                  final dailyRate =
                      (vehicle['price_per_day'] as num?)?.toDouble() ??
                      (vehicle['daily_rate'] as num?)?.toDouble() ??
                      (vehicle['rental_rate'] as num?)?.toDouble() ??
                      (booking['daily_rate'] as num?)?.toDouble() ??
                      (booking['price_per_day'] as num?)?.toDouble() ??
                      0.0;

                  final startRaw =
                      booking['start_at']?.toString() ??
                      booking['start_date']?.toString();
                  final endRaw =
                      booking['end_at']?.toString() ??
                      booking['end_date']?.toString();
                  final startDate = startRaw != null
                      ? DateTime.tryParse(startRaw)?.toLocal()
                      : null;
                  final endDate = endRaw != null
                      ? DateTime.tryParse(endRaw)?.toLocal()
                      : null;

                  int totalHours = 0;
                  if (startDate != null &&
                      endDate != null &&
                      endDate.isAfter(startDate)) {
                    totalHours = endDate.difference(startDate).inHours;
                  }

                  final fullDays = totalHours ~/ 24;
                  final excessHours = totalHours % 24;

                  String durationLabel = '';
                  if (fullDays > 0 && excessHours > 0) {
                    durationLabel = '$fullDays Day(s) $excessHours Hour(s)';
                  } else if (fullDays > 0) {
                    durationLabel = '$fullDays Day(s)';
                  } else if (excessHours > 0) {
                    durationLabel = '$excessHours Hour(s)';
                  } else {
                    final fallbackDays =
                        (booking['days'] as num?)?.toInt() ?? 1;
                    durationLabel = '$fallbackDays Day(s)';
                  }

                  final hourlyRate = dailyRate > 0 ? dailyRate / 24.0 : 0.0;
                  double subtotal = 0.0;
                  if (totalHours > 0 && dailyRate > 0) {
                    subtotal =
                        (fullDays * dailyRate) + (excessHours * hourlyRate);
                  } else {
                    final fallbackDays =
                        (booking['days'] as num?)?.toInt() ?? 1;
                    subtotal =
                        (booking['rental_subtotal'] as num?)?.toDouble() ??
                        (booking['subtotal'] as num?)?.toDouble() ??
                        (dailyRate > 0 ? dailyRate * fallbackDays : 0.0);
                  }

                  if (dailyRate > 0) {
                    return Column(
                      children: [
                        _buildOperatorSafetyLine(
                          'Vehicle Daily Rate',
                          'PHP ${_formatCurrency(dailyRate)} / day',
                        ),
                        _buildOperatorSafetyLine(
                          'Rental Duration',
                          '$durationLabel (Subtotal: PHP ${_formatCurrency(subtotal)})',
                        ),
                      ],
                    );
                  }
                  return _buildOperatorSafetyLine(
                    'Rental Duration',
                    durationLabel,
                  );
                }(),
                if ((booking['delivery_fee'] as num?)?.toDouble() != null &&
                    ((booking['delivery_fee'] as num).toDouble() > 0))
                  _buildOperatorSafetyLine(
                    'Delivery Fee',
                    'PHP ${_formatCurrency((booking['delivery_fee'] as num).toDouble())}',
                  ),
                if ((booking['driver_fee'] as num?)?.toDouble() != null &&
                    ((booking['driver_fee'] as num).toDouble() > 0))
                  _buildOperatorSafetyLine(
                    'Driver Fee',
                    'PHP ${_formatCurrency((booking['driver_fee'] as num).toDouble())}',
                  ),
                if (((booking['extension_additional_price'] as num?)
                                ?.toDouble() ??
                            0.0) >
                        0 ||
                    ((booking['extension_fee'] as num?)?.toDouble() ?? 0.0) >
                        0) ...[
                  _buildOperatorSafetyLine(
                    'Trip Extension Fee',
                    'PHP ${_formatCurrency(((booking['extension_additional_price'] as num?)?.toDouble() ?? (booking['extension_fee'] as num?)?.toDouble() ?? 0.0))}',
                  ),
                ],
                () {
                  final lateHours =
                      (booking['late_return_hours'] as num?)?.toInt() ?? 0;
                  final rawLateFee =
                      (booking['late_return_fee'] as num?)?.toDouble() ?? 0.0;
                  final actualLateFee = lateHours > 0
                      ? (rawLateFee > 0 && rawLateFee <= lateHours * 1000
                            ? rawLateFee
                            : lateHours * 300.0)
                      : (rawLateFee > 0 && rawLateFee <= 3000
                            ? rawLateFee
                            : 0.0);
                  if (actualLateFee > 0 || lateHours > 0) {
                    final displayHours = lateHours > 0
                        ? lateHours
                        : (actualLateFee / 300.0).ceil();
                    return _buildOperatorSafetyLine(
                      'Late Return Penalty (${displayHours}h @ ₱300/hr)',
                      'PHP ${_formatCurrency(actualLateFee > 0 ? actualLateFee : (displayHours * 300.0))}',
                    );
                  }
                  return const SizedBox.shrink();
                }(),
                _buildOperatorSafetyLine(
                  'Reservation Deposit Paid',
                  'PHP ${_formatCurrency(((booking['reservation_fee_amount'] as num?)?.toDouble() ?? 1000.0))} (${booking['reservation_payment_method'] ?? 'E-Wallet'} ref: ${booking['reservation_payment_reference'] ?? 'N/A'})',
                ),
                if (booking['final_payment_reference'] != null ||
                    booking['renter_return_payment_amount'] != null ||
                    booking['final_payment_method'] != null)
                  _buildOperatorSafetyLine(
                    'Final Return Settlement',
                    'PHP ${_formatCurrency(((booking['renter_return_payment_amount'] as num?)?.toDouble() ?? 0.0))} (${booking['final_payment_method'] ?? 'E-Wallet'} ref: ${booking['final_payment_reference'] ?? 'N/A'})',
                  ),
                _buildOperatorSafetyLine(
                  'Total Final Trip Cost',
                  'PHP ${_formatCurrency(((booking['total_price'] as num?)?.toDouble() ?? (booking['total_cost'] as num?)?.toDouble() ?? 0.0))}',
                ),
                if (!_isPartnerOwnedBooking(booking)) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final bId = booking['id']?.toString() ?? '';
                        if (bId.isNotEmpty) {
                          TripRouteHistoryDialog.show(
                            context: context,
                            bookingId: bId,
                            vehicleName: booking['vehicles']?['brand'] != null
                                ? '${booking['vehicles']['brand']} ${booking['vehicles']['model'] ?? ''}'
                                : null,
                            plateNumber:
                                booking['vehicles']?['plate_number']?.toString(),
                            renterName: booking['renter']?['full_name']?.toString(),
                          );
                        }
                      },
                      icon: const Icon(Icons.route_rounded, size: 16),
                      label: const Text(
                        'Audit Traveled GPS Route & Destination Compliance',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _operatorGold,
                        side: BorderSide(
                          color: _operatorGold.withValues(alpha: 0.8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                () {
                  final finalReceiptUrl =
                      (booking['final_payment_proof_url'] ??
                              booking['payment_proof_url'] ??
                              booking['proof_url'] ??
                              booking['reservation_payment_proof_url'])
                          ?.toString()
                          .trim();
                  final hasFinalReceipt =
                      finalReceiptUrl != null && finalReceiptUrl.isNotEmpty;
                  final isFullPaymentAtReservation =
                      booking['reservation_payment_type'] == 'full_payment' ||
                      (((booking['reservation_fee_amount'] as num?)
                                  ?.toDouble() ??
                              0) >=
                          (((booking['total_price'] as num?)?.toDouble() ??
                                  (booking['total_cost'] as num?)?.toDouble() ??
                                  0) -
                              1));
                  final isPaymentSubmitted =
                      booking['renter_return_payment_submitted'] == true ||
                      (booking['final_payment_reference']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true) ||
                      booking['final_payment_status'] == 'paid' ||
                      booking['final_payment_status'] == 'submitted' ||
                      hasFinalReceipt ||
                      isFullPaymentAtReservation;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasFinalReceipt) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              color: _operatorGold,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'RENTER ATTACHED RECEIPT',
                              style: TextStyle(
                                color: Color(0xFF91A9BE),
                                fontSize: 9,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1928),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: OnDemandNetworkImage(
                                  imageUrl: finalReceiptUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  label: 'Receipt',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Payment Proof Receipt',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      booking['final_payment_reference'] != null
                                          ? 'Ref: ${booking['final_payment_reference']}'
                                          : 'Uploaded by renter for settlement',
                                      style: const TextStyle(
                                        color: Color(0xFF91A9BE),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _showReceiptProofDialog(
                                        finalReceiptUrl,
                                        isDark,
                                      ),
                                      icon: const Icon(
                                        Icons.open_in_full_rounded,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'View Full Receipt',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _operatorGold,
                                        side: BorderSide(color: _operatorGold),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (booking['final_payment_status'] == 'pending' &&
                          status.trim().toLowerCase() != 'completed') ...[
                        const SizedBox(height: 12),
                        if (_isPartnerOwnedBooking(booking))
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.purple.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.handshake_outlined,
                                  color: Colors.purpleAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Partner Unit: Final payment & receipt verification is managed directly by the partner.',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.purple[200]
                                          : Colors.purple[800],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isPaymentSubmitted || resolveBookingPaymentState(booking) == BookingPaymentState.paymentReview)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (resolveBookingPaymentState(booking) == BookingPaymentState.paymentReview) {
                                  await _showVerifyPaymentProofDialog(booking);
                                } else {
                                  await _confirmOperatorFinalPayment(booking);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _operatorGold,
                                foregroundColor: _operatorNavyDeep,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.verified_user_rounded,
                                size: 16,
                              ),
                              label: Text(
                                resolveBookingPaymentState(booking) == BookingPaymentState.paymentReview
                                    ? 'Verify Renter Payment Proof'
                                    : 'Confirm Final Payment & Verify Receipt',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        else if (resolveBookingPaymentState(booking) == BookingPaymentState.pendingConfirmation ||
                            resolveBookingPaymentState(booking) == BookingPaymentState.paid)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.35),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF10B981),
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Payment verified & recorded. No pending payment required from renter.',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.hourglass_bottom_rounded,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Awaiting renter payment & receipt upload',
                                    style: TextStyle(
                                      color: Colors.amber[200] ?? Colors.amber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  );
                }(),
              ],
            ),
          ),
        ],
      );

    if (scrollable) {
      return Scrollbar(
        thumbVisibility: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          physics: const AlwaysScrollableScrollPhysics(),
          child: detailContent,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(26),
      child: detailContent,
    );
  }

  Future<void> _showBookingRouteDialog(
    Map<String, dynamic> booking,
    bool isDark,
  ) async {
    final pickup = _operatorPickupLabel(booking['pickup_location']?.toString());
    final destination = booking['dropoff_location']?.toString().trim() ?? '';
    final routePointsFuture = _resolveBookingRoutePoints(booking);
    final routeMapController = MapController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final foreground = isDark ? Colors.white : _operatorInk;
        final muted = isDark ? Colors.grey[400] : Colors.grey.shade600;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF172235) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _operatorGold.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.route_rounded, color: _operatorGold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Booking Route',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Exact locations submitted by the renter',
                              style: TextStyle(color: muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (!_isPartnerOwnedBooking(booking))
                        OutlinedButton.icon(
                        onPressed: () {
                          final bId = booking['id']?.toString() ?? '';
                          if (bId.isNotEmpty) {
                            TripRouteHistoryDialog.show(
                              context: context,
                              bookingId: bId,
                              vehicleName: booking['vehicles']?['brand'] != null
                                  ? '${booking['vehicles']['brand']} ${booking['vehicles']['model'] ?? ''}'
                                  : null,
                              plateNumber:
                                  booking['vehicles']?['plate_number']?.toString(),
                              renterName: booking['renter']?['full_name']?.toString(),
                            );
                          }
                        },
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                        label: const Text(
                          'Full GPS Playback Audit',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _operatorGold,
                          side: BorderSide(color: _operatorGold.withValues(alpha: 0.7)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Close route',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: Icon(Icons.close_rounded, color: foreground),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildRouteLocationRow(
                    icon: Icons.trip_origin_rounded,
                    label: 'Pickup location',
                    value: pickup,
                    color: AppColors.success,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildRouteLocationRow(
                    icon: Icons.flag_rounded,
                    label: 'Trip destination',
                    value: destination.isEmpty
                        ? 'No destination was provided'
                        : destination,
                    color: _operatorGold,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 320,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: FutureBuilder<List<MobilisMapPoint>>(
                        future: routePointsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return Container(
                              color: isDark
                                  ? const Color(0xFF0D1928)
                                  : Colors.grey.shade100,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                color: _operatorGold,
                              ),
                            );
                          }

                          final routePoints = snapshot.data ?? const [];
                          if (routePoints.isEmpty) {
                            return Container(
                              color: isDark
                                  ? const Color(0xFF0D1928)
                                  : Colors.grey.shade100,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                'The saved route could not be located. Ask the renter to update the booking pin.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: muted),
                              ),
                            );
                          }

                          final markers = <MobilisMapMarker>[
                            MobilisMapMarker(
                              latitude: routePoints.first.latitude,
                              longitude: routePoints.first.longitude,
                              icon: routePoints.length > 1
                                  ? Icons.trip_origin_rounded
                                  : Icons.flag_rounded,
                              color: routePoints.length > 1
                                  ? AppColors.success
                                  : _operatorGold,
                              size: 38,
                            ),
                            if (routePoints.length > 1)
                              MobilisMapMarker(
                                latitude: routePoints.last.latitude,
                                longitude: routePoints.last.longitude,
                                icon: Icons.flag_rounded,
                                color: _operatorGold,
                                size: 40,
                              ),
                          ];
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: MobilisLeafletMap(
                                  key: ValueKey(
                                    'operator-route-${booking['id']}-${routePoints.map((point) => '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}').join('|')}',
                                  ),
                                  markers: markers,
                                  routePoints: routePoints,
                                  routeColor: _operatorGold,
                                  initialZoom: routePoints.length > 1
                                      ? null
                                      : 14,
                                  mapController: routeMapController,
                                  mapStyle: MobilisMapStyle.street,
                                ),
                              ),
                              Positioned(
                                right: 14,
                                top: 14,
                                child: Column(
                                  children: [
                                    _buildRouteZoomButton(
                                      tooltip: 'Zoom in',
                                      icon: Icons.add_rounded,
                                      onPressed: () {
                                        final camera =
                                            routeMapController.camera;
                                        routeMapController.move(
                                          camera.center,
                                          (camera.zoom + 1).clamp(5, 19),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    _buildRouteZoomButton(
                                      tooltip: 'Zoom out',
                                      icon: Icons.remove_rounded,
                                      onPressed: () {
                                        final camera =
                                            routeMapController.camera;
                                        routeMapController.move(
                                          camera.center,
                                          (camera.zoom - 1).clamp(5, 19),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRouteZoomButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: const Color(0xFF071D31).withValues(alpha: 0.92),
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 24),
        constraints: const BoxConstraints.tightFor(width: 46, height: 46),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildRouteLocationRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 9,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorDetailTile(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    final tile = Container(
      width: 205,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? _operatorGold : _operatorNavy, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 9,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : _operatorInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.open_in_new_rounded,
              color: isDark ? _operatorGold : _operatorNavy,
              size: 15,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return tile;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: tile,
      ),
    );
  }

  Widget _buildRenterReviewCard(Map<String, dynamic> booking, bool isDark) {
    final renter = booking['renter'] as Map<String, dynamic>? ?? const {};
    final verified =
        renter['id_verified'] == true ||
        const {'approved', 'verified'}.contains(
          renter['verification_status']?.toString().trim().toLowerCase(),
        );
    final foreground = isDark ? Colors.white : _operatorInk;
    final muted = isDark ? Colors.grey[400] : Colors.grey.shade600;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_search_outlined,
                color: isDark ? _operatorGold : _operatorNavy,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'Renter Review',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (verified ? Colors.green : Colors.orange).withOpacity(
                    0.14,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  verified ? 'IDENTITY VERIFIED' : 'VERIFY DOCUMENTS',
                  style: TextStyle(
                    color: verified ? Colors.green : Colors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _buildPaymentInfoTile(
                'Full name',
                renter['full_name']?.toString().trim().isNotEmpty == true
                    ? renter['full_name'].toString()
                    : 'Not provided',
                isDark,
              ),
              _buildPaymentInfoTile(
                'Email',
                renter['email']?.toString().trim().isNotEmpty == true
                    ? renter['email'].toString()
                    : 'Not provided',
                isDark,
              ),
              _buildPaymentInfoTile(
                'Phone',
                renter['phone']?.toString().trim().isNotEmpty == true
                    ? renter['phone'].toString()
                    : 'Not provided',
                isDark,
              ),
              _buildPaymentInfoTile(
                'Location',
                renter['location']?.toString().trim().isNotEmpty == true
                    ? renter['location'].toString()
                    : 'Not provided',
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Review the renter information and the verification evidence below before finalizing this booking.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorSafetyLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF91A9BE),
                fontSize: 9,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorEvidenceChip(IconData icon, String label, dynamic url) {
    final available = url?.toString().trim().isNotEmpty == true;
    return Tooltip(
      message: available ? 'Preview $label' : '$label was not uploaded',
      child: InkWell(
        onTap: available
            ? () => _showOperatorEvidencePreview(label, url.toString().trim())
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 132),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: available
                  ? _operatorGold.withOpacity(0.45)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                available ? icon : Icons.warning_amber_rounded,
                size: 15,
                color: available ? _operatorGold : Colors.orangeAccent,
              ),
              const SizedBox(width: 7),
              Text(
                available ? label : '$label missing',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (available) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.visibility_outlined,
                  color: Color(0xFF91A9BE),
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOperatorEvidencePreview(String title, String url) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (previewContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172235) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 34,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _operatorGold.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: _operatorGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isDark ? Colors.white : _operatorInk,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Booking verification evidence',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.pop(previewContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: isDark
                          ? Colors.black.withOpacity(0.18)
                          : const Color(0xFFF1F3F5),
                      child: SizedBox.expand(
                        child: OptimizedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          isThumbnail: false,
                          errorWidget: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.broken_image_outlined,
                                    size: 54,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'This uploaded file cannot be previewed as an image.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildBookingSection(
    String title,
    List<Map<String, dynamic>> bookings,
    bool isDark,
    Color statusColor, {
    bool showEmpty = false,
  }) {
    final isEmpty = bookings.isEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$title (${bookings.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isEmpty && showEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No ${title.toLowerCase()} at this time',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else if (!isEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final vehicle = booking['vehicles'] as Map<String, dynamic>?;
                final renter = booking['renter'] as Map<String, dynamic>?;
                final driver = booking['driver'] as Map<String, dynamic>?;
                final driverUser = driver?['user'] as Map<String, dynamic>?;
                final withDriver = _bookingNeedsDriver(booking['with_driver']);
                final latestAssignment = _latestDriverAssignment(booking);
                final assignmentStatus = latestAssignment?['status']
                    ?.toString()
                    .trim()
                    .toLowerCase();
                final waitingForDriver =
                    assignmentStatus == 'pending_offer' ||
                    assignmentStatus == 'assigned';
                final assignedAtRaw = booking['driver_assigned_at'] ?? latestAssignment?['offered_at'] ?? latestAssignment?['created_at'];
                final assignedAt = assignedAtRaw != null ? DateTime.tryParse(assignedAtRaw.toString())?.toLocal() : null;
                final offerRemainingSec = (waitingForDriver && assignedAt != null)
                    ? (600 - DateTime.now().difference(assignedAt).inSeconds).clamp(0, 600)
                    : 0;
                final isOfferExpired = assignmentStatus == 'expired' || (waitingForDriver && (assignedAt != null && offerRemainingSec <= 0));
                final effectiveWaitingForDriver = waitingForDriver && !isOfferExpired;
                final driverAccepted =
                    assignmentStatus == 'accepted' ||
                    assignmentStatus == 'confirmed' ||
                    booking['status']?.toString().toLowerCase() == 'driver_accepted';
                final driverDeclined = assignmentStatus == 'rejected' || assignmentStatus == 'declined' || isOfferExpired;
                final status = booking['status'] as String? ?? 'pending';
                final statusLower = status.toLowerCase();
                final canTrack = _canTrackBooking(booking);
                final completionState = BookingService().getTripCompletionState(
                  booking,
                );
                final completionStage = completionState['completionStage']
                    ?.toString();
                final total =
                    (booking['total_price'] as num?)?.toDouble() ??
                    (booking['total_cost'] as num?)?.toDouble() ??
                    0.0;

                // Parse dates
                final startAtStr =
                    (booking['start_at'] ?? booking['start_date']) as String? ??
                    '';
                final endAtStr =
                    (booking['end_at'] ?? booking['end_date']) as String? ?? '';
                final startDate = DateTime.tryParse(startAtStr);
                final endDate = DateTime.tryParse(endAtStr);
                final pickedUpAt = DateTime.tryParse(
                  booking['picked_up_at']?.toString() ?? '',
                );
                final returnedAt = DateTime.tryParse(
                  booking['returned_at']?.toString() ?? '',
                );
                final days = _inclusiveRentalDays(startDate, endDate);

                final localStartDate = startDate?.toLocal();
                final localEndDate = endDate?.toLocal();
                final dateRange = localStartDate != null && localEndDate != null
                    ? '${localStartDate.day.toString().padLeft(2, '0')} ${_getMonthName(localStartDate.month)} - ${localEndDate.day.toString().padLeft(2, '0')} ${_getMonthName(localEndDate.month)}'
                    : 'N/A';
                final startSchedule = _formatBookingDateTime(startDate);
                final endSchedule = _formatBookingDateTime(endDate);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with vehicle and renter
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vehicle thumbnail
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: isDark
                                  ? Colors.black38
                                  : Colors.grey.shade200,
                            ),
                            child: vehicle?['image_url'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: OptimizedNetworkImage(
                                      imageUrl: vehicle!['image_url'],
                                      fit: BoxFit.cover,
                                      errorWidget: Center(
                                        child: Icon(
                                          Icons.directions_car,
                                          color: isDark
                                              ? Colors.grey[600]
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.directions_car,
                                      color: isDark
                                          ? Colors.grey[600]
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          // Vehicle and renter info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Vehicle name + year
                                Text(
                                  vehicle != null
                                      ? _vehicleTitle(vehicle)
                                      : 'Unknown Vehicle',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Renter name
                                Text(
                                  'Renter: ${renter?['full_name'] ?? 'Unknown'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Driver chip if applicable
                                if (withDriver && driver != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Driver: ${driverUser?['full_name'] ?? 'TBA'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black38 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Schedule',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Start: $startSchedule',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Return: $endSchedule',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Details row: dates, days, total, status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Date range
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dates',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateRange,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          // Days
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Days',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$days',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Total
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '₱${total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (pickedUpAt != null || returnedAt != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (pickedUpAt != null)
                              _buildBookingEventChip(
                                Icons.key,
                                'Picked up: '
                                '${pickedUpAt.day.toString().padLeft(2, '0')} '
                                '${_getMonthName(pickedUpAt.month)}',
                                isDark,
                              ),
                            if (returnedAt != null)
                              _buildBookingEventChip(
                                Icons.assignment_turned_in,
                                'Returned: '
                                '${returnedAt.day.toString().padLeft(2, '0')} '
                                '${_getMonthName(returnedAt.month)}',
                                isDark,
                              ),
                          ],
                        ),
                      ],
                      if (statusLower == 'pending') ...[
                        const SizedBox(height: 12),
                        _buildBookingPaymentDetails(booking, isDark),
                        if (withDriver && assignmentStatus != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: driverAccepted
                                  ? Colors.green.withOpacity(0.12)
                                  : driverDeclined
                                  ? Colors.red.withOpacity(0.12)
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: driverAccepted
                                    ? Colors.green
                                    : driverDeclined
                                    ? Colors.red
                                    : AppColors.primary,
                              ),
                            ),
                            child: Text(
                              driverAccepted
                                  ? 'Driver accepted. Finalize the booking to create the conversation.'
                                  : driverDeclined
                                  ? 'Driver declined. Select another available driver.'
                                  : 'Waiting for the selected driver to accept or decline.',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      // Status and actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildStatusBadge(status),
                          Flexible(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_isPartnerOwnedBooking(booking))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.purple.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.handshake_outlined,
                                          size: 14,
                                          color: Colors.purpleAccent,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Partner Unit • View Only',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.purple[200]
                                                : Colors.purple[800],
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (statusLower == 'pending' &&
                                    (!withDriver || driverAccepted) &&
                                    !_isPartnerOwnedBooking(booking))
                                  ElevatedButton.icon(
                                    onPressed: () => _handleQuickApproveBooking(
                                      booking,
                                      needsDriver: withDriver,
                                      driverAccepted: driverAccepted,
                                    ),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Finalize'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if (statusLower == 'pending' &&
                                     withDriver &&
                                     !driverAccepted &&
                                     (!effectiveWaitingForDriver || isOfferExpired) &&
                                     !_isPartnerOwnedBooking(booking))
                                   ElevatedButton.icon(
                                     onPressed: () =>
                                         _showApproveDialog(booking),
                                     icon: const Icon(
                                       Icons.person_search,
                                       size: 16,
                                     ),
                                     label: Text(
                                       driverDeclined
                                           ? 'Select Another Driver'
                                           : (isOfferExpired
                                               ? 'Driver Expired • Reassign'
                                               : 'Select Driver'),
                                     ),
                                     style: ElevatedButton.styleFrom(
                                       backgroundColor: (driverDeclined || isOfferExpired)
                                           ? Colors.amber[800]
                                           : Colors.green,
                                       foregroundColor: Colors.white,
                                       padding: const EdgeInsets.symmetric(
                                         horizontal: 16,
                                         vertical: 8,
                                       ),
                                     ),
                                   ),
                                 if (statusLower == 'pending' &&
                                     withDriver &&
                                     effectiveWaitingForDriver &&
                                     !_isPartnerOwnedBooking(booking))
                                   OutlinedButton.icon(
                                     onPressed: () => _showApproveDialog(booking),
                                     icon: const SizedBox(
                                       width: 14,
                                       height: 14,
                                       child: CircularProgressIndicator(
                                         strokeWidth: 2,
                                       ),
                                     ),
                                     label: Text(
                                       'Awaiting Driver (${(offerRemainingSec ~/ 60).toString().padLeft(2, '0')}:${(offerRemainingSec % 60).toString().padLeft(2, '0')})',
                                     ),
                                     style: OutlinedButton.styleFrom(
                                       foregroundColor: AppColors.primary,
                                       side: const BorderSide(color: AppColors.primary),
                                       padding: const EdgeInsets.symmetric(
                                         horizontal: 14,
                                         vertical: 8,
                                       ),
                                     ),
                                   ),
                                if (statusLower == 'pending' &&
                                    !_isPartnerOwnedBooking(booking))
                                  OutlinedButton.icon(
                                    onPressed: () => _showRejectDialog(
                                      booking['id'].toString(),
                                    ),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      foregroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if (canTrack)
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _openTrackingForBooking(booking),
                                    icon: const Icon(Icons.explore_outlined),
                                    label: const Text('Track'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _showBookingSafetyReviewDialog(booking),
                                  icon: const Icon(
                                    Icons.verified_user_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Review Docs'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                                if ((statusLower == 'confirmed' ||
                                        statusLower == 'approved') &&
                                    !_isPartnerOwnedBooking(booking))
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _openOperatorInspectionRecordOrForm(
                                          booking,
                                          inspectionType: 'before',
                                          allowCreate: true,
                                        ),
                                    icon: const Icon(
                                      Icons.fact_check_outlined,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Submit Checklist & Start Trip',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(
                                        color: Colors.blue,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if ((statusLower == 'active' ||
                                        statusLower == 'ongoing' ||
                                        statusLower ==
                                            'return_pending_inspection') &&
                                    !_isPartnerOwnedBooking(booking))
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _openOperatorInspectionRecordOrForm(
                                          booking,
                                          inspectionType: 'before',
                                          allowCreate: false,
                                        ),
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'View Pre-Trip Checklist',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(
                                        color: Colors.blue,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if ((statusLower == 'approved' ||
                                        statusLower == 'confirmed' ||
                                        statusLower == 'active' ||
                                        statusLower == 'ongoing' ||
                                        statusLower ==
                                            'return_pending_inspection') &&
                                    !_isPartnerOwnedBooking(booking))
                                  ElevatedButton.icon(
                                    onPressed:
                                        statusLower ==
                                            'return_pending_inspection'
                                        ? () => _showInspectionDialog(
                                            booking,
                                            inspectionType: 'after',
                                          )
                                        : null,
                                    icon: Icon(
                                      statusLower == 'return_pending_inspection'
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.lock_clock_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      statusLower == 'return_pending_inspection'
                                          ? 'Confirm Return Inspection'
                                          : 'Confirm Return (Awaiting Renter)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          statusLower ==
                                              'return_pending_inspection'
                                          ? AppColors.primary
                                          : Colors.grey.shade800,
                                      foregroundColor:
                                          statusLower ==
                                              'return_pending_inspection'
                                          ? Colors.black
                                          : Colors.grey.shade500,
                                      disabledBackgroundColor:
                                          Colors.grey.shade800,
                                      disabledForegroundColor:
                                          Colors.grey.shade500,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if ({
                                  'approved',
                                  'confirmed',
                                  'active',
                                  'ongoing',
                                  'return_pending_inspection',
                                }.contains(statusLower))
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _openBookingConversation(booking),
                                    icon: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 16,
                                    ),
                                    label: const Text('Message'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(
                                        color: AppColors.primary,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                if ((statusLower == 'confirmed' ||
                                        statusLower == 'approved' ||
                                        statusLower == 'active') &&
                                    !canTrack)
                                  Text(
                                    _isCompanyOwnedBooking(booking)
                                        ? 'Waiting for live location'
                                        : 'Partner monitors this trip',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                if (canTrack)
                                  Text(
                                    'Driver updates this trip',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                () {
                                  final finalReceiptUrl =
                                      (booking['final_payment_proof_url'] ??
                                              booking['payment_proof_url'] ??
                                              booking['proof_url'] ??
                                              booking['reservation_payment_proof_url'])
                                          ?.toString()
                                          .trim();
                                  final hasFinalReceipt =
                                      finalReceiptUrl != null &&
                                      finalReceiptUrl.isNotEmpty;
                                  final isFullPaymentAtReservation =
                                      booking['reservation_payment_type'] ==
                                          'full_payment' ||
                                      (((booking['reservation_fee_amount']
                                                      as num?)
                                                  ?.toDouble() ??
                                              0) >=
                                          (((booking['total_price'] as num?)
                                                      ?.toDouble() ??
                                                  (booking['total_cost']
                                                          as num?)
                                                      ?.toDouble() ??
                                                  0) -
                                              1));
                                  final isPaymentSubmitted =
                                      booking['renter_return_payment_submitted'] ==
                                          true ||
                                      (booking['final_payment_reference']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true) ||
                                      booking['final_payment_status'] ==
                                          'paid' ||
                                      booking['final_payment_status'] ==
                                          'submitted' ||
                                      hasFinalReceipt ||
                                      isFullPaymentAtReservation;

                                  if (completionStage == 'awaiting_payment' &&
                                      !_isPartnerOwnedBooking(booking)) {
                                    if (isPaymentSubmitted) {
                                      return ElevatedButton.icon(
                                        onPressed: () =>
                                            _confirmOperatorFinalPayment(
                                              booking,
                                            ),
                                        icon: const Icon(
                                          Icons.payments_outlined,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Confirm Full Payment',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                      );
                                    } else {
                                      return Text(
                                        'Awaiting renter payment',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.amber[300]
                                              : Colors.amber[800],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    }
                                  }
                                  return const SizedBox.shrink();
                                }(),
                                if ((statusLower == 'awaiting_completion' ||
                                        statusLower == 'completed') &&
                                    statusLower != 'ongoing' &&
                                    statusLower != 'active' &&
                                    statusLower != 'approved' &&
                                    statusLower !=
                                        'return_pending_inspection' &&
                                    booking['return_inspected_at'] != null &&
                                    !_isPartnerOwnedBooking(booking) &&
                                    (completionStage == 'operator_rating' ||
                                        completionStage ==
                                            'awaiting_completion' ||
                                        completionStage ==
                                            'awaiting_after_checklist' ||
                                        completionStage ==
                                            'awaiting_payment' ||
                                        completionStage == 'completed')) ...[
                                  if (_isOperatorRatingFullyCompleted(booking))
                                    Tooltip(
                                      message: 'Rating is complete',
                                      child: ElevatedButton.icon(
                                        onPressed: null,
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                        ),
                                        label: const Text('Rating Complete'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade300,
                                          foregroundColor: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _openOperatorRenterRating(booking),
                                      icon: const Icon(
                                        Icons.star_rate_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Rate Trip'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                ],
                                if (completionStage == 'completed')
                                  Text(
                                    'Trip completed after all required ratings',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBookingPaymentDetails(
    Map<String, dynamic> booking,
    bool isDark,
  ) {
    final amount = (booking['reservation_fee_amount'] as num?)?.toDouble();
    final type = booking['reservation_payment_type']?.toString() ?? '';
    final coversTotal = booking['reservation_payment_covers_total'] == true;
    final rawBookingStatus =
        (booking['status']?.toString() ??
                booking['rawStatus']?.toString() ??
                '')
            .toLowerCase();
    final isBookingConfirmedOrActive =
        rawBookingStatus == 'approved' ||
        rawBookingStatus == 'confirmed' ||
        rawBookingStatus == 'active' ||
        rawBookingStatus == 'ongoing' ||
        rawBookingStatus == 'return_pending_inspection' ||
        rawBookingStatus == 'awaiting_completion' ||
        rawBookingStatus == 'completed';

    final status = isBookingConfirmedOrActive
        ? 'Verified & Confirmed'
        : (booking['reservation_payment_status']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? booking['reservation_payment_status'].toString()
              : 'Not submitted');

    final method =
        booking['reservation_payment_method']?.toString().trim().isNotEmpty ==
            true
        ? booking['reservation_payment_method'].toString()
        : 'PSDC QR payment';
    final reference =
        booking['reservation_payment_reference']?.toString().trim() ?? '';
    final proofUrl =
        booking['reservation_payment_proof_url']?.toString().trim() ?? '';
    final submittedAt = DateTime.tryParse(
      booking['reservation_payment_submitted_at']?.toString() ?? '',
    )?.toLocal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black38 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  coversTotal ? 'FULL PAYMENT' : 'RESERVATION',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _buildPaymentInfoTile(
                'Amount paid',
                amount == null ? 'N/A' : 'PHP ${_formatCurrency(amount, decimals: 0)}',
                isDark,
              ),
              _buildPaymentInfoTile(
                'Payment type',
                type.isEmpty ? 'Reservation only' : type.replaceAll('_', ' '),
                isDark,
              ),
              _buildPaymentInfoTile(
                'Status',
                status.replaceAll('_', ' '),
                isDark,
              ),
              _buildPaymentInfoTile(
                'Method',
                method.replaceAll('_', ' '),
                isDark,
              ),
              _buildPaymentInfoTile(
                'Reference',
                reference.isEmpty ? 'Missing' : reference,
                isDark,
              ),
              _buildPaymentInfoTile(
                'Submitted',
                _formatBookingDateTime(submittedAt),
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (proofUrl.isEmpty)
            Text(
              'No receipt proof uploaded.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                fontSize: 12,
              ),
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: OnDemandNetworkImage(
                    imageUrl: proofUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    label: 'Load',
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _showReceiptProofDialog(proofUrl, isDark),
                  icon: const Icon(Icons.open_in_full, size: 16),
                  label: const Text('View receipt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoTile(String label, String value, bool isDark) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[500] : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptProofDialog(String proofUrl, bool isDark) {
    String resolvedUrl = proofUrl.trim();
    if (resolvedUrl.isNotEmpty &&
        !resolvedUrl.startsWith('http://') &&
        !resolvedUrl.startsWith('https://') &&
        !resolvedUrl.startsWith('data:')) {
      resolvedUrl = resolvedUrl.replaceFirst(RegExp(r'^/+'), '');
      if (resolvedUrl.startsWith('booking_evidence/')) {
        resolvedUrl = _supabase.storage
            .from('booking_evidence')
            .getPublicUrl(resolvedUrl.substring('booking_evidence/'.length));
      } else if (resolvedUrl.startsWith('partner_documents/')) {
        resolvedUrl = _supabase.storage
            .from('partner_documents')
            .getPublicUrl(resolvedUrl.substring('partner_documents/'.length));
      } else {
        resolvedUrl = _supabase.storage
            .from('booking_evidence')
            .getPublicUrl(resolvedUrl);
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Payment Receipt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    if (resolvedUrl.startsWith('http'))
                      IconButton(
                        tooltip: 'Open in new tab',
                        onPressed: () => launchUrl(
                          Uri.parse(resolvedUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (resolvedUrl.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No receipt image uploaded.',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Refund was recorded with transaction reference number.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: OptimizedNetworkImage(
                        imageUrl: resolvedUrl,
                        fit: BoxFit.contain,
                        isThumbnail: false,
                        errorWidget: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Unable to load receipt image.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (resolvedUrl.startsWith('http'))
                                TextButton.icon(
                                  onPressed: () => launchUrl(
                                    Uri.parse(resolvedUrl),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  icon: const Icon(Icons.open_in_new, size: 14),
                                  label: const Text('Try opening in browser'),
                                ),
                            ],
                          ),
                        ),
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

  Future<void> _showRenterQrModal(
    BuildContext context, {
    required String qrUrl,
    required String renterName,
    required String provider,
    required String accountNumber,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF172235) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded, color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$renterName\'s $provider QR Code',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          'Account No: $accountNumber',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981), width: 2),
                ),
                child: Image.network(
                  qrUrl,
                  width: 260,
                  height: 260,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Container(
                    width: 240,
                    height: 240,
                    color: Colors.grey.shade200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.qr_code_2_rounded, size: 60, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Unable to display QR image', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scan this QR code using your $provider app to disburse the security deposit refund directly to $renterName.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _showSecurityDepositRefundDialog(
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    return ActionGuard.runGuarded('deposit_refund_dialog_$bookingId', () async {
      final isDark = Theme.of(context).brightness == Brightness.dark;
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final renterName = renter['full_name']?.toString() ?? 'Renter';
    final renterPhone = renter['phone_number']?.toString() ??
        renter['phone']?.toString() ??
        booking['renter_phone']?.toString() ??
        '';
    final vehicleName =
        '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();

    // Renter Payout methods & QR fetching
    final renterUserId = (booking['renter_id'] ?? renter['id'] ?? renter['user_id'])?.toString();
    List<PayoutMethod> renterPayoutMethods = [];
    String? discoveredQrUrl;

    if (renterUserId != null && renterUserId.isNotEmpty) {
      try {
        renterPayoutMethods = await PayoutMethodService().getPayoutMethods(renterUserId);
      } catch (e) {
        debugPrint('Could not load renter payout methods: $e');
      }

      try {
        discoveredQrUrl = await PayoutMethodService().getRenterQrCodeUrl(renterUserId);
      } catch (e) {
        debugPrint('Could not discover renter QR code URL: $e');
      }
    }

    final directQrUrl = (discoveredQrUrl != null && discoveredQrUrl.isNotEmpty)
        ? discoveredQrUrl
        : (renter['qr_code_url']?.toString() ??
            renter['gcash_qr_url']?.toString() ??
            renter['payout_qr_url']?.toString() ??
            booking['renter_qr_url']?.toString());

    // Fetch dynamic Admin Settings for Security Deposit
    ReservationPaymentSettings adminSettings = const ReservationPaymentSettings();
    try {
      adminSettings = await ReservationPaymentService().getSettings();
    } catch (e) {
      debugPrint('Could not load admin deposit settings: $e');
    }

    // Determine seater capacity & deposit rule from Admin Settings
    final vehicleSeatsRaw = vehicle['seats'] ?? booking['seats'];
    int seats = 5;
    if (vehicleSeatsRaw != null) {
      if (vehicleSeatsRaw is num) {
        seats = vehicleSeatsRaw.toInt();
      } else {
        seats = int.tryParse(vehicleSeatsRaw.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 5;
      }
    }
    final double defaultSecurityDeposit = adminSettings.getDepositForSeats(seats);
    final depositAmount = (booking['security_deposit'] as num?)?.toDouble() ?? defaultSecurityDeposit;

    bool isAlreadyRefunded = booking['security_deposit_refunded'] == true;
    final pastRefundAmount = (booking['security_deposit_refund_amount'] as num?)?.toDouble();
    final pastDeduction = (booking['security_deposit_refund_deduction'] as num?)?.toDouble();
    final pastNotes = booking['security_deposit_refund_notes']?.toString() ?? '';
    final pastRef = booking['security_deposit_refund_ref']?.toString() ?? '';
    final pastMethod = booking['security_deposit_refund_method']?.toString();

    final refundAmountController = TextEditingController(
      text: (isAlreadyRefunded && pastRefundAmount != null)
          ? pastRefundAmount.toStringAsFixed(0)
          : depositAmount.toStringAsFixed(0),
    );
    final deductionAmountController = TextEditingController(
      text: (isAlreadyRefunded && pastDeduction != null)
          ? pastDeduction.toStringAsFixed(0)
          : '0',
    );
    final deductionNotesController = TextEditingController(
      text: isAlreadyRefunded ? pastNotes : '',
    );
    final referenceController = TextEditingController(
      text: isAlreadyRefunded ? pastRef : '',
    );
    String selectedMethod = (isAlreadyRefunded && pastMethod != null && pastMethod.isNotEmpty)
        ? pastMethod
        : (renterPayoutMethods.isNotEmpty
            ? renterPayoutMethods.first.provider
            : 'GCash');
    // Fetch post-trip return inspection
    Map<String, dynamic>? postInspection;
    try {
      final inspections = await BookingInspectionService().getBookingInspections(bookingId);
      final afterList = inspections.where((i) => (i['inspection_type']?.toString().toLowerCase() == 'after')).toList();
      if (afterList.isNotEmpty) {
        postInspection = afterList.first;
      }
    } catch (e) {
      debugPrint('Could not load booking inspections: $e');
    }

    PlatformFile? receiptFile;
    bool isSubmitting = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isPartner = _isPartnerOwnedBooking(booking);
          final deposit = double.tryParse(refundAmountController.text) ?? depositAmount;
          final deduction = double.tryParse(deductionAmountController.text) ?? 0.0;
          final netRefund = (deposit - deduction).clamp(0.0, double.infinity);

          // Resolve current status in workflow
          final currentStatus = (booking['security_deposit_refunded'] == true)
              ? 'refund_processed'
              : (booking['security_deposit_status']?.toString() ??
                  (postInspection != null ? 'post_inspection_submitted' : 'deposit_held'));

          // Find active renter method matching selectedMethod
          final activeMethod = renterPayoutMethods.firstWhere(
            (m) => m.provider.toLowerCase() == selectedMethod.toLowerCase(),
            orElse: () => renterPayoutMethods.isNotEmpty
                ? renterPayoutMethods.first
                : PayoutMethod(
                    id: '',
                    provider: selectedMethod,
                    accountName: renterName,
                    accountNumber: renterPhone,
                    qrCodeUrl: directQrUrl,
                    createdAt: DateTime.now(),
                  ),
          );

          final activeQrUrl = (activeMethod.qrCodeUrl != null && activeMethod.qrCodeUrl!.trim().isNotEmpty)
              ? activeMethod.qrCodeUrl!.trim()
              : (directQrUrl != null && directQrUrl.trim().isNotEmpty ? directQrUrl.trim() : '');

          // Parse flagged items from post-inspection checklist
          final flaggedItems = <String>[];
          if (postInspection != null) {
            final rawChecklist = postInspection['checklist_items'];
            if (rawChecklist is Map) {
              final Map<String, String> keyToLabel = {};
              for (final sec in BookingInspectionService.checklistSections.values) {
                keyToLabel.addAll(sec);
              }
              rawChecklist.forEach((key, val) {
                if (val == false) {
                  flaggedItems.add(keyToLabel[key] ?? key.toString().replaceAll('_', ' '));
                }
              });
            }
          }

          final evidenceRaw = postInspection?['evidence_urls'];
          final List<String> evidenceUrls = evidenceRaw is List
              ? evidenceRaw.map((e) => e.toString()).where((u) => u.trim().isNotEmpty).toList()
              : [];

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF172235) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.assignment_return_rounded,
                              color: Color(0xFF10B981),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Security Deposit Refund Review',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$vehicleName ($seats Seater) • Booking #${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Operator Authority & Funds Notice
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.verified_user_rounded, color: Color(0xFF0284C7), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isPartner
                                          ? 'Operator & PSDC Authority: PSDC initially receives and holds the security deposit. The Partner submits a Post-Inspection condition report as a recommendation. The Operator reviews the findings, decides any deduction, and releases the refund.'
                                          : 'Operator & PSDC Authority: PSDC holds the security deposit for company fleet vehicles. The return inspection findings are recorded below. The Operator reviews the vehicle condition, decides any deduction, and releases the refund.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Workflow Status Tracker Chips
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2D44) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2C3E5A) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SECURITY DEPOSIT WORKFLOW STAGES',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _buildWorkflowChip('1. Deposit Held', isDone: true, isActive: currentStatus == 'deposit_held', isDark: isDark),
                                      _buildWorkflowChip('2. Post Inspection Submitted', isDone: postInspection != null || isAlreadyRefunded, isActive: currentStatus == 'post_inspection_submitted', isDark: isDark),
                                      _buildWorkflowChip('3. Operator Review', isDone: isAlreadyRefunded, isActive: currentStatus == 'operator_review' || (postInspection != null && !isAlreadyRefunded), isDark: isDark),
                                      _buildWorkflowChip('4. Refund Processed', isDone: isAlreadyRefunded, isActive: currentStatus == 'refund_processed', isDark: isDark),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (booking['security_deposit_refunded'] == true) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Security Deposit Refund Completed: PHP ${_formatCurrency(((booking["security_deposit_refund_amount"] ?? depositAmount) as num), decimals: 0)} was already refunded for this booking.',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF10B981)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Post Inspection Findings & Vehicle Condition Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: flaggedItems.isNotEmpty || (postInspection?['damages']?.toString().isNotEmpty == true)
                                      ? Colors.orange.withValues(alpha: 0.6)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  width: flaggedItems.isNotEmpty ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.fact_check_rounded,
                                        size: 20,
                                        color: postInspection != null ? const Color(0xFF0284C7) : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isPartner
                                              ? 'Partner Post-Inspection Findings & Condition'
                                              : 'PSDC Return Inspection Findings & Condition',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                        ),
                                      ),
                                      if (postInspection != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (booking['security_deposit_return_eligible'] == true)
                                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                : Colors.orange.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: (booking['security_deposit_return_eligible'] == true)
                                                  ? const Color(0xFF10B981)
                                                  : Colors.orange,
                                            ),
                                          ),
                                          child: Text(
                                            (booking['security_deposit_return_eligible'] == true)
                                                ? (isPartner ? 'Partner Recommended: Cleared' : 'PSDC Inspection: Cleared')
                                                : (isPartner ? 'Partner Recommended: Review Issues' : 'PSDC Inspection: Review Issues'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: (booking['security_deposit_return_eligible'] == true)
                                                  ? const Color(0xFF10B981)
                                                  : Colors.orange,
                                            ),
                                          ),
                                        )
                                      else
                                        const Text(
                                          'No inspection filed yet',
                                          style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  if (postInspection != null) ...[
                                    // Condition Grid
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildInspectionMiniItem(
                                            label: 'Fuel Level',
                                            value: postInspection['fuel_level']?.toString() ?? 'Recorded',
                                            icon: Icons.local_gas_station_rounded,
                                            isDark: isDark,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildInspectionMiniItem(
                                            label: 'Cleanliness',
                                            value: postInspection['cleanliness']?.toString() ?? 'Recorded',
                                            icon: Icons.cleaning_services_rounded,
                                            isDark: isDark,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildInspectionMiniItem(
                                            label: 'Tires / Mags',
                                            value: '${postInspection["tires_details"] ?? "OK"} / ${postInspection["mags_details"] ?? "OK"}',
                                            icon: Icons.tire_repair_rounded,
                                            isDark: isDark,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildInspectionMiniItem(
                                            label: 'Mileage',
                                            value: postInspection['mileage'] != null
                                                ? '${postInspection["mileage"]} km'
                                                : 'Not logged',
                                            icon: Icons.speed_rounded,
                                            isDark: isDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Flagged issues / unchecked items
                                    if (flaggedItems.isNotEmpty) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: const [
                                                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Reported Deficiencies / Unchecked Checklist Items:',
                                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Colors.red),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: flaggedItems
                                                  .map(
                                                    (item) => Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(5),
                                                      ),
                                                      child: Text(
                                                        '• $item',
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],

                                    // Reported damages or remarks
                                    if (postInspection['damages']?.toString().isNotEmpty == true ||
                                        postInspection['remarks']?.toString().isNotEmpty == true ||
                                        booking['security_deposit_return_notes']?.toString().isNotEmpty == true) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (postInspection['damages']?.toString().isNotEmpty == true)
                                              Text(
                                                'Reported Damages: ${postInspection["damages"]}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange),
                                              ),
                                            if (postInspection['remarks']?.toString().isNotEmpty == true)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  'Inspector Remarks: ${postInspection["remarks"]}',
                                                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87),
                                                ),
                                              ),
                                            if (booking['security_deposit_return_notes']?.toString().isNotEmpty == true)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  'Partner Deposit Note: ${booking["security_deposit_return_notes"]}',
                                                  style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.black54),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],

                                    // Photo evidence thumbnails
                                    if (evidenceUrls.isNotEmpty) ...[
                                      const Text(
                                        'Inspection Evidence Photos (Tap to inspect full size):',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        height: 64,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: evidenceUrls.length,
                                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                                          itemBuilder: (ctx, idx) {
                                            final url = evidenceUrls[idx];
                                            return InkWell(
                                              onTap: () => _showReceiptProofDialog(url, isDark),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  width: 64,
                                                  height: 64,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
                                                  ),
                                                  child: Image.network(
                                                    url,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ] else ...[
                                    Text(
                                      isPartner
                                          ? 'Post-trip return inspection has not been submitted by Partner yet.'
                                          : 'Return inspection has not been recorded yet.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Quick Decision Preset Buttons for Operator
                            if (!isAlreadyRefunded) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setDialogState(() {
                                          deductionAmountController.text = '0';
                                          deductionNotesController.text = 'Vehicle inspected and cleared. Full refund approved.';
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF10B981),
                                        side: const BorderSide(color: Color(0xFF10B981)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                      label: const Text(
                                        'Approve Full Refund (₱0 Deduction)',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setDialogState(() {
                                          if (deductionAmountController.text == '0' || deductionAmountController.text.isEmpty) {
                                            deductionAmountController.text = '500';
                                          }
                                          if (deductionNotesController.text.isEmpty) {
                                            deductionNotesController.text = 'Post-inspection deduction for damages / missing items.';
                                          }
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange,
                                        side: const BorderSide(color: Colors.orange),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.handyman_outlined, size: 18),
                                      label: const Text(
                                        'Apply Deduction & Refund Remaining',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Renter Info & Linked Accounts / QR Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2D44) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2C3E5A) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                        child: Text(
                                          renterName.isNotEmpty ? renterName[0].toUpperCase() : 'R',
                                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              renterName,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(Icons.phone_rounded, size: 13, color: AppColors.primary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  renterPhone.isNotEmpty ? renterPhone : 'No phone recorded',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (renterPhone.isNotEmpty)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: renterPhone));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Copied $renterPhone to clipboard for transfer.'),
                                                backgroundColor: const Color(0xFF10B981),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            foregroundColor: const Color(0xFF10B981),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.copy_rounded, size: 13),
                                          label: const Text('Copy Phone / GCash', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  const Divider(height: 1),
                                  const SizedBox(height: 14),

                                  // QR Code & Account Details Section
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      if (activeQrUrl.isNotEmpty) ...[
                                        GestureDetector(
                                          onTap: () => _showRenterQrModal(
                                            dialogContext,
                                            qrUrl: activeQrUrl,
                                            renterName: renterName,
                                            provider: activeMethod.provider,
                                            accountNumber: activeMethod.accountNumber.isNotEmpty
                                                ? activeMethod.accountNumber
                                                : renterPhone,
                                          ),
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: 88,
                                                height: 88,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                                                ),
                                                padding: const EdgeInsets.all(4),
                                                child: Image.network(
                                                  activeQrUrl,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (ctx, err, stack) => const Center(
                                                    child: Icon(Icons.qr_code_2_rounded, size: 40, color: Colors.grey),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                right: 2,
                                                bottom: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                      ] else ...[
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.qr_code_2_rounded, size: 38, color: Color(0xFF10B981)),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${activeMethod.provider.toUpperCase()} LINKED ACCOUNT',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w900,
                                                      color: Color(0xFF10B981),
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              activeMethod.accountName.isNotEmpty
                                                  ? activeMethod.accountName
                                                  : renterName,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Account No: ${activeMethod.accountNumber.isNotEmpty ? activeMethod.accountNumber : (renterPhone.isNotEmpty ? renterPhone : "Not linked")}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                                              ),
                                            ),
                                            if (activeQrUrl.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              InkWell(
                                                onTap: () => _showRenterQrModal(
                                                  dialogContext,
                                                  qrUrl: activeQrUrl,
                                                  renterName: renterName,
                                                  provider: activeMethod.provider,
                                                  accountNumber: activeMethod.accountNumber.isNotEmpty
                                                      ? activeMethod.accountNumber
                                                      : renterPhone,
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: const [
                                                    Icon(Icons.qr_code_2_rounded, size: 14, color: Color(0xFF10B981)),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Tap to view / scan full QR code',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF10B981),
                                                        decoration: TextDecoration.underline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Refund Amount & Deduction Rows
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Deposit Collected (PHP)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: refundAmountController,
                                        keyboardType: TextInputType.number,
                                        readOnly: isAlreadyRefunded,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          prefixText: 'PHP ',
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Admin Policy: ${seats} Seater → PHP ${_formatCurrency(defaultSecurityDeposit, decimals: 0)} (4-5 Seater: PHP ${_formatCurrency(adminSettings.deposit4to5Seater, decimals: 0)} | 6+ Seater: PHP ${_formatCurrency(adminSettings.deposit6PlusSeater, decimals: 0)})',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Deduction from Deposit (PHP)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: deductionAmountController,
                                        keyboardType: TextInputType.number,
                                        readOnly: isAlreadyRefunded,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          prefixText: 'PHP ',
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (double.tryParse(deductionAmountController.text) != null &&
                                (double.tryParse(deductionAmountController.text) ?? 0) > 0) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Deduction Reason / Notes *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: deductionNotesController,
                                    readOnly: isAlreadyRefunded,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'e.g. Scratches on bumper, missing early warning device, carwash fee...',
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ],

                            // Net Refund Card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Net Refund to Renter:',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      Text(
                                        'Deposit (PHP ${_formatCurrency(deposit, decimals: 0)}) - Deduction (PHP ${_formatCurrency(deduction, decimals: 0)})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'PHP ${_formatCurrency(netRefund, decimals: 0)}',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Payment Method & Reference
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Refund Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        value: selectedMethod,
                                        dropdownColor: isDark ? const Color(0xFF1E2D44) : Colors.white,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                                          DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                                          DropdownMenuItem(value: 'Maya', child: Text('Maya')),
                                          DropdownMenuItem(value: 'PSDC Cash Counter', child: Text('PSDC Cash Counter')),
                                        ],
                                        onChanged: isAlreadyRefunded
                                            ? null
                                            : (val) {
                                                if (val != null) setDialogState(() => selectedMethod = val);
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Reference / Transaction No. (13-digit max)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: referenceController,
                                        keyboardType: TextInputType.number,
                                        maxLength: 13,
                                        readOnly: isAlreadyRefunded,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(13),
                                        ],
                                        decoration: InputDecoration(
                                          isDense: true,
                                          counterText: '',
                                          hintText: 'e.g. 1002349817283',
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Upload Receipt Section
                            Text(
                              isAlreadyRefunded ? 'Proof of Refund Receipt' : 'Proof of Refund Receipt (Required)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            if (isAlreadyRefunded)
                              Builder(
                                builder: (_) {
                                  final receiptUrl = booking['security_deposit_refund_receipt_url']?.toString();
                                  if (receiptUrl != null && receiptUrl.isNotEmpty) {
                                    return OutlinedButton.icon(
                                      onPressed: () => _showReceiptProofDialog(receiptUrl, isDark),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(46),
                                        side: const BorderSide(color: Color(0xFF10B981)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981)),
                                      label: const Text('View Deposit Refund Receipt Proof', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                                    );
                                  }
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'No receipt proof uploaded.',
                                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.black54),
                                    ),
                                  );
                                },
                              )
                            else if (receiptFile == null)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
                                    withData: true,
                                  );
                                  if (result != null && result.files.isNotEmpty) {
                                    setDialogState(() => receiptFile = result.files.first);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Attach GCash / Transfer Receipt'),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        receiptFile!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => setDialogState(() => receiptFile = null),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Remove receipt',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    if (dialogError != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                              child: Text(isAlreadyRefunded ? 'Close' : 'Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (isSubmitting || isAlreadyRefunded)
                                  ? null
                                  : () async {
                                      final ref = referenceController.text.trim();
                                      if (ref.isEmpty && receiptFile == null) {
                                        setDialogState(() => dialogError = 'Please provide a reference number or upload a receipt.');
                                        return;
                                      }
                                      if (ref.isNotEmpty && ref.length > 13) {
                                        setDialogState(() => dialogError = 'Transaction ID / Reference Number cannot exceed 13 digits.');
                                        return;
                                      }

                                      setDialogState(() {
                                        dialogError = null;
                                        isSubmitting = true;
                                      });

                                      try {
                                        String uploadedReceiptUrl = '';
                                        if (receiptFile?.bytes != null) {
                                          final currentUserId = _supabase.auth.currentUser?.id ?? '';
                                          uploadedReceiptUrl = await BookingInspectionService().uploadEvidenceBytes(
                                            userId: currentUserId,
                                            bookingId: bookingId,
                                            bytes: receiptFile!.bytes!,
                                            extension: receiptFile!.extension ?? 'jpg',
                                          );
                                        }

                                        final currentUserId = _supabase.auth.currentUser?.id ?? '';
                                        await BookingService().refundSecurityDeposit(
                                          bookingId: bookingId,
                                          refundAmount: netRefund,
                                          deductionAmount: deduction,
                                          deductionNotes: deductionNotesController.text.trim(),
                                          refundMethod: selectedMethod,
                                          refundReference: ref,
                                          refundReceiptUrl: uploadedReceiptUrl,
                                          operatorId: currentUserId,
                                        );

                                        booking['security_deposit_refunded'] = true;
                                        booking['security_deposit_refund_amount'] = netRefund;
                                        booking['security_deposit_refund_deduction'] = deduction;
                                        booking['partner_security_deposit_deduction'] = deduction;
                                        booking['security_deposit_status'] = 'refund_processed';
                                        booking['security_deposit_refund_notes'] = deductionNotesController.text.trim();
                                        booking['security_deposit_refund_method'] = selectedMethod;
                                        booking['security_deposit_refund_ref'] = ref;
                                        booking['security_deposit_refund_receipt_url'] = uploadedReceiptUrl;
                                        booking['security_deposit_refunded_at'] = DateTime.now().toIso8601String();
                                        booking['security_deposit_operator_reviewed_at'] = DateTime.now().toIso8601String();
                                        booking['security_deposit_operator_reviewed_by'] = currentUserId;

                                        final rIdx = _recentBookings.indexWhere((b) => b['id']?.toString() == bookingId);
                                        if (rIdx != -1) {
                                          _recentBookings[rIdx]['security_deposit_refunded'] = true;
                                          _recentBookings[rIdx]['security_deposit_refund_amount'] = netRefund;
                                          _recentBookings[rIdx]['security_deposit_refund_deduction'] = deduction;
                                          _recentBookings[rIdx]['partner_security_deposit_deduction'] = deduction;
                                          _recentBookings[rIdx]['security_deposit_status'] = 'refund_processed';
                                          _recentBookings[rIdx]['security_deposit_refund_notes'] = deductionNotesController.text.trim();
                                          _recentBookings[rIdx]['security_deposit_refund_method'] = selectedMethod;
                                          _recentBookings[rIdx]['security_deposit_refund_ref'] = ref;
                                          _recentBookings[rIdx]['security_deposit_refund_receipt_url'] = uploadedReceiptUrl;
                                          _recentBookings[rIdx]['security_deposit_refunded_at'] = DateTime.now().toIso8601String();
                                          _recentBookings[rIdx]['security_deposit_operator_reviewed_at'] = DateTime.now().toIso8601String();
                                          _recentBookings[rIdx]['security_deposit_operator_reviewed_by'] = currentUserId;
                                        }
                                        if (mounted) {
                                          setState(() {});
                                        }

                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                        _loadRecentBookings();
                                        _loadDashboardData(showLoading: false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Security deposit of PHP ${_formatCurrency(netRefund, decimals: 0)} refunded to $renterName successfully.',
                                              ),
                                              backgroundColor: const Color(0xFF10B981),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        final msg = e.toString().replaceAll('Exception:', '').trim();
                                        setDialogState(() {
                                          isSubmitting = false;
                                          dialogError = msg.contains('already been finalized')
                                              ? 'This transaction has already been finalized.'
                                              : 'Refund failed: $msg';
                                          if (msg.contains('already been finalized')) {
                                            isAlreadyRefunded = true;
                                            booking['security_deposit_refunded'] = true;
                                            booking['security_deposit_status'] = 'refund_processed';
                                          }
                                        });
                                        if (msg.contains('already been finalized')) {
                                          _loadRecentBookings();
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(46),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                    )
                                  : Text(
                                      isAlreadyRefunded
                                          ? 'Refund Already Completed'
                                          : 'Finalize & Release Refund (PHP ${_formatCurrency(netRefund, decimals: 0)})',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    refundAmountController.dispose();
    deductionAmountController.dispose();
    deductionNotesController.dispose();
    referenceController.dispose();
    });
  }

  Widget _buildWorkflowChip(
    String label, {
    required bool isDone,
    required bool isActive,
    required bool isDark,
  }) {
    Color bg;
    Color fg;
    Color border;
    IconData icon;

    if (isActive) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.2);
      fg = const Color(0xFF10B981);
      border = const Color(0xFF10B981);
      icon = Icons.radio_button_checked_rounded;
    } else if (isDone) {
      bg = const Color(0xFF0284C7).withValues(alpha: 0.12);
      fg = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
      border = const Color(0xFF0284C7).withValues(alpha: 0.4);
      icon = Icons.check_circle_rounded;
    } else {
      bg = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04);
      fg = isDark ? Colors.white38 : Colors.black38;
      border = isDark ? Colors.white12 : Colors.black12;
      icon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: isActive ? 1.5 : 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionMiniItem({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF0284C7)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStateBadge(Map<String, dynamic> booking) {
    final state = resolveBookingPaymentState(booking);
    final color = bookingPaymentStateColor(state);
    final label = bookingPaymentStateLabel(state);

    return Tooltip(
      message: 'Payment Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showVerifyPaymentProofDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    return ActionGuard.runGuarded('verify_payment_dialog_$bookingId', () async {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final renter = booking['renter'] as Map<String, dynamic>? ?? {};
      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final renterName = renter['full_name']?.toString() ?? 'Renter';
      final vehicleTitle = _vehicleTitle(vehicle.isNotEmpty ? vehicle : booking);
      final proofUrl = (booking['reservation_payment_proof_url'] ??
              booking['final_payment_proof_url'] ??
              booking['payment_proof_url'] ??
              booking['payment_receipt_url'] ??
              booking['proof_url'])
          ?.toString()
          .trim();
      final reference = (booking['reservation_payment_reference'] ??
              booking['final_payment_reference'] ??
              booking['payment_reference'])
          ?.toString()
          .trim();
      final totalAmount = _bookingAmount(booking);
      final notesController = TextEditingController();
      bool isSubmitting = false;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFF38BDF8),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Verify Renter Payment',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$renterName • $vehicleTitle',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary Cards
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Booking Amount', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : Colors.grey.shade600)),
                                        const SizedBox(height: 4),
                                        Text('PHP ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Reference Number', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : Colors.grey.shade600)),
                                        const SizedBox(height: 4),
                                        Text(
                                          reference != null && reference.isNotEmpty ? reference : 'N/A',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Receipt Preview
                            const Text('Uploaded Receipt / Transfer Proof', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            if (proofUrl != null && proofUrl.isNotEmpty)
                              Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: OnDemandNetworkImage(
                                          imageUrl: proofUrl,
                                          height: 220,
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                          label: 'Receipt Proof',
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Receipt Image', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                            TextButton.icon(
                                              onPressed: () => _showReceiptProofDialog(proofUrl, isDark),
                                              icon: const Icon(Icons.open_in_full_rounded, size: 14),
                                              label: const Text('View Full Image', style: TextStyle(fontSize: 11)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                ),
                                child: const Center(
                                  child: Text('No receipt image uploaded. Reference provided above.', style: TextStyle(fontSize: 12, color: Colors.amber)),
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Verification Notes
                            const Text('Verification Notes (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: notesController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'e.g., GCash ref verified in merchant portal',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      setDialogState(() => isSubmitting = true);
                                      try {
                                        await BookingService().verifyRenterReservationPayment(
                                          bookingId,
                                          notes: notesController.text.trim(),
                                        );
                                        booking['reservation_payment_status'] = 'verified';
                                        booking['payment_verified'] = true;
                                        final idx = _recentBookings.indexWhere((b) => b['id']?.toString() == bookingId);
                                        if (idx != -1) {
                                          _recentBookings[idx]['reservation_payment_status'] = 'verified';
                                          _recentBookings[idx]['payment_verified'] = true;
                                        }
                                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                                        _loadRecentBookings();
                                        _loadDashboardData(showLoading: false);
                                        if (context.mounted) {
                                          await _showActionFeedbackModal(
                                            title: 'Payment Verified',
                                            message: 'Payment verified successfully! Ready for final booking approval.',
                                            isError: false,
                                          );
                                        }
                                      } catch (e) {
                                        setDialogState(() => isSubmitting = false);
                                        if (context.mounted) {
                                          await _showActionFeedbackModal(
                                            title: 'Verification Failed',
                                            message: e.toString().replaceFirst('Exception: ', ''),
                                            isError: true,
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                              label: Text(
                                isSubmitting ? 'Verifying...' : 'Verify & Accept Payment',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      notesController.dispose();
    });
  }

  Future<void> _showBookingRefundDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    return ActionGuard.runGuarded('booking_refund_dialog_$bookingId', () async {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final renter = booking['renter'] as Map<String, dynamic>? ?? {};
      final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
      final renterName = renter['full_name']?.toString() ?? 'Renter';
      final renterPhone = renter['phone_number']?.toString() ?? renter['phone']?.toString() ?? booking['renter_phone']?.toString() ?? '';
      final vehicleTitle = _vehicleTitle(vehicle.isNotEmpty ? vehicle : booking);

      final renterUserId = (booking['renter_id'] ?? renter['id'] ?? renter['user_id'])?.toString();
      List<PayoutMethod> renterPayoutMethods = [];
      String? discoveredQrUrl;

      if (renterUserId != null && renterUserId.isNotEmpty) {
        try {
          renterPayoutMethods = await PayoutMethodService().getPayoutMethods(renterUserId);
        } catch (_) {}
        try {
          discoveredQrUrl = await PayoutMethodService().getRenterQrCodeUrl(renterUserId);
        } catch (_) {}
      }

      final directQrUrl = (discoveredQrUrl != null && discoveredQrUrl.isNotEmpty)
          ? discoveredQrUrl
          : (renter['qr_code_url']?.toString() ?? renter['gcash_qr_url']?.toString() ?? renter['payout_qr_url']?.toString() ?? booking['renter_qr_url']?.toString());

      // Pre-load refund details from booking_refunds table if not already on booking map
      if (booking['refund_ref'] == null || booking['refund_amount'] == null) {
        try {
          final refundRow = await _supabase
              .from('booking_refunds')
              .select('*')
              .eq('booking_id', bookingId)
              .maybeSingle();
          if (refundRow != null) {
            final isProcessed = refundRow['status'] == 'processed';
            if (isProcessed) {
              booking['refund_status'] = 'refunded';
              booking['refund_completed'] = true;
            }
            booking['refund_ref'] ??= refundRow['payment_reference'];
            final bAmount = (refundRow['amount'] as num?)?.toDouble();
            if (bAmount != null && bAmount > 0) {
              booking['refund_amount'] = bAmount;
            }
            booking['refund_notes'] ??= refundRow['reason'];
          }
        } catch (_) {}
      }

      final isAlreadyRefunded = booking['refund_status'] == 'refunded' || booking['refund_completed'] == true;
      final defaultRefundAmount = resolveBookingRefundAmount(booking);
      final paymentTypeLabel = resolveBookingPaymentTypeLabel(booking);

      final refundAmountController = TextEditingController(
        text: defaultRefundAmount.toStringAsFixed(2),
      );
      final referenceController = TextEditingController(
        text: booking['refund_ref']?.toString() ?? '',
      );
      final notesController = TextEditingController(
        text: booking['refund_notes']?.toString() ?? '',
      );
      String selectedMethod = booking['refund_method']?.toString() ?? (renterPayoutMethods.isNotEmpty ? renterPayoutMethods.first.provider : 'GCash');
      PlatformFile? receiptFile;
      bool isSubmitting = false;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final refundAmount = double.tryParse(refundAmountController.text) ?? defaultRefundAmount;

            final activeMethod = renterPayoutMethods.firstWhere(
              (m) => m.provider.toLowerCase() == selectedMethod.toLowerCase(),
              orElse: () => renterPayoutMethods.isNotEmpty
                  ? renterPayoutMethods.first
                  : PayoutMethod(
                      id: '',
                      provider: selectedMethod,
                      accountName: renterName,
                      accountNumber: renterPhone,
                      qrCodeUrl: directQrUrl,
                      createdAt: DateTime.now(),
                    ),
            );

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1B2638) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580, maxHeight: 820),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isAlreadyRefunded
                                  ? const Color(0xFFA855F7).withOpacity(0.15)
                                  : const Color(0xFFEF4444).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isAlreadyRefunded ? Icons.check_circle_rounded : Icons.currency_exchange_rounded,
                              color: isAlreadyRefunded ? const Color(0xFFA855F7) : const Color(0xFFEF4444),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAlreadyRefunded ? 'Booking Refund Details' : 'Process Booking Refund',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$renterName • $vehicleTitle',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Notice
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isAlreadyRefunded
                                    ? const Color(0xFFA855F7).withOpacity(0.12)
                                    : const Color(0xFFEF4444).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isAlreadyRefunded
                                      ? const Color(0xFFA855F7).withOpacity(0.35)
                                      : const Color(0xFFEF4444).withOpacity(0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isAlreadyRefunded ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                    color: isAlreadyRefunded ? const Color(0xFFA855F7) : const Color(0xFFEF4444),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isAlreadyRefunded
                                          ? 'Refund completed: PHP ${refundAmount.toStringAsFixed(2)} was disbursed to renter.'
                                          : 'This booking was rejected/cancelled after payment. Please disburse the refund to the renter below.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Payment Mode Breakdown Banner
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF162032) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? const Color(0xFF2E3E58) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    paymentTypeLabel == 'Full Payment' ? Icons.verified_rounded : Icons.receipt_outlined,
                                    size: 18,
                                    color: paymentTypeLabel == 'Full Payment' ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Renter Payment Mode: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    paymentTypeLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: paymentTypeLabel == 'Full Payment' ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Amount Paid: PHP ${defaultRefundAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Renter Payout Method Card (with QR code)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF101928) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Renter Payout Destination', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (activeMethod.qrCodeUrl != null && activeMethod.qrCodeUrl!.isNotEmpty)
                                        GestureDetector(
                                          onTap: () => _showReceiptProofDialog(activeMethod.qrCodeUrl!, isDark),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: OnDemandNetworkImage(
                                              imageUrl: activeMethod.qrCodeUrl!,
                                              width: 72,
                                              height: 72,
                                              fit: BoxFit.cover,
                                              label: 'QR Code',
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.account_balance_wallet_outlined, size: 28),
                                        ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              activeMethod.accountName.isNotEmpty ? activeMethod.accountName : renterName,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${activeMethod.provider}: ${activeMethod.accountNumber.isNotEmpty ? activeMethod.accountNumber : renterPhone}',
                                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey.shade700),
                                            ),
                                            if (activeMethod.qrCodeUrl != null && activeMethod.qrCodeUrl!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: () => _showReceiptProofDialog(activeMethod.qrCodeUrl!, isDark),
                                                child: const Text('Tap to view/scan QR code', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8), decoration: TextDecoration.underline)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Refund Amount field
                            const Text('Refund Amount (PHP)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: refundAmountController,
                              readOnly: isAlreadyRefunded,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                prefixText: 'PHP ',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Method & Reference
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Payout Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        value: selectedMethod,
                                        isDense: true,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        items: ['GCash', 'Maya', 'Bank Transfer', 'Cash']
                                            .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12))))
                                            .toList(),
                                        onChanged: isAlreadyRefunded ? null : (v) => setDialogState(() => selectedMethod = v ?? 'GCash'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Reference No. / Ref #', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: referenceController,
                                        readOnly: isAlreadyRefunded,
                                        decoration: InputDecoration(
                                          hintText: 'e.g. 1002345892',
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF263247) : const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Refund Receipt Proof
                            const Text('Refund Transfer Receipt / Screenshot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            if (isAlreadyRefunded)
                              Builder(
                                builder: (_) {
                                  final receipt = booking['refund_receipt_url']?.toString();
                                  if (receipt != null && receipt.isNotEmpty) {
                                    return OutlinedButton.icon(
                                      onPressed: () => _showReceiptProofDialog(receipt, isDark),
                                      icon: const Icon(Icons.receipt_long_rounded),
                                      label: const Text('View Refund Receipt Proof'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(44),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                  return const Text('No receipt proof attached.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic));
                                },
                              )
                            else if (receiptFile == null)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
                                    withData: true,
                                  );
                                  if (result != null && result.files.isNotEmpty) {
                                    setDialogState(() => receiptFile = result.files.first);
                                  }
                                },
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Upload Transfer Screenshot / Receipt'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(receiptFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16),
                                      onPressed: () => setDialogState(() => receiptFile = null),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                          if (!isAlreadyRefunded) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final ref = referenceController.text.trim();
                                        if (ref.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Please provide a reference number for the refund transfer.')),
                                          );
                                          return;
                                        }
                                        setDialogState(() => isSubmitting = true);
                                        try {
                                          String uploadedReceiptUrl = '';
                                          if (receiptFile?.bytes != null) {
                                            final currentUserId = _supabase.auth.currentUser?.id ?? '';
                                            uploadedReceiptUrl = await BookingInspectionService().uploadEvidenceBytes(
                                              userId: currentUserId,
                                              bookingId: bookingId,
                                              bytes: receiptFile!.bytes!,
                                              extension: receiptFile!.extension ?? 'jpg',
                                            );
                                          }

                                          await BookingService().settleBookingRefund(
                                            bookingId: bookingId,
                                            amount: refundAmount,
                                            method: selectedMethod,
                                            reference: ref,
                                            receiptUrl: uploadedReceiptUrl,
                                            notes: notesController.text.trim(),
                                          );

                                          booking['refund_status'] = 'refunded';
                                          booking['refund_completed'] = true;
                                          booking['refund_amount'] = refundAmount;
                                          booking['refund_ref'] = ref;
                                          booking['refund_method'] = selectedMethod;
                                          booking['refund_receipt_url'] = uploadedReceiptUrl;

                                          final idx = _recentBookings.indexWhere((b) => b['id']?.toString() == bookingId);
                                          if (idx != -1) {
                                            _recentBookings[idx]['refund_status'] = 'refunded';
                                            _recentBookings[idx]['refund_completed'] = true;
                                            _recentBookings[idx]['refund_amount'] = refundAmount;
                                            _recentBookings[idx]['refund_ref'] = ref;
                                            _recentBookings[idx]['refund_method'] = selectedMethod;
                                            _recentBookings[idx]['refund_receipt_url'] = uploadedReceiptUrl;
                                          }

                                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                                          _loadRecentBookings();
                                          _loadDashboardData(showLoading: false);
                                          if (context.mounted) {
                                            await _showActionFeedbackModal(
                                              title: 'Refund Recorded',
                                              message: 'Refund of PHP ${refundAmount.toStringAsFixed(2)} recorded successfully.',
                                              isError: false,
                                            );
                                          }
                                        } catch (e) {
                                          setDialogState(() => isSubmitting = false);
                                          if (context.mounted) {
                                            await _showActionFeedbackModal(
                                              title: 'Refund Failed',
                                              message: e.toString().replaceFirst('Exception: ', ''),
                                              isError: true,
                                            );
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                label: Text(
                                  isSubmitting ? 'Recording...' : 'Confirm & Complete Refund',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      refundAmountController.dispose();
      referenceController.dispose();
      notesController.dispose();
    });
  }

  Future<void> _showDisbursePartnerPayoutDialog(
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    return ActionGuard.runGuarded('disburse_partner_dialog_$bookingId', () async {
      final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicle = booking['vehicles'] as Map<String, dynamic>? ?? {};
    final partnerVehicle = booking['partner_vehicles'] as Map<String, dynamic>? ?? {};
    final partnerData = (partnerVehicle['partners'] ?? vehicle['partners'] ?? vehicle['owner']) as Map<String, dynamic>? ?? {};
    final partnerUserData = (partnerData['users'] ?? partnerData['user']) as Map<String, dynamic>? ?? {};

    final partnerUserId = (partnerUserData['id'] ?? partnerData['user_id'] ?? partnerVehicle['partner_id'] ?? vehicle['owner_id'] ?? booking['partner_id'] ?? booking['partner_user_id'])?.toString();
    final partnerName = partnerData['business_name']?.toString() ??
        partnerUserData['full_name']?.toString() ??
        partnerData['full_name']?.toString() ??
        'Partner Owner';
    final partnerPhone = partnerData['business_phone']?.toString() ??
        partnerUserData['phone']?.toString() ??
        partnerData['phone']?.toString() ??
        '';
    final vehicleName = _vehicleTitle(partnerVehicle.isNotEmpty ? partnerVehicle : vehicle);

    final rawRental = (booking['rental_subtotal'] as num?)?.toDouble() ??
        ((booking['total_price'] as num?)?.toDouble() ?? 0.0);
    final deliveryFee = (booking['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final lateFee = (booking['late_return_fee'] as num?)?.toDouble() ?? 0.0;
    final rentalSubtotal = (rawRental > 0 ? rawRental : ((booking['total_price'] as num?)?.toDouble() ?? 0.0)) + deliveryFee + lateFee;
    final commission = rentalSubtotal * 0.05;
    final partnerEarnings = (rentalSubtotal - commission).clamp(0.0, double.infinity);
    final depositDeduction = (booking['partner_security_deposit_deduction'] as num?)?.toDouble() ??
        ((booking['partner_payout_deposit_deduction'] as num?)?.toDouble() ??
        ((booking['security_deposit_refund_deduction'] as num?)?.toDouble() ?? 0.0));
    final netPayout = (partnerEarnings + depositDeduction).clamp(0.0, double.infinity);

    bool isAlreadyDisbursed = booking['partner_payout_disbursed'] == true ||
        booking['partner_payout_status']?.toString().toLowerCase() == 'disbursed';
    double? pastPayoutAmount = (booking['partner_payout_amount'] as num?)?.toDouble();
    String pastRef = booking['partner_payout_ref']?.toString() ?? '';
    String? pastMethod = booking['partner_payout_method']?.toString();

    if (!isAlreadyDisbursed && bookingId.isNotEmpty) {
      try {
        final existingPayout = await _supabase
            .from('booking_payouts')
            .select('*')
            .eq('booking_id', bookingId)
            .eq('recipient_role', 'partner')
            .eq('status', 'released')
            .maybeSingle();
        if (existingPayout != null) {
          isAlreadyDisbursed = true;
          booking['partner_payout_disbursed'] = true;
          booking['partner_payout_status'] = 'disbursed';
          pastPayoutAmount = (existingPayout['net_amount'] as num?)?.toDouble() ??
              (existingPayout['gross_amount'] as num?)?.toDouble();
          booking['partner_payout_amount'] = pastPayoutAmount;
          booking['partner_payout_commission'] = (existingPayout['deductions'] as num?)?.toDouble();
          final meta = existingPayout['metadata'] is Map ? Map<String, dynamic>.from(existingPayout['metadata']) : <String, dynamic>{};
          pastMethod = meta['payment_method']?.toString() ?? existingPayout['payout_method']?.toString() ?? 'GCash';
          pastRef = meta['reference_number']?.toString() ?? existingPayout['reference_number']?.toString() ?? '';
          booking['partner_payout_method'] = pastMethod;
          booking['partner_payout_ref'] = pastRef;
          booking['partner_payout_receipt_url'] = meta['receipt_url']?.toString() ?? existingPayout['receipt_url']?.toString() ?? '';
          booking['partner_payout_disbursed_at'] = existingPayout['released_at']?.toString() ?? existingPayout['created_at']?.toString();
        }
      } catch (e) {
        debugPrint('Could not check booking_payouts for partner: $e');
      }
    }

    final payoutAmountController = TextEditingController(
      text: (isAlreadyDisbursed && pastPayoutAmount != null)
          ? pastPayoutAmount.toStringAsFixed(2)
          : netPayout.toStringAsFixed(2),
    );
    final referenceController = TextEditingController(
      text: isAlreadyDisbursed ? pastRef : '',
    );
    String selectedMethod = (isAlreadyDisbursed && pastMethod != null && pastMethod.isNotEmpty)
        ? pastMethod
        : 'GCash';
    PlatformFile? receiptFile;
    bool isSubmitting = false;
    String? dialogError;

    // Load registered payout methods & QR code
    List<PayoutMethod> registeredMethods = [];
    String? discoveredQrUrl;
    if (partnerUserId != null && partnerUserId.isNotEmpty) {
      try {
        registeredMethods = await PayoutMethodService().getPayoutMethods(partnerUserId);
        if (registeredMethods.isNotEmpty && !isAlreadyDisbursed) {
          selectedMethod = registeredMethods.first.provider;
        }
      } catch (e) {
        debugPrint('Could not load partner payout methods: $e');
      }
      try {
        discoveredQrUrl = await PayoutMethodService().getUserPayoutQrUrl(partnerUserId);
      } catch (_) {}
    }

    String? methodQrUrl;
    for (final m in registeredMethods) {
      if (m.qrCodeUrl != null && m.qrCodeUrl!.isNotEmpty) {
        methodQrUrl = m.qrCodeUrl;
        break;
      }
    }
    final activeQrUrl = (discoveredQrUrl != null && discoveredQrUrl.isNotEmpty)
        ? discoveredQrUrl
        : (methodQrUrl ??
           partnerData['qr_code_url']?.toString() ??
           partnerData['gcash_qr_url']?.toString() ??
           partnerData['payout_qr_url']?.toString() ??
           booking['partner_qr_url']?.toString() ??
           booking['partner_payout_receipt_url']?.toString());

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final effectiveNet = double.tryParse(payoutAmountController.text) ?? netPayout;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF172235) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.12),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.purple.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.payments_outlined,
                              color: Colors.purpleAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Disburse Partner Commission / Payout',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$vehicleName • Booking #${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isAlreadyDisbursed) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.purpleAccent),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.purpleAccent, size: 22),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Partner Commission Disburse Completed: Earnings for this booking have already been disbursed.',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.purpleAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Partner Info & Payout Method Card (with QR thumbnail)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2D44) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2C3E5A) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (activeQrUrl != null && activeQrUrl.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => _showReceiptProofDialog(activeQrUrl, isDark),
                                      child: Tooltip(
                                        message: 'Click to enlarge QR code',
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Stack(
                                            children: [
                                              OnDemandNetworkImage(
                                                imageUrl: activeQrUrl,
                                                width: 68,
                                                height: 68,
                                                fit: BoxFit.cover,
                                                label: 'QR Code',
                                              ),
                                              Positioned(
                                                right: 2,
                                                bottom: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.65),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.purple.withValues(alpha: 0.2),
                                      child: const Icon(Icons.handshake_outlined, color: Colors.purpleAccent),
                                    ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          partnerName,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                        ),
                                        const SizedBox(height: 3),
                                        if (registeredMethods.isNotEmpty)
                                          Text(
                                            '${registeredMethods.first.provider}: ${registeredMethods.first.accountNumber} (${registeredMethods.first.accountName})',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.purple[200] : Colors.purple[800],
                                            ),
                                          )
                                        else if (partnerPhone.isNotEmpty)
                                          Text(
                                            'Phone / GCash: $partnerPhone',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                                            ),
                                          )
                                        else
                                          const Text(
                                            'No registered payout method',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        if (activeQrUrl != null && activeQrUrl.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          InkWell(
                                            onTap: () => _showReceiptProofDialog(activeQrUrl, isDark),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.qr_code_rounded, size: 14, color: Colors.purpleAccent),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'View Attached QR Code',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.purple[200] : Colors.purple[800],
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (registeredMethods.isNotEmpty || partnerPhone.isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        final target = registeredMethods.isNotEmpty
                                            ? registeredMethods.first.accountNumber
                                            : partnerPhone;
                                        Clipboard.setData(ClipboardData(text: target));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Copied $target to clipboard.'),
                                            backgroundColor: Colors.purple,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple.withValues(alpha: 0.15),
                                        foregroundColor: Colors.purpleAccent,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.copy_rounded, size: 14),
                                      label: const Text('Copy Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Revenue Breakdown Table
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Rental Total (Gross + Fees)', style: TextStyle(fontSize: 12)),
                                      Text('PHP ${_formatCurrency(rentalSubtotal)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('PSDC Platform Commission (5%)', style: TextStyle(fontSize: 12, color: Colors.orange)),
                                      Text('- PHP ${_formatCurrency(commission)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Partner Earnings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      Text('PHP ${_formatCurrency(partnerEarnings)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('Security Deposit Deduction (Damage Compensation)', style: TextStyle(fontSize: 12)),
                                          const SizedBox(width: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: depositDeduction > 0
                                                  ? Colors.green.withValues(alpha: 0.15)
                                                  : Colors.grey.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              depositDeduction > 0 ? '+ Added' : 'None',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: depositDeduction > 0 ? Colors.greenAccent : Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '+ PHP ${_formatCurrency(depositDeduction)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: depositDeduction > 0 ? Colors.greenAccent : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Final Partner Disbursement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                      Text(
                                        'PHP ${_formatCurrency(netPayout)}',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.purpleAccent),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Payment Method & Reference
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Disbursement Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        value: selectedMethod,
                                        dropdownColor: isDark ? const Color(0xFF1E2D44) : Colors.white,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                                          DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                                          DropdownMenuItem(value: 'Maya', child: Text('Maya')),
                                          DropdownMenuItem(value: 'PSDC Cash Counter', child: Text('PSDC Cash Counter')),
                                        ],
                                        onChanged: isAlreadyDisbursed
                                            ? null
                                            : (val) {
                                                if (val != null) setDialogState(() => selectedMethod = val);
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Reference / Transaction No. (13-digit max)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: referenceController,
                                        keyboardType: TextInputType.number,
                                        maxLength: 13,
                                        readOnly: isAlreadyDisbursed,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(13),
                                        ],
                                        decoration: InputDecoration(
                                          isDense: true,
                                          counterText: '',
                                          hintText: 'e.g. 2004918239012',
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Upload Receipt Section
                            Text(
                              isAlreadyDisbursed ? 'Proof of Disbursement' : 'Proof of Disbursement (Receipt / Screenshot)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            if (isAlreadyDisbursed)
                              Builder(
                                builder: (_) {
                                  final receiptUrl = booking['partner_payout_receipt_url']?.toString();
                                  if (receiptUrl != null && receiptUrl.isNotEmpty) {
                                    return OutlinedButton.icon(
                                      onPressed: () => _showReceiptProofDialog(receiptUrl, isDark),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(46),
                                        side: const BorderSide(color: Colors.purpleAccent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.receipt_long_rounded, color: Colors.purpleAccent),
                                      label: const Text('View Partner Payout Receipt Proof', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.purpleAccent)),
                                    );
                                  }
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'No receipt proof uploaded.',
                                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.black54),
                                    ),
                                  );
                                },
                              )
                            else if (receiptFile == null)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
                                    withData: true,
                                  );
                                  if (result != null && result.files.isNotEmpty) {
                                    setDialogState(() => receiptFile = result.files.first);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Attach GCash / Transfer Receipt'),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.receipt_long_rounded, color: Colors.purpleAccent),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        receiptFile!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => setDialogState(() => receiptFile = null),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Remove receipt',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    if (dialogError != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                              child: Text(isAlreadyDisbursed ? 'Close' : 'Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (isSubmitting || isAlreadyDisbursed)
                                  ? null
                                  : () async {
                                      final ref = referenceController.text.trim();
                                      if (ref.isEmpty && receiptFile == null) {
                                        setDialogState(() => dialogError = 'Please provide a reference number or upload a receipt.');
                                        return;
                                      }
                                      if (ref.isNotEmpty && ref.length > 13) {
                                        setDialogState(() => dialogError = 'Transaction ID / Reference Number cannot exceed 13 digits.');
                                        return;
                                      }

                                      setDialogState(() {
                                        dialogError = null;
                                        isSubmitting = true;
                                      });

                                      try {
                                        String uploadedReceiptUrl = '';
                                        if (receiptFile?.bytes != null) {
                                          final currentUserId = _supabase.auth.currentUser?.id ?? '';
                                          uploadedReceiptUrl = await BookingInspectionService().uploadEvidenceBytes(
                                            userId: currentUserId,
                                            bookingId: bookingId,
                                            bytes: receiptFile!.bytes!,
                                            extension: receiptFile!.extension ?? 'jpg',
                                          );
                                        }

                                        final currentUserId = _supabase.auth.currentUser?.id ?? '';
                                        await BookingService().disbursePartnerCommission(
                                          bookingId: bookingId,
                                          operatorId: currentUserId,
                                          paymentMethod: selectedMethod,
                                          referenceNumber: ref,
                                          receiptUrl: uploadedReceiptUrl,
                                          netAmount: effectiveNet,
                                          commissionAmount: commission,
                                          securityDepositDeduction: depositDeduction,
                                          partnerUserId: partnerUserId,
                                          vehicleTitle: vehicleName,
                                        );

                                        booking['partner_payout_disbursed'] = true;
                                        booking['partner_payout_status'] = 'disbursed';
                                        booking['partner_payout_amount'] = effectiveNet;
                                        booking['partner_payout_commission'] = commission;
                                        booking['partner_payout_deposit_deduction'] = depositDeduction;
                                        booking['partner_security_deposit_deduction'] = depositDeduction;
                                        booking['partner_payout_method'] = selectedMethod;
                                        booking['partner_payout_ref'] = ref;
                                        booking['partner_payout_receipt_url'] = uploadedReceiptUrl;
                                        booking['partner_payout_disbursed_at'] = DateTime.now().toIso8601String();

                                        final pIdx = _recentBookings.indexWhere((b) => b['id']?.toString() == bookingId);
                                        if (pIdx != -1) {
                                          _recentBookings[pIdx]['partner_payout_disbursed'] = true;
                                          _recentBookings[pIdx]['partner_payout_status'] = 'disbursed';
                                          _recentBookings[pIdx]['partner_payout_amount'] = effectiveNet;
                                          _recentBookings[pIdx]['partner_payout_commission'] = commission;
                                          _recentBookings[pIdx]['partner_payout_deposit_deduction'] = depositDeduction;
                                          _recentBookings[pIdx]['partner_security_deposit_deduction'] = depositDeduction;
                                          _recentBookings[pIdx]['partner_payout_method'] = selectedMethod;
                                          _recentBookings[pIdx]['partner_payout_ref'] = ref;
                                          _recentBookings[pIdx]['partner_payout_receipt_url'] = uploadedReceiptUrl;
                                          _recentBookings[pIdx]['partner_payout_disbursed_at'] = DateTime.now().toIso8601String();
                                        }
                                        setDialogState(() {
                                          isAlreadyDisbursed = true;
                                          isSubmitting = false;
                                        });
                                        if (mounted) {
                                          setState(() {});
                                        }

                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                        _loadRecentBookings();
                                        _loadDashboardData(showLoading: false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Partner payout of PHP ${_formatCurrency(effectiveNet)} disbursed to $partnerName successfully.',
                                              ),
                                              backgroundColor: Colors.purple,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        final msg = e.toString().replaceAll('Exception:', '').trim();
                                        setDialogState(() {
                                          isSubmitting = false;
                                          dialogError = msg.contains('already been finalized')
                                              ? 'This transaction has already been finalized.'
                                              : 'Failed to disburse partner payout: $msg';
                                          if (msg.contains('already been finalized')) {
                                            isAlreadyDisbursed = true;
                                            booking['partner_payout_disbursed'] = true;
                                            booking['partner_payout_status'] = 'disbursed';
                                          }
                                        });
                                        if (msg.contains('already been finalized')) {
                                          _loadRecentBookings();
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade600,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                                disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade600,
                                minimumSize: const Size.fromHeight(46),
                              ),
                              child: isAlreadyDisbursed
                                  ? const Text('Partner Disbursed ✓', style: TextStyle(fontWeight: FontWeight.w700))
                                  : (isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text('Confirm & Disburse Payout', style: TextStyle(fontWeight: FontWeight.w700))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    payoutAmountController.dispose();
    referenceController.dispose();
    });
  }

  Future<void> _showDisburseDriverPayoutDialog(
    Map<String, dynamic> booking,
  ) async {
    final bookingId = booking['id']?.toString() ?? '';
    return ActionGuard.runGuarded('disburse_driver_dialog_$bookingId', () async {
      final isDark = Theme.of(context).brightness == Brightness.dark;
    final driverData = booking['driver'] as Map<String, dynamic>? ?? {};
    final driverUserData = (driverData['users'] ?? driverData['user']) as Map<String, dynamic>? ?? {};
    final driverUserJoined = (booking['driver_user'] ?? booking['driver_profile']) as Map<String, dynamic>? ?? {};

    final driverUserId = (driverUserData['id'] ??
            driverData['user_id'] ??
            driverUserJoined['id'] ??
            booking['driver_id'])
        ?.toString();
    final driverName = driverUserData['full_name']?.toString() ??
        driverUserJoined['full_name']?.toString() ??
        driverData['full_name']?.toString() ??
        booking['driver_name']?.toString() ??
        'Assigned Driver';
    final driverPhone = driverUserData['phone']?.toString() ??
        driverUserJoined['phone']?.toString() ??
        driverData['phone']?.toString() ??
        '';

    final latestAssignment = _latestDriverAssignment(booking);
    double driverGross = (booking['driver_fee'] as num?)?.toDouble() ??
        (latestAssignment?['trip_fee'] as num?)?.toDouble() ??
        0.0;
    if (driverGross <= 0) {
      final start = DateTime.tryParse((booking['start_at'] ?? booking['start_date'])?.toString() ?? '');
      final end = DateTime.tryParse((booking['end_at'] ?? booking['end_date'])?.toString() ?? '');
      int days = 1;
      if (start != null && end != null && end.isAfter(start)) {
        days = (end.difference(start).inMinutes / Duration.minutesPerDay).ceil();
        if (days <= 0) days = 1;
      }
      driverGross = days * PricingPolicy.driverDailyRate;
    }
    final commission = driverGross * 0.05;
    final netPayout = (driverGross - commission).clamp(0.0, double.infinity);

    bool isAlreadyDisbursed = booking['driver_payout_disbursed'] == true ||
        booking['driver_payout_status']?.toString().toLowerCase() == 'disbursed';
    double? pastPayoutAmount = (booking['driver_payout_amount'] as num?)?.toDouble();
    String pastRef = booking['driver_payout_ref']?.toString() ?? '';
    String? pastMethod = booking['driver_payout_method']?.toString();

    if (!isAlreadyDisbursed && bookingId.isNotEmpty) {
      try {
        final existingPayout = await _supabase
            .from('booking_payouts')
            .select('*')
            .eq('booking_id', bookingId)
            .eq('recipient_role', 'driver')
            .eq('status', 'released')
            .maybeSingle();
        if (existingPayout != null) {
          isAlreadyDisbursed = true;
          booking['driver_payout_disbursed'] = true;
          booking['driver_payout_status'] = 'disbursed';
          pastPayoutAmount = (existingPayout['net_amount'] as num?)?.toDouble() ??
              (existingPayout['gross_amount'] as num?)?.toDouble();
          booking['driver_payout_amount'] = pastPayoutAmount;
          booking['driver_payout_commission'] = (existingPayout['deductions'] as num?)?.toDouble();
          final meta = existingPayout['metadata'] is Map ? Map<String, dynamic>.from(existingPayout['metadata']) : <String, dynamic>{};
          pastMethod = meta['payment_method']?.toString() ?? existingPayout['payout_method']?.toString() ?? 'GCash';
          pastRef = meta['reference_number']?.toString() ?? existingPayout['reference_number']?.toString() ?? '';
          booking['driver_payout_method'] = pastMethod;
          booking['driver_payout_ref'] = pastRef;
          booking['driver_payout_receipt_url'] = meta['receipt_url']?.toString() ?? existingPayout['receipt_url']?.toString() ?? '';
          booking['driver_payout_disbursed_at'] = existingPayout['released_at']?.toString() ?? existingPayout['created_at']?.toString();
        }
      } catch (e) {
        debugPrint('Could not check booking_payouts for driver: $e');
      }
    }

    final payoutAmountController = TextEditingController(
      text: (isAlreadyDisbursed && pastPayoutAmount != null)
          ? pastPayoutAmount.toStringAsFixed(2)
          : netPayout.toStringAsFixed(2),
    );
    final referenceController = TextEditingController(
      text: isAlreadyDisbursed ? pastRef : '',
    );
    String selectedMethod = (isAlreadyDisbursed && pastMethod != null && pastMethod.isNotEmpty)
        ? pastMethod
        : 'GCash';
    PlatformFile? receiptFile;
    bool isSubmitting = false;
    String? dialogError;

    // Load registered payout methods & QR code
    List<PayoutMethod> registeredMethods = [];
    String? discoveredQrUrl;
    if (driverUserId != null && driverUserId.isNotEmpty && !isAlreadyDisbursed) {
      try {
        registeredMethods = await PayoutMethodService().getPayoutMethods(driverUserId);
        if (registeredMethods.isNotEmpty) {
          selectedMethod = registeredMethods.first.provider;
        }
      } catch (e) {
        debugPrint('Could not load driver payout methods: $e');
      }
      try {
        discoveredQrUrl = await PayoutMethodService().getUserPayoutQrUrl(driverUserId);
      } catch (_) {}
    }

    String? methodQrUrl;
    for (final m in registeredMethods) {
      if (m.qrCodeUrl != null && m.qrCodeUrl!.isNotEmpty) {
        methodQrUrl = m.qrCodeUrl;
        break;
      }
    }
    final activeQrUrl = (discoveredQrUrl != null && discoveredQrUrl.isNotEmpty)
        ? discoveredQrUrl
        : (methodQrUrl ??
           driverData['qr_code_url']?.toString() ??
           driverData['gcash_qr_url']?.toString() ??
           driverData['payout_qr_url']?.toString() ??
           booking['driver_qr_url']?.toString() ??
           booking['driver_payout_receipt_url']?.toString());

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final effectiveNet = double.tryParse(payoutAmountController.text) ?? netPayout;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF172235) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.paid_outlined,
                              color: Color(0xFF0284C7),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Disburse Driver Fee / Payout',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Driver: $driverName • Booking #${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isAlreadyDisbursed) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF38BDF8)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 22),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Driver Trip Fee Disburse Completed: Driver fee for this booking has already been disbursed.',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF38BDF8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Driver Info & Payout Method Card (with QR thumbnail)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2D44) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2C3E5A) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (activeQrUrl != null && activeQrUrl.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => _showReceiptProofDialog(activeQrUrl, isDark),
                                      child: Tooltip(
                                        message: 'Click to enlarge QR code',
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Stack(
                                            children: [
                                              OnDemandNetworkImage(
                                                imageUrl: activeQrUrl,
                                                width: 68,
                                                height: 68,
                                                fit: BoxFit.cover,
                                                label: 'QR Code',
                                              ),
                                              Positioned(
                                                right: 2,
                                                bottom: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.65),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                      child: const Icon(Icons.drive_eta_rounded, color: Color(0xFF0284C7)),
                                    ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driverName,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                        ),
                                        const SizedBox(height: 3),
                                        if (registeredMethods.isNotEmpty)
                                          Text(
                                            '${registeredMethods.first.provider}: ${registeredMethods.first.accountNumber} (${registeredMethods.first.accountName})',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF38BDF8),
                                            ),
                                          )
                                        else if (driverPhone.isNotEmpty)
                                          Text(
                                            'Phone / GCash: $driverPhone',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                                            ),
                                          )
                                        else
                                          const Text(
                                            'No registered payout method',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        if (activeQrUrl != null && activeQrUrl.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          InkWell(
                                            onTap: () => _showReceiptProofDialog(activeQrUrl, isDark),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.qr_code_rounded, size: 14, color: Color(0xFF38BDF8)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'View Attached QR Code',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (registeredMethods.isNotEmpty || driverPhone.isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        final target = registeredMethods.isNotEmpty
                                            ? registeredMethods.first.accountNumber
                                            : driverPhone;
                                        Clipboard.setData(ClipboardData(text: target));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Copied $target to clipboard.'),
                                            backgroundColor: const Color(0xFF0284C7),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                        foregroundColor: const Color(0xFF38BDF8),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.copy_rounded, size: 14),
                                      label: const Text('Copy Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Revenue Breakdown Table
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Driver Gross Fee', style: TextStyle(fontSize: 12)),
                                      Text('PHP ${_formatCurrency(driverGross)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('PSDC Platform Commission (5%)', style: TextStyle(fontSize: 12, color: Colors.orange)),
                                      Text('- PHP ${_formatCurrency(commission)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange)),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Net Payout to Driver (95%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                      Text(
                                        'PHP ${_formatCurrency(netPayout)}',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Payment Method & Reference
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Disbursement Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        value: selectedMethod,
                                        dropdownColor: isDark ? const Color(0xFF1E2D44) : Colors.white,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                                          DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                                          DropdownMenuItem(value: 'Maya', child: Text('Maya')),
                                          DropdownMenuItem(value: 'PSDC Cash Counter', child: Text('PSDC Cash Counter')),
                                        ],
                                        onChanged: isAlreadyDisbursed
                                            ? null
                                            : (val) {
                                                if (val != null) setDialogState(() => selectedMethod = val);
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Reference / Transaction No. (13-digit max)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: referenceController,
                                        keyboardType: TextInputType.number,
                                        maxLength: 13,
                                        readOnly: isAlreadyDisbursed,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(13),
                                        ],
                                        decoration: InputDecoration(
                                          isDense: true,
                                          counterText: '',
                                          hintText: 'e.g. 3009218273849',
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Upload Receipt Section
                            Text(
                              isAlreadyDisbursed ? 'Proof of Disbursement' : 'Proof of Disbursement (Receipt / Screenshot)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            if (isAlreadyDisbursed)
                              Builder(
                                builder: (_) {
                                  final receiptUrl = booking['driver_payout_receipt_url']?.toString();
                                  if (receiptUrl != null && receiptUrl.isNotEmpty) {
                                    return OutlinedButton.icon(
                                      onPressed: () => _showReceiptProofDialog(receiptUrl, isDark),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(46),
                                        side: const BorderSide(color: Color(0xFF0284C7)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7)),
                                      label: const Text('View Driver Fee Receipt Proof', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0284C7))),
                                    );
                                  }
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF101A29) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'No receipt proof uploaded.',
                                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.black54),
                                    ),
                                  );
                                },
                              )
                            else if (receiptFile == null)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
                                    withData: true,
                                  );
                                  if (result != null && result.files.isNotEmpty) {
                                    setDialogState(() => receiptFile = result.files.first);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Attach GCash / Transfer Receipt'),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        receiptFile!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => setDialogState(() => receiptFile = null),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Remove receipt',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    if (dialogError != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                              child: Text(isAlreadyDisbursed ? 'Close' : 'Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (isSubmitting || isAlreadyDisbursed)
                                  ? null
                                  : () async {
                                      final ref = referenceController.text.trim();
                                      if (ref.isEmpty && receiptFile == null) {
                                        setDialogState(() => dialogError = 'Please provide a reference number or upload a receipt.');
                                        return;
                                      }
                                      if (ref.isNotEmpty && ref.length > 13) {
                                        setDialogState(() => dialogError = 'Transaction ID / Reference Number cannot exceed 13 digits.');
                                        return;
                                      }

                                      setDialogState(() {
                                        dialogError = null;
                                        isSubmitting = true;
                                      });

                                      try {
                                        String uploadedReceiptUrl = '';
                                        if (receiptFile?.bytes != null) {
                                          final currentUserId = _supabase.auth.currentUser?.id ?? '';
                                          uploadedReceiptUrl = await BookingInspectionService().uploadEvidenceBytes(
                                            userId: currentUserId,
                                            bookingId: bookingId,
                                            bytes: receiptFile!.bytes!,
                                            extension: receiptFile!.extension ?? 'jpg',
                                          );
                                        }

                                        final currentUserId = _supabase.auth.currentUser?.id ?? '';
                                        await BookingService().disburseDriverCommission(
                                          bookingId: bookingId,
                                          operatorId: currentUserId,
                                          paymentMethod: selectedMethod,
                                          referenceNumber: ref,
                                          receiptUrl: uploadedReceiptUrl,
                                          netAmount: effectiveNet,
                                          commissionAmount: commission,
                                          driverUserId: driverUserId,
                                        );

                                        booking['driver_payout_disbursed'] = true;
                                        booking['driver_payout_status'] = 'disbursed';
                                        booking['driver_payout_amount'] = effectiveNet;
                                        booking['driver_payout_commission'] = commission;
                                        booking['driver_payout_method'] = selectedMethod;
                                        booking['driver_payout_ref'] = ref;
                                        booking['driver_payout_receipt_url'] = uploadedReceiptUrl;
                                        booking['driver_payout_disbursed_at'] = DateTime.now().toIso8601String();

                                        final dIdx = _recentBookings.indexWhere((b) => b['id']?.toString() == bookingId);
                                        if (dIdx != -1) {
                                          _recentBookings[dIdx]['driver_payout_disbursed'] = true;
                                          _recentBookings[dIdx]['driver_payout_status'] = 'disbursed';
                                          _recentBookings[dIdx]['driver_payout_amount'] = effectiveNet;
                                          _recentBookings[dIdx]['driver_payout_commission'] = commission;
                                          _recentBookings[dIdx]['driver_payout_method'] = selectedMethod;
                                          _recentBookings[dIdx]['driver_payout_ref'] = ref;
                                          _recentBookings[dIdx]['driver_payout_receipt_url'] = uploadedReceiptUrl;
                                          _recentBookings[dIdx]['driver_payout_disbursed_at'] = DateTime.now().toIso8601String();
                                        }
                                        setDialogState(() {
                                          isAlreadyDisbursed = true;
                                          isSubmitting = false;
                                        });
                                        if (mounted) {
                                          setState(() {});
                                        }

                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                        _loadRecentBookings();
                                        _loadDashboardData(showLoading: false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Driver payout of PHP ${_formatCurrency(effectiveNet)} disbursed to $driverName successfully.',
                                              ),
                                              backgroundColor: const Color(0xFF0284C7),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        final msg = e.toString().replaceAll('Exception:', '').trim();
                                        setDialogState(() {
                                          isSubmitting = false;
                                          dialogError = msg.contains('already been finalized')
                                              ? 'This transaction has already been finalized.'
                                              : 'Failed to disburse driver payout: $msg';
                                          if (msg.contains('already been finalized')) {
                                            isAlreadyDisbursed = true;
                                            booking['driver_payout_disbursed'] = true;
                                            booking['driver_payout_status'] = 'disbursed';
                                          }
                                        });
                                        if (msg.contains('already been finalized')) {
                                          _loadRecentBookings();
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                                disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade600,
                                minimumSize: const Size.fromHeight(46),
                              ),
                              child: isAlreadyDisbursed
                                  ? const Text('Driver Fee Disbursed ✓', style: TextStyle(fontWeight: FontWeight.w700))
                                  : (isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text('Confirm & Disburse Payout', style: TextStyle(fontWeight: FontWeight.w700))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    payoutAmountController.dispose();
    referenceController.dispose();
    });
  }

  Future<void> _showBookingSafetyReviewDialog(
    Map<String, dynamic> booking,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final evidence = [
      MapEntry(
        'Signature image',
        booking['renter_signature_url']?.toString() ?? '',
      ),
      MapEntry('Valid ID', booking['renter_valid_id_url']?.toString() ?? ''),
      MapEntry('Selfie', booking['renter_selfie_url']?.toString() ?? ''),
      MapEntry(
        'Co-traveler signature image',
        booking['co_traveler_signature_url']?.toString() ?? '',
      ),
      MapEntry(
        'Co-traveler valid ID',
        booking['co_traveler_valid_id_url']?.toString() ?? '',
      ),
      MapEntry(
        'Co-traveler selfie',
        booking['co_traveler_selfie_url']?.toString() ?? '',
      ),
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: const Text('Renter Safety Review'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewLine(
                  'Digital signature',
                  booking['renter_signature_text']?.toString(),
                ),
                _buildReviewLine(
                  'Emergency contact',
                  [
                        booking['emergency_contact_name']?.toString(),
                        booking['emergency_contact_relationship']?.toString(),
                        booking['emergency_contact_phone']?.toString(),
                      ]
                      .where((part) => part != null && part.trim().isNotEmpty)
                      .join(' - '),
                ),
                _buildReviewLine(
                  'Co-traveler',
                  [
                        booking['co_traveler_name']?.toString(),
                        booking['co_traveler_phone']?.toString(),
                      ]
                      .where((part) => part != null && part.trim().isNotEmpty)
                      .join(' - '),
                ),
                _buildReviewLine(
                  'Co-traveler license',
                  booking['co_traveler_license']?.toString(),
                ),
                _buildReviewLine(
                  'Co-traveler signature',
                  booking['co_traveler_signature_text']?.toString(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Uploaded files',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...evidence.map((item) {
                  final url = item.value.trim();
                  final bucket = _storageBucketFromUrl(url);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: url.isEmpty
                          ? null
                          : () => _openEvidenceUrl(url),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        url.isEmpty
                            ? '${item.key}: missing'
                            : bucket == null
                            ? item.key
                            : '${item.key} ($bucket)',
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                DialogStatusIndicator(
                  compact: true,
                  isComplete: evidence.every(
                    (item) => item.value.trim().isNotEmpty,
                  ),
                  completeLabel: 'Required evidence complete',
                  incompleteLabel: 'Required evidence incomplete',
                  completeDetail: 'All safety files are available for review.',
                  incompleteDetail:
                      'One or more required safety files are missing.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEvidenceUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showErrorSnackBar('Invalid uploaded file link');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showErrorSnackBar(
        'Could not open uploaded file. Check that the storage bucket exists and the file was uploaded.',
      );
    }
  }

  String? _storageBucketFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final publicIndex = segments.indexOf('public');
    if (publicIndex >= 0 && publicIndex + 1 < segments.length) {
      return segments[publicIndex + 1];
    }

    final signIndex = segments.indexOf('sign');
    if (signIndex >= 0 && signIndex + 1 < segments.length) {
      return segments[signIndex + 1];
    }

    return null;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Widget _buildReviewLine(String label, String? value) {
    final clean = value?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              clean == null || clean.isEmpty ? 'Not provided' : clean,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showReleasePaymentSettlementDialog(
    BuildContext context,
    Map<String, dynamic> currentBooking,
    double remainingBalance,
  ) async {
    final bookingId = currentBooking['id']?.toString() ?? '';
    final operatorId = _supabase.auth.currentUser?.id ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedMethod = 'Cash';
    final refController = TextEditingController(text: 'CASH-HANDOVER');
    final notesController = TextEditingController();
    bool isSettling = false;

    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.point_of_sale_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Settle Remaining Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Balance to Settle:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        'PHP ${_formatCurrency(remainingBalance)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  dropdownColor: isDark ? AppColors.darkBgSecondary : Colors.white,
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash at Desk / Counter')),
                    DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                    DropdownMenuItem(value: 'Maya', child: Text('Maya / PayMaya')),
                    DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (BDO/BPI/QR Ph)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedMethod = val;
                        if (val == 'Cash') {
                          refController.text = 'CASH-HANDOVER';
                        } else if (refController.text == 'CASH-HANDOVER') {
                          refController.text = '';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Reference / OR Number *',
                    hintText: 'e.g. CASH-HANDOVER or GCash Ref #',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks (Optional)',
                    hintText: 'e.g. Collected remaining rental payment at key handover',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSettling ? null : () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSettling
                  ? null
                  : () async {
                      final ref = refController.text.trim();
                      if (ref.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please provide a payment reference or OR number.')),
                        );
                        return;
                      }
                      setDialogState(() => isSettling = true);
                      try {
                        await BookingService().settleReleasePayment(
                          bookingId: bookingId,
                          actorId: operatorId,
                          actorRole: 'operator',
                          paymentMethod: selectedMethod,
                          paymentReference: ref,
                          notes: notesController.text.trim(),
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                      } catch (e) {
                        setDialogState(() => isSettling = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to settle payment: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              child: isSettling
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Confirm Payment Received', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInspectionDialog(
    Map<String, dynamic> booking, {
    required String inspectionType,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final bookingId = booking['id']?.toString() ?? '';
    if (currentUserId == null || bookingId.isEmpty) return;

    var currentBookingData = Map<String, dynamic>.from(booking);

    // Determine if the current user is the vehicle owner.
    // Only the vehicle owner may submit — everyone else gets a read-only view.
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleOwnerId = vehicle?['owner_id']?.toString() ?? '';
    final isViewOnly = vehicleOwnerId.isNotEmpty && currentUserId != vehicleOwnerId;

    final fuelController = TextEditingController();
    final tiresController = TextEditingController();
    final magsController = TextEditingController();
    final exteriorRemarksController = TextEditingController(text: 'Good');
    final interiorRemarksController = TextEditingController(text: 'Good');
    final autosweepBalanceController = TextEditingController(text: 'N/A');
    final easytripBalanceController = TextEditingController(text: 'N/A');
    final toolsRemarksController = TextEditingController(text: 'Good');
    final cleanlinessRemarksController = TextEditingController(text: 'Good');
    final otherItemsController = TextEditingController(text: 'N/A');
    final othersRemarksController = TextEditingController(text: 'Good');
    final releasedByController = TextEditingController();
    final receivedByController = TextEditingController();
    final inspectionControllers = <TextEditingController>[
      fuelController,
      tiresController,
      magsController,
      exteriorRemarksController,
      interiorRemarksController,
      autosweepBalanceController,
      easytripBalanceController,
      toolsRemarksController,
      cleanlinessRemarksController,
      otherItemsController,
      othersRemarksController,
      releasedByController,
      receivedByController,
    ];
    final checklistItems = <String, bool>{
      for (final key in BookingInspectionService.requiredChecklistKeys)
        key: false,
    };
    final selectedEvidence = <PlatformFile>[];
    bool returnDepositEligible = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If view-only, show a simpler read-only dialog and exit early
    if (isViewOnly) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Inspection Checklist (View Only)'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey),
              SizedBox(height: 14),
              Text(
                'Only the vehicle owner can submit the inspection checklist.\n\nYou can view the submitted checklist once the owner has completed it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      for (final c in inspectionControllers) c.dispose();
      return;
    }

    final shouldSave = await showDialog<bool>(

      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isFullyPaid = BookingService().isBookingFullyPaid(currentBookingData);
            final remainingBalance = BookingService().getBookingRemainingBalance(currentBookingData);

            return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            title: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inspectionType == 'before'
                            ? 'Pre-Trip Vehicle Release Inspection'
                            : 'Post-Trip Vehicle Return Inspection',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        inspectionType == 'before'
                            ? 'Complete this inspection before the booking can move to Ongoing.'
                            : 'Record the returned condition before final payment and ratings. Car inspection is mandatory.',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (inspectionType == 'before') ...[
                      if (isFullyPaid) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '100% Fully Paid (PHP 0.00 balance) • Ready for key release',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Unpaid Balance: PHP ${_formatCurrency(remainingBalance)}',
                                      style: const TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Full payment is strictly required before handing over vehicle keys. Settle balance below to unlock release.',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final settled = await _showReleasePaymentSettlementDialog(
                                    dialogContext,
                                    currentBookingData,
                                    remainingBalance,
                                  );
                                  if (settled == true) {
                                    final updated = await BookingService().getBookingById(bookingId);
                                    if (updated != null) {
                                      setDialogState(() => currentBookingData = updated);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.payments_outlined, size: 16),
                                label: const Text('Settle Remaining Balance at Desk'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    VehicleInspectionChecklistFields(
                      values: checklistItems,
                      isDark: isDark,
                      onChanged: (entry) => setDialogState(
                        () => checklistItems[entry.key] = entry.value,
                      ),
                      onSelectAll: (selected) => setDialogState(() {
                        for (final key in checklistItems.keys) {
                          checklistItems[key] = selected;
                        }
                      }),
                    ),
                    const SizedBox(height: 4),
                    VehicleInspectionSupplementalFields(
                      isDark: isDark,
                      fuelLevelController: fuelController,
                      tiresController: tiresController,
                      magsController: magsController,
                      exteriorRemarksController: exteriorRemarksController,
                      interiorRemarksController: interiorRemarksController,
                      autosweepBalanceController: autosweepBalanceController,
                      easytripBalanceController: easytripBalanceController,
                      toolsRemarksController: toolsRemarksController,
                      cleanlinessRemarksController:
                          cleanlinessRemarksController,
                      otherItemsController: otherItemsController,
                      othersRemarksController: othersRemarksController,
                      releasedByController: releasedByController,
                      receivedByController: receivedByController,
                    ),
                    const SizedBox(height: 12),
                    DialogStatusIndicator(
                      compact: true,
                      isComplete:
                          fuelController.text.trim().isNotEmpty &&
                          tiresController.text.trim().isNotEmpty &&
                          magsController.text.trim().isNotEmpty &&
                          releasedByController.text.trim().isNotEmpty &&
                          receivedByController.text.trim().isNotEmpty &&
                          selectedEvidence.isNotEmpty,
                      completeLabel: 'Inspection information complete',
                      incompleteLabel: 'Inspection information incomplete',
                      completeDetail:
                          'Required fields and photo evidence are ready. Checklist items are optional.',
                      incompleteDetail:
                          'Fill in required condition fields (fuel, tires, mags, names) and attach at least one photo or video.',
                    ),
                    const SizedBox(height: 10),
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 15, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              inspectionType == 'before'
                                  ? 'Pre-trip checklist items are optional. Check only items that apply and are in working condition. Unchecked items will be recorded as existing defects.'
                                  : 'Post-trip checklist items are optional. Check only items that apply — unchecked items will be flagged as issues for review. This determines security deposit refund eligibility.',
                              style: const TextStyle(fontSize: 11, color: Colors.blue, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.media,
                            allowMultiple: true,
                            withData: true,
                          );
                          if (result == null) return;
                          final usableFiles = result.files
                              .where(
                                (file) =>
                                    file.bytes != null &&
                                    file.size <= 25 * 1024 * 1024,
                              )
                              .toList();
                          setDialogState(() {
                            final existingNames =
                                selectedEvidence.map((f) => f.name).toSet();
                            for (final file in usableFiles) {
                              if (!existingNames.contains(file.name) &&
                                  selectedEvidence.length < 10) {
                                selectedEvidence.add(file);
                                existingNames.add(file.name);
                              }
                            }
                          });
                        },
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          selectedEvidence.isEmpty
                              ? 'Add photos or videos (4 to 5 images recommended)'
                              : 'Add more photos/videos (${selectedEvidence.length} selected)',
                        ),
                      ),
                    ),
                    if (selectedEvidence.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedEvidence
                                .map(
                                  (file) => InputChip(
                                    avatar: const Icon(Icons.image_outlined, size: 16),
                                    label: Text(file.name),
                                    onDeleted: () => setDialogState(
                                      () => selectedEvidence.remove(file),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    if (inspectionType == 'after') ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: returnDepositEligible
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: returnDepositEligible
                                ? const Color(0xFF10B981)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: returnDepositEligible,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                setDialogState(() {
                                  returnDepositEligible = val ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vehicle in Good Condition • Return Security Deposit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: returnDepositEligible
                                          ? const Color(0xFF10B981)
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Check this box if the vehicle was returned in acceptable/good condition with no unaddressed damages or major violations. This flags the booking to unlock the "Return Security Deposit" button for the operator.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (inspectionType != 'after')
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
              ElevatedButton(
                onPressed: () {
                  if (inspectionType == 'before' && !isFullyPaid) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Cannot release vehicle keys: Full payment of PHP ${_formatCurrency(remainingBalance)} is required before handover. Please settle balance first.',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  final requiredFieldsReady =
                      fuelController.text.trim().isNotEmpty &&
                      tiresController.text.trim().isNotEmpty &&
                      magsController.text.trim().isNotEmpty &&
                      releasedByController.text.trim().isNotEmpty &&
                      receivedByController.text.trim().isNotEmpty;
                  if (!requiredFieldsReady ||
                      selectedEvidence.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please fill in condition fields (fuel, tires, mags, names) and attach at least one photo or video.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: Text(
                  inspectionType == 'before'
                      ? 'Submit and Start Trip'
                      : 'Submit Return Inspection Checklist',
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

    if (shouldSave != true) {
      for (final controller in inspectionControllers) {
        controller.dispose();
      }
      return;
    }

    _showOperationLoading(
      inspectionType == 'before'
          ? 'Uploading evidence & saving pre-trip inspection...'
          : 'Uploading evidence & submitting return inspection...',
    );

    try {
      final filesToUpload = selectedEvidence
          .where((file) => file.bytes != null)
          .map((file) => (bytes: file.bytes!, extension: file.extension ?? 'jpg'))
          .toList();
      final evidenceUrls = await BookingInspectionService()
          .uploadMultipleEvidenceBytes(
            userId: currentUserId,
            bookingId: bookingId,
            files: filesToUpload,
          );
      final savedInspection = await BookingInspectionService().saveInspection(
        bookingId: bookingId,
        inspectionType: inspectionType,
        inspectorId: currentUserId,
        fuelLevel: fuelController.text.trim(),
        cleanliness: cleanlinessRemarksController.text.trim(),
        scratches: exteriorRemarksController.text.trim(),
        remarks: othersRemarksController.text.trim(),
        tiresDetails: tiresController.text.trim(),
        magsDetails: magsController.text.trim(),
        autosweepBalance: autosweepBalanceController.text.trim(),
        easytripBalance: easytripBalanceController.text.trim(),
        otherItems: otherItemsController.text.trim(),
        sectionRemarks: {
          'exterior': exteriorRemarksController.text.trim(),
          'interior': interiorRemarksController.text.trim(),
          'tools_accessories': toolsRemarksController.text.trim(),
          'cleanliness': cleanlinessRemarksController.text.trim(),
          'others': othersRemarksController.text.trim(),
        },
        evidenceUrls: evidenceUrls,
        checklistItems: checklistItems,
        releasedBy: releasedByController.text,
        receivedBy: receivedByController.text,
      );

      // Immediately post the inspection checklist audit to chat so it is guaranteed to submit
      try {
        await BookingService().postInspectionAuditToBookingChat(
          booking: currentBookingData,
          inspection: savedInspection,
          inspectionType: inspectionType,
        );
      } catch (auditErr) {
        debugPrint('[OperatorWebScreen] Warning posting inspection audit: $auditErr');
      }

      if (inspectionType == 'before') {
        await BookingService().startBookingAfterInspection(
          bookingId: bookingId,
          inspectorId: currentUserId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Release checklist submitted. The trip is now ongoing.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        await BookingService().setSecurityDepositReturnEligibility(
          bookingId: bookingId,
          isEligible: returnDepositEligible,
        );

        final bookingData =
            await BookingService().getBookingById(bookingId) ?? booking;
        final isFullyPaid = BookingService().isBookingFullyPaid(bookingData);
        final remainingBalance =
            BookingService().getBookingRemainingBalance(bookingData);
        final lateReturn =
            BookingService().getLateReturnDetails(bookingData, DateTime.now());
        final lateReturnFee =
            (lateReturn['late_return_fee'] as num?)?.toDouble() ?? 0.0;
        final lateHours =
            (lateReturn['late_return_hours'] as num?)?.toInt() ?? 0;

        final hasChargesOrViolations =
            lateReturnFee > 0 || remainingBalance > 0 || !isFullyPaid;
        bool confirmPaymentNow = false;

        // Settlement form state (hoisted so it's accessible after the dialog)
        String selectedMethod = 'GCash';
        TextEditingController? refController;
        String? uploadedReceiptUrl;

        if (hasChargesOrViolations) {
          // Check if already settled (e.g. re-opened after partial save)
          final alreadySettled =
              bookingData['final_payment_status']?.toString().toLowerCase() == 'paid';
          final meta = bookingData['metadata'] is Map
              ? Map<String, dynamic>.from(bookingData['metadata'] as Map)
              : <String, dynamic>{};
          final totalPenalty = lateReturnFee + remainingBalance;

          // Settlement form state
          final pastMethod = (bookingData['final_payment_method'] ?? meta['final_payment_method'])?.toString();
          final pastRef = (bookingData['final_payment_reference'] ?? meta['final_payment_reference'])?.toString();
          final pastReceipt = (bookingData['final_payment_proof_url'] ?? meta['final_payment_proof_url'])?.toString();

          selectedMethod = pastMethod?.isNotEmpty == true ? pastMethod! : 'GCash';
          refController = TextEditingController(text: pastRef ?? '');
          PlatformFile? receiptFile;
          uploadedReceiptUrl = pastReceipt?.isNotEmpty == true ? pastReceipt : null;
          bool isSettling = false;
          String? settlementError;

          final choice = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => StatefulBuilder(
              builder: (dialogContext, setDs) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Dialog(
                  backgroundColor: isDark ? const Color(0xFF1E2235) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF2D3148) : Colors.grey.shade200,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ─── Header ───────────────────────────────────
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_long_rounded,
                                    color: Color(0xFFF59E0B), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alreadySettled ? 'Settlement Record' : 'Late Fee & Balance Settlement',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                      ),
                                    ),
                                    Text(
                                      alreadySettled ? 'Payment confirmed and recorded.' : 'Settle all outstanding charges before completing return.',
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(dialogContext, 'cancel'),
                                icon: Icon(Icons.close_rounded,
                                    color: isDark ? Colors.white38 : Colors.black38),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ─── Already Settled Badge ─────────────────────
                          if (alreadySettled) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF10B981), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Settlement already confirmed',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ─── Charge Breakdown ──────────────────────────
                          if (lateReturnFee > 0) ...[
                            _buildSettlementLineItem(
                              label: 'Late Return Penalty ($lateHours hr${lateHours == 1 ? '' : 's'})',
                              amount: lateReturnFee,
                              color: const Color(0xFFEF4444),
                              icon: Icons.schedule_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (remainingBalance > 0) ...[
                            _buildSettlementLineItem(
                              label: 'Unpaid Rental Balance',
                              amount: remainingBalance,
                              color: const Color(0xFFF59E0B),
                              icon: Icons.account_balance_wallet_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                          ],

                          // ─── Total ────────────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF252A3D) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Amount to Settle',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'PHP ${_formatCurrency(totalPenalty)}',
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (!alreadySettled) ...[
                            // ─── Payment Method ────────────────────────
                            Text(
                              'Settlement Payment Method',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedMethod,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF252A3D) : Colors.grey.shade50,
                              ),
                              dropdownColor: isDark ? const Color(0xFF252A3D) : Colors.white,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                              items: ['GCash', 'Maya', 'Bank Transfer', 'Cash', 'GoTyme']
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                  .toList(),
                              onChanged: alreadySettled
                                  ? null
                                  : (v) => setDs(() => selectedMethod = v ?? selectedMethod),
                            ),
                            const SizedBox(height: 14),

                            // ─── Reference No ─────────────────────────
                            Text(
                              'Reference / Transaction No.',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: refController,
                              readOnly: alreadySettled,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. 1234567890123',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white30 : Colors.black26,
                                  fontSize: 13,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF252A3D) : Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ─── Receipt Upload ────────────────────────
                            Text(
                              'Proof of Settlement (Receipt / Screenshot)',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: alreadySettled
                                  ? null
                                  : () async {
                                      final result = await FilePicker.platform.pickFiles(
                                        type: FileType.image,
                                        withData: true,
                                      );
                                      if (result != null && result.files.isNotEmpty) {
                                        setDs(() => receiptFile = result.files.first);
                                      }
                                    },
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF252A3D) : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: receiptFile != null
                                        ? const Color(0xFF10B981)
                                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                                    width: receiptFile != null ? 1.5 : 1.0,
                                  ),
                                ),
                                child: receiptFile != null
                                    ? Row(
                                        children: [
                                          const SizedBox(width: 12),
                                          const Icon(Icons.image_rounded,
                                              color: Color(0xFF10B981), size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              receiptFile!.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () =>
                                                setDs(() => receiptFile = null),
                                            icon: const Icon(Icons.delete_outline_rounded,
                                                color: Colors.redAccent, size: 18),
                                            splashRadius: 16,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.upload_file_rounded,
                                              size: 18,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Tap to upload receipt',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],

                          // ─── Already Settled: Show Details ─────────────
                          if (alreadySettled) ...[
                            if (pastMethod?.isNotEmpty == true)
                              _buildSettlementDetailRow(
                                  label: 'Payment Method',
                                  value: pastMethod!,
                                  icon: Icons.payment_rounded,
                                  isDark: isDark),
                            if (pastRef?.isNotEmpty == true)
                              _buildSettlementDetailRow(
                                  label: 'Reference No.',
                                  value: pastRef!,
                                  icon: Icons.tag_rounded,
                                  isDark: isDark),
                            if (pastReceipt?.isNotEmpty == true) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _showReceiptProofDialog(pastReceipt!, isDark),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF0284C7)
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.receipt_rounded,
                                            color: Color(0xFF0284C7), size: 18),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'View Settlement Receipt',
                                            style: TextStyle(
                                              color: Color(0xFF0284C7),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.open_in_new_rounded,
                                            color: Color(0xFF0284C7), size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: () => _showReceiptProofDialog(pastReceipt!, isDark),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        OnDemandNetworkImage(
                                          imageUrl: pastReceipt!,
                                          width: double.infinity,
                                          height: 140,
                                          fit: BoxFit.cover,
                                          label: 'Receipt Proof',
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.zoom_in, color: Colors.white, size: 16),
                                              SizedBox(width: 4),
                                              Text(
                                                'Click to view full receipt',
                                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],

                          // ─── Error ─────────────────────────────────────
                          if (settlementError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Colors.redAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      settlementError!,
                                      style: const TextStyle(
                                          color: Colors.redAccent, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // ─── Actions ───────────────────────────────────
                          if (alreadySettled)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isSettling
                                        ? null
                                        : () => Navigator.pop(dialogContext, 'cancel'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                                      ),
                                      foregroundColor: isDark ? Colors.white70 : Colors.black54,
                                      minimumSize: const Size(0, 46),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Close'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isSettling
                                        ? null
                                        : () async {
                                            final reasonCtrl = TextEditingController();
                                            final rejectReason = await showDialog<String>(
                                              context: dialogContext,
                                              builder: (rCtx) => AlertDialog(
                                                backgroundColor: isDark ? const Color(0xFF1E2235) : Colors.white,
                                                title: const Text('Reject Payment Proof?'),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'If the renter entered the wrong amount, invalid reference, or fake receipt, reject this settlement. The renter will be asked to re-submit or settle at the front desk.',
                                                      style: TextStyle(fontSize: 13),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    TextField(
                                                      controller: reasonCtrl,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Rejection Reason',
                                                        hintText: 'e.g. Receipt unreadable / Reference invalid',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(rCtx),
                                                    child: const Text('Back'),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.redAccent,
                                                      foregroundColor: Colors.white,
                                                    ),
                                                    onPressed: () => Navigator.pop(
                                                      rCtx,
                                                      reasonCtrl.text.trim().isNotEmpty
                                                          ? reasonCtrl.text.trim()
                                                          : 'Settlement receipt or reference could not be verified.',
                                                    ),
                                                    child: const Text('Confirm Reject'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (rejectReason != null && rejectReason.isNotEmpty) {
                                              setDs(() => isSettling = true);
                                              try {
                                                await BookingService().rejectFinalSettlementPayment(
                                                  bookingId: bookingId,
                                                  operatorId: currentUserId,
                                                  rejectionReason: rejectReason,
                                                );
                                                Navigator.pop(dialogContext, 'reject_payment');
                                              } catch (e) {
                                                setDs(() {
                                                  isSettling = false;
                                                  settlementError = 'Rejection failed: $e';
                                                });
                                              }
                                            }
                                          },
                                    icon: const Icon(Icons.cancel_outlined, size: 16),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.redAccent),
                                      foregroundColor: Colors.redAccent,
                                      minimumSize: const Size(0, 46),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: isSettling
                                        ? null
                                        : () => Navigator.pop(dialogContext, 'confirm_payment'),
                                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                                    label: const Text(
                                      'Confirm & Complete',
                                      textAlign: TextAlign.center,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 46),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isSettling
                                        ? null
                                        : () => Navigator.pop(
                                            dialogContext, 'cancel'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.grey.shade300,
                                      ),
                                      foregroundColor: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                      minimumSize:
                                          const Size(0, 46),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isSettling
                                        ? null
                                        : () => Navigator.pop(
                                            dialogContext, 'proceed_unpaid'),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Colors.orange),
                                      foregroundColor: Colors.orange,
                                      minimumSize:
                                          const Size(0, 46),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: const Text(
                                      'Leave Unpaid',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: isSettling
                                        ? null
                                        : () async {
                                            if ((refController?.text ?? '').trim().isEmpty) {
                                              setDs(() => settlementError =
                                                  'Please enter a reference / transaction number.');
                                              return;
                                            }
                                            setDs(() {
                                              isSettling = true;
                                              settlementError = null;
                                            });
                                            try {
                                              if (receiptFile?.bytes !=
                                                  null) {
                                                uploadedReceiptUrl =
                                                    await BookingInspectionService()
                                                        .uploadEvidenceBytes(
                                                  userId: currentUserId,
                                                  bookingId: bookingId,
                                                  bytes: receiptFile!
                                                      .bytes!,
                                                  extension: receiptFile!
                                                          .extension ??
                                                      'jpg',
                                                );
                                              }
                                              Navigator.pop(
                                                  dialogContext,
                                                  'confirm_payment');
                                            } catch (e) {
                                              setDs(() {
                                                isSettling = false;
                                                settlementError =
                                                    'Receipt upload failed: ${e.toString().replaceAll('Exception:', '').trim()}';
                                              });
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size(0, 46),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: isSettling
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2),
                                          )
                                        : const Text(
                                            'Confirm Settlement',
                                            textAlign: TextAlign.center,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );

          if (choice == 'cancel' || choice == null) {
            _hideOperationLoading();
            return;
          }
          if (choice == 'reject_payment') {
            _hideOperationLoading();
            await _loadDashboardData(showLoading: false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Settlement payment rejected. Renter notified to re-submit or settle at desk.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          if (choice == 'confirm_payment') {
            confirmPaymentNow = true;
          }

        } else {
          // No late return fee and fully paid -> completes automatically without showing payment window!
          confirmPaymentNow = true;
        }

        await BookingService().completeBookingAfterInspection(
          bookingId: bookingId,
          inspectorId: currentUserId,
          confirmPaymentIfUnpaid: confirmPaymentNow,
          penaltyPaymentMethod:
              hasChargesOrViolations ? selectedMethod : null,
          penaltyPaymentReference:
              hasChargesOrViolations ? (refController?.text.trim() ?? '') : null,
          penaltyReceiptUrl:
              hasChargesOrViolations ? uploadedReceiptUrl : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (!hasChargesOrViolations || confirmPaymentNow)
                  ? 'Return checklist submitted. Trip completed successfully!'
                  : 'Return checklist submitted. Trip is awaiting late fee / balance payment confirmation.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }

      await _loadDashboardData(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Inspection save error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _hideOperationLoading();
      for (final controller in inspectionControllers) {
        controller.dispose();
      }
    }
  }

  Widget _buildSettlementLineItem({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            'PHP ${_formatCurrency(amount)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementDetailRow({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildInspectionConditionSelector(
    TextEditingController controller,
    String label, {
    required bool isDark,
    required VoidCallback refresh,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172337) : const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFDCE3EC),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF10233B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final option in const ['Good', 'Bad']) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(option),
              selected: controller.text == option,
              onSelected: (_) {
                controller.text = option;
                refresh();
              },
              selectedColor: option == 'Good'
                  ? AppColors.success.withValues(alpha: 0.22)
                  : AppColors.error.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: controller.text == option
                    ? option == 'Good'
                          ? AppColors.success
                          : AppColors.error
                    : isDark
                    ? Colors.white70
                    : Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingEventChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? Colors.grey[300] : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[300] : Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

