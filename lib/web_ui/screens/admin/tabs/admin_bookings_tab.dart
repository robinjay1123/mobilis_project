part of '../admin_web_screen.dart';

extension _AdminBookingsTab on _AdminWebScreenState {
  Widget _buildBookingsContent(bool isDark) {
    // 1. Calculate status counts
    final allCount = _allBookings.length;
    int pendingCount = 0;
    int confirmedCount = 0;
    int activeCount = 0;
    int completedCount = 0;
    int cancelledCount = 0;

    for (final b in _allBookings) {
      final st = (b['status']?.toString() ?? 'pending').toLowerCase();
      if (st == 'pending') {
        pendingCount++;
      } else if (st == 'confirmed' || st == 'approved') {
        confirmedCount++;
      } else if (st == 'active' || st == 'in_trip' || st == 'in-trip') {
        activeCount++;
      } else if (st == 'completed') {
        completedCount++;
      } else if (st == 'cancelled' || st == 'rejected') {
        cancelledCount++;
      }
    }

    // 2. Filter bookings by search query & status chip
    final query = _bookingSearchQuery.trim().toLowerCase();
    final filteredBookings = _allBookings.where((booking) {
      final status = (booking['status']?.toString() ?? 'pending').toLowerCase();

      // Status filter
      if (_bookingStatusFilter != 'all') {
        if (_bookingStatusFilter == 'pending' && status != 'pending') {
          return false;
        }
        if (_bookingStatusFilter == 'confirmed' &&
            status != 'confirmed' &&
            status != 'approved') {
          return false;
        }
        if (_bookingStatusFilter == 'active' &&
            status != 'active' &&
            status != 'in_trip' &&
            status != 'in-trip') {
          return false;
        }
        if (_bookingStatusFilter == 'completed' && status != 'completed') {
          return false;
        }
        if (_bookingStatusFilter == 'cancelled' &&
            status != 'cancelled' &&
            status != 'rejected') {
          return false;
        }
      }

      // Search query
      if (query.isEmpty) return true;
      final bookingId = booking['id']?.toString().toLowerCase() ?? '';
      final vehicle = booking['vehicles'] as Map<String, dynamic>?;
      final vehicleTitle =
          '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''} ${vehicle?['plate_number'] ?? ''}'
              .toLowerCase();
      final renter = booking['renter'] as Map<String, dynamic>?;
      final renterName = renter?['full_name']?.toString().toLowerCase() ?? '';
      final renterEmail = renter?['email']?.toString().toLowerCase() ?? '';
      final driver = (booking['driver'] ?? booking['drivers']) as Map<String, dynamic>?;
      final driverUser = driver?['users'] as Map<String, dynamic>?;
      final driverName =
          driverUser?['full_name']?.toString().toLowerCase() ?? '';
      final pickup = booking['pickup_location']?.toString().toLowerCase() ?? '';
      final dropoff =
          booking['dropoff_location']?.toString().toLowerCase() ?? '';

      return bookingId.contains(query) ||
          vehicleTitle.contains(query) ||
          renterName.contains(query) ||
          renterEmail.contains(query) ||
          driverName.contains(query) ||
          pickup.contains(query) ||
          dropoff.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.book_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bookings & Trip Operations',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Search, monitor, and manage all trip bookings, driver assignments, payment details, and live GPS tracking.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  height: 1,
                ),
                const SizedBox(height: 16),

                // Controls Row: Search Bar, Status Filter Chips & View Mode Toggle
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _bookingSearchQuery = val),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search by Booking ID, Renter, Vehicle, Plate, Driver, or Destination...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black26
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // View Mode Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Cards View',
                            icon: const Icon(Icons.grid_view_rounded, size: 18),
                            color: _bookingViewMode == 'cards'
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            onPressed: () =>
                                setState(() => _bookingViewMode = 'cards'),
                          ),
                          IconButton(
                            tooltip: 'Table View',
                            icon: const Icon(
                              Icons.table_rows_rounded,
                              size: 18,
                            ),
                            color: _bookingViewMode == 'table'
                                ? AppColors.primary
                                : (isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            onPressed: () =>
                                setState(() => _bookingViewMode = 'table'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Status Filter Chips
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildBookingFilterChip(
                      'all',
                      'All Bookings',
                      allCount,
                      isDark,
                    ),
                    _buildBookingFilterChip(
                      'pending',
                      'Pending',
                      pendingCount,
                      isDark,
                      color: Colors.orange,
                    ),
                    _buildBookingFilterChip(
                      'confirmed',
                      'Confirmed',
                      confirmedCount,
                      isDark,
                      color: Colors.blue,
                    ),
                    _buildBookingFilterChip(
                      'active',
                      'Active / In-Trip',
                      activeCount,
                      isDark,
                      color: Colors.green,
                    ),
                    _buildBookingFilterChip(
                      'completed',
                      'Completed',
                      completedCount,
                      isDark,
                      color: Colors.teal,
                    ),
                    _buildBookingFilterChip(
                      'cancelled',
                      'Cancelled',
                      cancelledCount,
                      isDark,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Bookings List or Cards View
          if (filteredBookings.isEmpty)
            _buildCard(
              'Bookings List (0)',
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 48,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No bookings match your current search or filter criteria.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              isDark,
            )
          else if (_bookingViewMode == 'cards')
            Column(
              children: filteredBookings
                  .map((b) => _buildDetailedBookingCard(b, isDark))
                  .toList(),
            )
          else
            _buildBookingsMasterTable(filteredBookings, isDark),
        ],
      ),
    );
  }

  Widget _buildBookingFilterChip(
    String key,
    String label,
    int count,
    bool isDark, {
    Color? color,
  }) {
    final isSelected = _bookingStatusFilter == key;
    final chipColor = color ?? AppColors.primary;

    return InkWell(
      onTap: () => setState(() => _bookingStatusFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.2)
              : (isDark ? Colors.black26 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? chipColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor
                    : (isDark ? Colors.white10 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedBookingCard(Map<String, dynamic> booking, bool isDark) {
    final bookingId = booking['id']?.toString() ?? 'N/A';
    final refCode = bookingId.length > 8
        ? '#BK-${bookingId.substring(0, 8).toUpperCase()}'
        : '#BK-$bookingId';
    final status = (booking['status'] as String? ?? 'pending').toLowerCase();
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final renter = booking['renter'] as Map<String, dynamic>?;
    final driver = (booking['driver'] ?? booking['drivers']) as Map<String, dynamic>?;
    final driverUser = driver?['users'] as Map<String, dynamic>?;
    final withDriver = booking['with_driver'] == true;

    final vehicleImageUrl = _resolveVehicleImage(vehicle, booking);
    final vBrand = vehicle?['brand']?.toString().trim() ?? '';
    final vModel = vehicle?['model']?.toString().trim() ?? '';
    final vCombo = [vBrand, vModel].where((part) => part.isNotEmpty).join(' ');
    final rawVName = vehicle?['vehicle_name']?.toString().trim() ?? '';
    final vehicleTitle = vCombo.isNotEmpty
        ? vCombo
        : (rawVName.isNotEmpty &&
                rawVName.toLowerCase() != 'partner vehicle' &&
                rawVName.toLowerCase() != 'unknown vehicle'
            ? rawVName
            : (vehicle?['plate_number']?.toString().isNotEmpty == true
                ? 'Vehicle (${vehicle!['plate_number']})'
                : 'Partner Vehicle'));
    final plateNumber = vehicle?['plate_number']?.toString().trim() ?? '';
    final renterName =
        renter?['full_name']?.toString().trim() ?? 'Unknown Renter';
    final renterPhone = renter?['phone']?.toString().trim() ?? '';
    final driverName = driverUser?['full_name']?.toString().trim() ?? 'N/A';
    final driverPhone = driverUser?['phone']?.toString().trim() ?? '';

    final startDate = _formatDate(booking['start_date']);
    final endDate = _formatDate(booking['end_date']);
    final pickup =
        booking['pickup_location']?.toString().trim() ?? 'Not specified';
    final dropoff =
        booking['dropoff_location']?.toString().trim() ??
        booking['delivery_address']?.toString().trim() ??
        'Not specified';

    final totalCost =
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0;
    final deposit = (booking['deposit_amount'] as num?)?.toDouble() ?? 0;
    final paymentStatus = (booking['payment_status'] as String? ?? 'pending')
        .toLowerCase();

    final canTrack = _canTrackBooking(booking);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF021F35) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                SelectableText(
                  refCode,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.primary : Colors.blue.shade800,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Copy Booking ID',
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: bookingId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Booking ID copied to clipboard'),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  '• Booked ${_formatDate(booking['created_at'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(status),
              ],
            ),
          ),

          // Main 4-Column Data Grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 900;
                final colWidth = isNarrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 36) / 4;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Column 1: Vehicle & Owner (with Car Image Thumbnail)
                    SizedBox(
                      width: colWidth,
                      child: _buildVehicleBookingFieldBox(
                        'Vehicle & License',
                        vehicleTitle,
                        isDark,
                        subtitle: plateNumber.isNotEmpty
                            ? 'Plate: $plateNumber'
                            : 'No plate specified',
                        imageUrl: vehicleImageUrl,
                        onTapVehicle: (vehicle != null || booking['partner_vehicles'] != null)
                            ? () {
                                final targetVeh = vehicle ??
                                    (booking['partner_vehicles'] as Map<String, dynamic>?);
                                if (targetVeh != null) {
                                  _showAdminVehicleDetailsDialog(targetVeh, isDark);
                                }
                              }
                            : null,
                      ),
                    ),

                    // Column 2: Renter & Driver
                    SizedBox(
                      width: colWidth,
                      child: _buildBookingFieldBox(
                        'Renter & Driver',
                        renterName,
                        isDark,
                        subtitle: withDriver
                            ? 'Driver: $driverName ${driverPhone.isNotEmpty ? "($driverPhone)" : ""}'
                            : 'Self-Drive (No Driver)',
                        icon: Icons.person_pin_rounded,
                        highlightColor: withDriver ? Colors.blue : null,
                      ),
                    ),

                    // Column 3: Rental Schedule & Locations
                    SizedBox(
                      width: colWidth,
                      child: _buildBookingFieldBox(
                        'Schedule & Route',
                        '$startDate → $endDate',
                        isDark,
                        subtitle: 'Pickup: $pickup\nDropoff: $dropoff',
                        icon: Icons.route_rounded,
                      ),
                    ),

                    // Column 4: Financial Summary & Payment
                    SizedBox(
                      width: colWidth,
                      child: _buildBookingFieldBox(
                        'Financial Breakdown',
                        'PHP ${totalCost.toStringAsFixed(0)}',
                        isDark,
                        subtitle:
                            'Deposit: PHP ${deposit.toStringAsFixed(0)} • Delivery: ₱75/km\nPayment: ${paymentStatus.toUpperCase()}',
                        icon: Icons.payments_rounded,
                        highlightColor: Colors.green,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Footer Action Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                if (renterPhone.isNotEmpty) ...[
                  Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Renter Contact: $renterPhone',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
                const Spacer(),

                // Actions
                if (canTrack)
                  FilledButton.icon(
                    onPressed: () => _openTrackingForBooking(booking),
                    icon: const Icon(Icons.location_on_rounded, size: 16),
                    label: const Text('Live GPS Track'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleBookingFieldBox(
    String label,
    String value,
    bool isDark, {
    String? subtitle,
    String? imageUrl,
    VoidCallback? onTapVehicle,
  }) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_car_filled_rounded,
                size: 13,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTapVehicle != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    size: 12,
                    color: isDark ? AppColors.primary : Colors.blue.shade700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vehicle Car Image Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 58,
                  height: 44,
                  color: isDark ? AppColors.darkBgTertiary : Colors.grey.shade200,
                  child: hasImage
                      ? OptimizedNetworkImage(
                          imageUrl: imageUrl.trim(),
                          fit: BoxFit.cover,
                          width: 58,
                          height: 44,
                          errorWidget: Icon(
                            Icons.directions_car_rounded,
                            size: 24,
                            color: isDark ? Colors.grey[600] : Colors.grey.shade500,
                          ),
                        )
                      : Icon(
                          Icons.directions_car_rounded,
                          size: 24,
                          color: isDark ? Colors.grey[600] : Colors.grey.shade500,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              // Vehicle Title & Plate Number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTapVehicle != null) {
      return Tooltip(
        message: 'Click to view vehicle details',
        child: InkWell(
          onTap: onTapVehicle,
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.primary.withValues(alpha: 0.05),
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _buildBookingFieldBox(
    String label,
    String value,
    bool isDark, {
    String? subtitle,
    IconData? icon,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              highlightColor?.withValues(alpha: 0.4) ??
              (isDark ? AppColors.borderColor : Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color:
                      highlightColor ??
                      (isDark ? Colors.white54 : Colors.grey.shade600),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _getBookingCommissionBreakdown(
    Map<String, dynamic> booking,
  ) {
    final total =
        (booking['total_price'] as num?)?.toDouble() ??
        (booking['total_cost'] as num?)?.toDouble() ??
        0.0;
    final rentalSubtotal =
        (booking['rental_subtotal'] as num?)?.toDouble() ?? total;
    final vehicle = booking['vehicles'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(booking['vehicles'])
        : <String, dynamic>{};
    final isPartner =
        booking['is_partner_vehicle'] == true ||
        vehicle['is_partner_vehicle'] == true ||
        vehicle['owner_role']?.toString().toLowerCase() == 'partner';

    // 5% platform commission on rental, 95% partner net
    final partnerCommission = isPartner ? rentalSubtotal * 0.05 : 0.0;
    final partnerNet = isPartner
        ? (rentalSubtotal - partnerCommission).clamp(0.0, double.infinity)
        : 0.0;

    final rawCommissionStatus =
        booking['commission_status']?.toString().toLowerCase();
    final settlement = booking['settlement'] as Map<String, dynamic>?;
    final isSettlementReleased =
        settlement?['status']?.toString().toLowerCase() == 'released';

    String statusKey = 'not_applicable';
    String statusLabel = 'PSDC Fleet';
    if (isPartner) {
      if (rawCommissionStatus == 'released' || isSettlementReleased) {
        statusKey = 'released';
        statusLabel = 'Disbursed';
      } else if (rawCommissionStatus == 'processing') {
        statusKey = 'processing';
        statusLabel = 'Processing';
      } else if (rawCommissionStatus == 'settlement_failed') {
        statusKey = 'failed';
        statusLabel = 'Failed';
      } else {
        final bookingStatus =
            (booking['status']?.toString() ?? '').toLowerCase();
        if (bookingStatus == 'completed') {
          statusKey = 'pending_release';
          statusLabel = 'Pending Disbursement';
        } else if (bookingStatus == 'cancelled' ||
            bookingStatus == 'rejected') {
          statusKey = 'cancelled';
          statusLabel = 'Cancelled';
        } else {
          statusKey = 'on_trip';
          statusLabel = 'In Progress';
        }
      }
    }

    final releasedAtRaw =
        settlement?['released_at'] ??
        booking['commission_eligible_at'] ??
        booking['updated_at'];
    DateTime? releasedAt;
    if (releasedAtRaw != null) {
      releasedAt = DateTime.tryParse(releasedAtRaw.toString());
    }

    return {
      'is_partner': isPartner,
      'partner_name': booking['partner_name'] ?? 'Partner',
      'partner_business_name': booking['partner_business_name'],
      'partner_email': booking['partner_email'],
      'partner_phone': booking['partner_phone'],
      'total_amount': total,
      'rental_amount': rentalSubtotal,
      'partner_commission': partnerCommission,
      'partner_net': partnerNet,
      'status_key': statusKey,
      'status_label': statusLabel,
      'released_at': releasedAt,
    };
  }

  Widget _buildCommissionDisbursementBadge(
    Map<String, dynamic> breakdown,
    bool isDark,
  ) {
    final isPartner = breakdown['is_partner'] == true;
    if (!isPartner) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.blueGrey.withValues(alpha: 0.2)
              : Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? Colors.blueGrey.shade700 : Colors.blueGrey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.apartment_rounded,
              size: 13,
              color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700,
            ),
            const SizedBox(width: 5),
            Text(
              'PSDC Fleet (100%)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? Colors.blueGrey.shade300
                    : Colors.blueGrey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    final statusKey = breakdown['status_key'] as String;
    final partnerNet = (breakdown['partner_net'] as num?)?.toDouble() ?? 0.0;
    final commission =
        (breakdown['partner_commission'] as num?)?.toDouble() ?? 0.0;
    final releasedAt = breakdown['released_at'] as DateTime?;

    if (statusKey == 'released') {
      final dateStr = releasedAt != null
          ? DateFormat('MMM d, h:mm a').format(releasedAt)
          : '';
      return Tooltip(
        message:
            'Partner Net: ₱${partnerNet.toStringAsFixed(0)} | Platform Commission (5%): ₱${commission.toStringAsFixed(0)}${dateStr.isNotEmpty ? '\nDisbursed: $dateStr' : ''}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 13,
                color: Color(0xFF10B981),
              ),
              const SizedBox(width: 5),
              Text(
                'Disbursed (₱${partnerNet.toStringAsFixed(0)})',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (statusKey == 'pending_release') {
      return Tooltip(
        message:
            'Trip completed. Ready for payout disbursement (Partner: ₱${partnerNet.toStringAsFixed(0)})',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 13,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 5),
              const Text(
                'Pending Disbursement',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (statusKey == 'on_trip' || statusKey == 'processing') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 13,
              color: Color(0xFF3B82F6),
            ),
            const SizedBox(width: 5),
            Text(
              statusKey == 'processing' ? 'Processing' : 'In Progress',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.withValues(alpha: 0.15)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        breakdown['status_label']?.toString() ?? 'N/A',
        style: TextStyle(
          fontSize: 10,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildBookingsMasterTable(
    List<Map<String, dynamic>> sortedBookings,
    bool isDark,
  ) {
    return _buildCard(
      'Bookings Master Table (${sortedBookings.length})',
      LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                horizontalMargin: 16,
                columnSpacing: 24,
                columns: [
                  DataColumn(
                    label: Text(
                      'Booking ID & Dates',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Vehicle & Fleet',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Renter & Driver',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Trip Status',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Partner Disbursement',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Total Amount',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                rows: sortedBookings.map((booking) {
                  final bookingId = booking['id']?.toString() ?? 'N/A';
                  final refCode = bookingId.length > 8
                      ? '#BK-${bookingId.substring(0, 8).toUpperCase()}'
                      : '#BK-$bookingId';
                  final vehicle = booking['vehicles'] as Map<String, dynamic>?;
                  final user = booking['renter'] as Map<String, dynamic>?;
                  final driver = (booking['driver'] ?? booking['drivers']) as Map<String, dynamic>?;
                  final driverUser = driver?['users'] as Map<String, dynamic>?;
                  final driverName = driverUser?['full_name']?.toString();
                  final status = booking['status'] as String? ?? 'pending';
                  final canTrack = _canTrackBooking(booking);
                  final breakdown = _getBookingCommissionBreakdown(booking);
                  final total = breakdown['total_amount'] as double;
                  final isPartner = breakdown['is_partner'] == true;
                  final partnerName = breakdown['partner_name'] as String;
                  final vehicleImg = _resolveVehicleImage(vehicle, booking);

                  final startDateRaw =
                      booking['start_date'] ?? booking['start_at'];
                  final endDateRaw = booking['end_date'] ?? booking['end_at'];
                  String dateRangeText = 'Dates not set';
                  if (startDateRaw != null) {
                    final startDt = DateTime.tryParse(startDateRaw.toString());
                    final endDt = endDateRaw != null
                        ? DateTime.tryParse(endDateRaw.toString())
                        : null;
                    if (startDt != null && endDt != null) {
                      dateRangeText =
                          '${DateFormat('MMM d').format(startDt)} - ${DateFormat('MMM d, yyyy').format(endDt)}';
                    } else if (startDt != null) {
                      dateRangeText = DateFormat('MMM d, yyyy').format(startDt);
                    }
                  }

                  return DataRow(
                    cells: [
                      DataCell(
                        InkWell(
                          onTap: () =>
                              _showAdminBookingDetailsModal(booking, isDark),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                refCode,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.primary
                                      : Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateRangeText,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 44,
                                height: 34,
                                color: isDark
                                    ? AppColors.darkBgTertiary
                                    : Colors.grey.shade200,
                                child: vehicleImg.isNotEmpty
                                    ? OptimizedNetworkImage(
                                        imageUrl: vehicleImg,
                                        fit: BoxFit.cover,
                                        width: 44,
                                        height: 34,
                                        errorWidget: Icon(
                                          Icons.directions_car_rounded,
                                          size: 18,
                                          color: isDark
                                              ? Colors.grey[600]
                                              : Colors.grey.shade500,
                                        ),
                                      )
                                    : Icon(
                                        Icons.directions_car_rounded,
                                        size: 18,
                                        color: isDark
                                            ? Colors.grey[600]
                                            : Colors.grey.shade500,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  vehicle != null
                                      ? '${vehicle['brand']} ${vehicle['model']} ${vehicle['plate_number'] != null ? "(${vehicle['plate_number']})" : ""}'
                                      : 'Unknown Vehicle',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPartner
                                        ? const Color(0xFF0284C7).withValues(
                                            alpha: 0.15,
                                          )
                                        : AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isPartner
                                        ? '🤝 Partner: $partnerName'
                                        : '🏢 PSDC Fleet',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isPartner
                                          ? const Color(0xFF0284C7)
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user?['full_name'] ?? 'Unknown Renter',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                            if (driverName != null && driverName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 11,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Driver: $driverName',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(_buildStatusBadge(status)),
                      DataCell(
                        _buildCommissionDisbursementBadge(breakdown, isDark),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'PHP ${total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 13,
                              ),
                            ),
                            if (isPartner) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Net ₱${(breakdown['partner_net'] as double).toStringAsFixed(0)} / Comm ₱${(breakdown['partner_commission'] as double).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              tooltip: 'View Booking & Disbursement Details',
                              color: isDark
                                  ? AppColors.primary
                                  : Colors.blue.shade800,
                              onPressed: () => _showAdminBookingDetailsModal(
                                booking,
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton.icon(
                              onPressed: canTrack
                                  ? () => _openTrackingForBooking(booking)
                                  : null,
                              icon: const Icon(Icons.location_on, size: 14),
                              label: const Text(
                                'Track',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(60, 32),
                                disabledBackgroundColor: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                                disabledForegroundColor: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
      isDark,
    );
  }

  void _showAdminBookingDetailsModal(
    Map<String, dynamic> booking,
    bool isDark,
  ) {
    final bookingId = booking['id']?.toString() ?? 'N/A';
    final refCode = bookingId.length > 8
        ? '#BK-${bookingId.substring(0, 8).toUpperCase()}'
        : '#BK-$bookingId';
    final vehicle = booking['vehicles'] as Map<String, dynamic>?;
    final vehicleImg = _resolveVehicleImage(vehicle, booking);
    final user = booking['renter'] as Map<String, dynamic>?;
    final driver = (booking['driver'] ?? booking['drivers']) as Map<String, dynamic>?;
    final driverUser = driver?['users'] as Map<String, dynamic>?;
    final status = booking['status'] as String? ?? 'pending';
    final breakdown = _getBookingCommissionBreakdown(booking);
    final isPartner = breakdown['is_partner'] == true;
    final canTrack = _canTrackBooking(booking);

    final pickup =
        booking['pickup_location']?.toString() ?? 'Garage Pickup / PSDC';
    final dropoff =
        booking['dropoff_location']?.toString() ?? 'Return to Garage';

    final startDateRaw = booking['start_date'] ?? booking['start_at'];
    final endDateRaw = booking['end_date'] ?? booking['end_at'];
    DateTime? startDt = startDateRaw != null
        ? DateTime.tryParse(startDateRaw.toString())
        : null;
    DateTime? endDt = endDateRaw != null
        ? DateTime.tryParse(endDateRaw.toString())
        : null;

    final createdAtRaw = booking['created_at'];
    DateTime? createdDt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw.toString())
        : null;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isReleasing = false;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Details $refCode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (createdDt != null)
                        Text(
                          'Booked on ${DateFormat('MMMM d, yyyy • h:mm a').format(createdDt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Partner Commission & Disbursement Breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isPartner
                            ? (isDark
                                ? const Color(0xFF0284C7).withValues(alpha: 0.1)
                                : const Color(0xFFF0F9FF))
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isPartner
                              ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                              : (isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isPartner
                                        ? Icons.handshake_rounded
                                        : Icons.apartment_rounded,
                                    size: 18,
                                    color: isPartner
                                        ? const Color(0xFF0284C7)
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isPartner
                                        ? 'Partner Vehicle & Commission Accounting'
                                        : 'PSDC Fleet Direct Revenue',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              _buildCommissionDisbursementBadge(
                                breakdown,
                                isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isPartner) ...[
                            Text(
                              'Partner: ${breakdown['partner_name']} ${breakdown['partner_business_name'] != null ? "(${breakdown['partner_business_name']})" : ""}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            if (breakdown['partner_email'] != null ||
                                breakdown['partner_phone'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Contact: ${breakdown['partner_email'] ?? ''} ${breakdown['partner_phone'] != null ? "• ${breakdown['partner_phone']}" : ""}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            // 3-box financial stat cards
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.black26
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'GROSS TOTAL',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₱${(breakdown['total_amount'] as double).toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF10B981).withValues(
                                              alpha: 0.1,
                                            )
                                          : const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'PARTNER NET (90%)',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₱${(breakdown['partner_net'] as double).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFFD4AF37).withValues(
                                              alpha: 0.1,
                                            )
                                          : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFD4AF37,
                                        ).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'PLATFORM COMM (10%)',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₱${(breakdown['partner_commission'] as double).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (breakdown['status_key'] ==
                                'pending_release') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: isReleasing
                                      ? null
                                      : () async {
                                          setModalState(
                                            () => isReleasing = true,
                                          );
                                          try {
                                            await TripRatingService()
                                                .reconcileCompletedBooking(
                                                  bookingId,
                                                );
                                            await _loadAllBookings();
                                            if (dialogCtx.mounted) {
                                              Navigator.pop(dialogCtx);
                                            }
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Partner commission disbursed successfully!',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.success,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            setModalState(
                                              () => isReleasing = false,
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor:
                                                      AppColors.error,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.payments_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    isReleasing
                                        ? 'Disbursing...'
                                        : 'Disburse & Settle Commission Now',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            Text(
                              'This vehicle is directly owned & managed by PSDC. 100% of revenue (₱${(breakdown['total_amount'] as double).toStringAsFixed(0)}) is retained as internal company revenue.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Section 2: Vehicle & Trip Information
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 72,
                                    height: 56,
                                    color: isDark
                                        ? AppColors.darkBgTertiary
                                        : Colors.grey.shade200,
                                    child: vehicleImg.isNotEmpty
                                        ? OptimizedNetworkImage(
                                            imageUrl: vehicleImg,
                                            fit: BoxFit.cover,
                                            width: 72,
                                            height: 56,
                                            errorWidget: Icon(
                                              Icons.directions_car_rounded,
                                              size: 26,
                                              color: isDark
                                                  ? Colors.grey[600]
                                                  : Colors.grey.shade500,
                                            ),
                                          )
                                        : Icon(
                                            Icons.directions_car_rounded,
                                            size: 26,
                                            color: isDark
                                                ? Colors.grey[600]
                                                : Colors.grey.shade500,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.directions_car_rounded,
                                            size: 16,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Vehicle Info',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        vehicle != null
                                            ? '${vehicle['brand']} ${vehicle['model']} ${vehicle['year'] ?? ''}'
                                            : 'Unknown Vehicle',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Plate Number: ${vehicle?['plate_number'] ?? 'No Plate'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Schedule & Route',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start: ${startDt != null ? DateFormat('MMM d, yyyy • h:mm a').format(startDt) : 'Not set'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'End: ${endDt != null ? DateFormat('MMM d, yyyy • h:mm a').format(endDt) : 'Not set'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pickup: $pickup\nDestination: $dropoff',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 3: Renter & Driver Info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Renter Details',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user?['full_name'] ?? 'Unknown Renter',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Email: ${user?['email'] ?? 'No email'}\nPhone: ${user?['phone'] ?? 'No phone'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.badge_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Driver Details',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  driverUser?['full_name'] ??
                                      'Self-Drive (No Driver)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  driverUser != null
                                      ? 'Email: ${driverUser['email'] ?? 'N/A'}\nPhone: ${driverUser['phone'] ?? 'N/A'}'
                                      : 'Trip is self-driven by renter.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (canTrack)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _openTrackingForBooking(booking);
                  },
                  icon: const Icon(Icons.location_on, size: 16),
                  label: const Text('Live GPS Track'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  static final Map<String, List<MobilisMapPoint>> _trackingRoadRouteCache = {};

  List<MobilisMapPoint> _getTrackingRoutePoints(
    MobilisMapPoint? carPoint,
    MobilisMapPoint? destPoint,
  ) {
    if (carPoint == null) return const [];
    if (destPoint == null) return [carPoint];

    final cacheKey =
        '${carPoint.latitude.toStringAsFixed(3)},${carPoint.longitude.toStringAsFixed(3)}->${destPoint.latitude.toStringAsFixed(3)},${destPoint.longitude.toStringAsFixed(3)}';

    if (_trackingRoadRouteCache.containsKey(cacheKey)) {
      return _trackingRoadRouteCache[cacheKey]!;
    }

    // Trigger async fetch in background
    _fetchRoadPathway(cacheKey, carPoint, destPoint);

    // Fallback straight line while road pathway is loading
    return [carPoint, destPoint];
  }

  Future<void> _fetchRoadPathway(
    String cacheKey,
    MobilisMapPoint fromPoint,
    MobilisMapPoint toPoint,
  ) async {
    if (_trackingRoadRouteCache.containsKey(cacheKey)) return;
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${fromPoint.longitude},${fromPoint.latitude};'
        '${toPoint.longitude},${toPoint.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = payload['routes'] as List<dynamic>? ?? const [];
        if (routes.isNotEmpty) {
          final first = Map<String, dynamic>.from(routes.first as Map);
          final geometry = first['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?;
          if (coordinates != null && coordinates.length >= 2) {
            final roadPoints = coordinates.map((coordinate) {
              final pair = coordinate as List<dynamic>;
              return MobilisMapPoint(
                latitude: (pair[1] as num).toDouble(),
                longitude: (pair[0] as num).toDouble(),
              );
            }).toList();
            _trackingRoadRouteCache[cacheKey] = roadPoints;
            if (mounted) setState(() {});
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Unable to fetch OSRM road route points: $e');
    }
    _trackingRoadRouteCache[cacheKey] = [fromPoint, toPoint];
  }

  MobilisMapPoint? _resolveTrackingLocationPoint(
    dynamic latVal,
    dynamic lngVal,
    String address,
  ) {
    final normalized = address.toLowerCase().trim();

    if (normalized.contains('bayambang')) {
      return const MobilisMapPoint(latitude: 15.8127, longitude: 120.4557);
    }
    if (normalized.contains('san carlos')) {
      return const MobilisMapPoint(latitude: 15.9281, longitude: 120.3488);
    }
    if (normalized.contains('dagupan')) {
      return const MobilisMapPoint(latitude: 16.0433, longitude: 120.3333);
    }
    if (normalized.contains('malasiqui')) {
      return const MobilisMapPoint(latitude: 15.9197, longitude: 120.4144);
    }
    if (normalized.contains('lingayen')) {
      return const MobilisMapPoint(latitude: 16.0218, longitude: 120.2307);
    }
    if (normalized.contains('rosales')) {
      return const MobilisMapPoint(latitude: 15.8925, longitude: 120.6328);
    }
    if (normalized.contains('villasis')) {
      return const MobilisMapPoint(latitude: 15.9011, longitude: 120.5878);
    }
    if (normalized.contains('calasiao')) {
      return const MobilisMapPoint(latitude: 16.0125, longitude: 120.3608);
    }
    if (normalized.contains('binmaley')) {
      return const MobilisMapPoint(latitude: 16.0306, longitude: 120.2689);
    }
    if (normalized.contains('santa barbara')) {
      return const MobilisMapPoint(latitude: 15.9981, longitude: 120.4042);
    }
    if (normalized.contains('bolinao')) {
      return const MobilisMapPoint(latitude: 16.3883, longitude: 119.8949);
    }
    if (normalized.contains('alaminos')) {
      return const MobilisMapPoint(latitude: 16.1558, longitude: 119.9819);
    }
    if (normalized.contains('sison')) {
      return const MobilisMapPoint(latitude: 16.1733, longitude: 120.5089);
    }
    if (normalized.contains('binalonan')) {
      return const MobilisMapPoint(latitude: 16.0489, longitude: 120.5947);
    }
    if (normalized.contains('urdaneta') ||
        normalized.contains('psdc garage') ||
        normalized.contains('xgfw+jq')) {
      return const MobilisMapPoint(latitude: 15.9758, longitude: 120.5719);
    }

    final lat = latVal is num
        ? latVal.toDouble()
        : double.tryParse(latVal?.toString() ?? '');
    final lng = lngVal is num
        ? lngVal.toDouble()
        : double.tryParse(lngVal?.toString() ?? '');

    if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
      return MobilisMapPoint(latitude: lat, longitude: lng);
    }

    return null;
  }

  static final Map<String, DateTime> _vehicleStoppedAt = {};

  static String _formatStoppedDuration(Duration diff) {
    if (diff.isNegative || diff.inMinutes < 1) {
      return '< 1m';
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    if (days > 0) {
      return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    }
    if (diff.inHours > 0) {
      return minutes > 0 ? '${diff.inHours}h ${minutes}m' : '${diff.inHours}h';
    }
    return '${diff.inMinutes}m';
  }

  Map<String, dynamic> _getVehicleMotionInfo(Map<String, dynamic> location) {
    final speedMps = (location['speed_mps'] as num?)?.toDouble() ?? 0.0;
    final speedKph = (speedMps * 3.6).round();
    final recordedAtStr = location['recorded_at']?.toString();
    DateTime? recordedAt;
    if (recordedAtStr != null && recordedAtStr.isNotEmpty) {
      recordedAt = DateTime.tryParse(recordedAtStr)?.toUtc();
    }
    final now = DateTime.now().toUtc();
    final isStale =
        recordedAt == null || now.difference(recordedAt).inMinutes >= 5;
    final isMoving = speedKph >= 3;

    final locKey = location['vehicle_id']?.toString() ??
        location['booking_id']?.toString() ??
        location['id']?.toString() ??
        '';

    if (isMoving) {
      if (locKey.isNotEmpty) {
        _vehicleStoppedAt.remove(locKey);
      }
      return {
        'status': 'moving',
        'label': 'MOVING • $speedKph km/h',
        'short_label': '$speedKph km/h',
        'color': const Color(0xFF00E676),
        'icon': Icons.speed_rounded,
        'speedKph': speedKph,
        'isMoving': true,
        'isParked': false,
        'isStopped': false,
        'stopTime': '0m',
      };
    }

    // Stationary (speed < 3 km/h) -> MARK AS PARKED & CALCULATE STOPPED TIME
    DateTime stoppedSince;
    final explicitStopped = location['stopped_at'] ?? location['stationary_since'];
    if (explicitStopped != null) {
      stoppedSince = DateTime.tryParse(explicitStopped.toString())?.toUtc() ?? recordedAt ?? now;
    } else if (locKey.isNotEmpty && _vehicleStoppedAt.containsKey(locKey)) {
      stoppedSince = _vehicleStoppedAt[locKey]!;
    } else {
      stoppedSince = recordedAt ?? now;
      if (locKey.isNotEmpty) {
        _vehicleStoppedAt[locKey] = stoppedSince;
      }
    }

    final diff = now.difference(stoppedSince);
    final durationText = _formatStoppedDuration(diff);

    if (isStale) {
      return {
        'status': 'parked',
        'label': 'PARKED • ENGINE OFF ($durationText)',
        'short_label': 'PARKED (OFF • $durationText)',
        'color': const Color(0xFF9E9E9E),
        'icon': Icons.local_parking_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': true,
        'isStopped': true,
        'stopTime': durationText,
        'stoppedSince': stoppedSince,
      };
    } else {
      return {
        'status': 'parked',
        'label': 'PARKED • IDLING ($durationText)',
        'short_label': 'PARKED ($durationText)',
        'color': const Color(0xFFFF9100),
        'icon': Icons.local_parking_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': true,
        'isStopped': true,
        'stopTime': durationText,
        'stoppedSince': stoppedSince,
      };
    }
  }

  Widget _buildMovementStatusChip({
    required Map<String, dynamic> location,
    required bool isDark,
    bool isCompact = false,
  }) {
    final motion = _getVehicleMotionInfo(location);
    final color = motion['color'] as Color;
    final label =
        isCompact ? motion['short_label'] as String : motion['label'] as String;
    final icon = motion['icon'] as IconData;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 7 : 9,
        vertical: isCompact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isCompact ? 11 : 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
