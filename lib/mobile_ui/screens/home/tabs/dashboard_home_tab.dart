part of '../dashboard_screen.dart';

extension _DashboardHomeTab on _DashboardScreenState {
  Widget _buildHomeTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? AppColors.darkBgSecondary
        : AppColors.lightBgSecondary;
    final mutedCardColor = isDark
        ? AppColors.darkBgTertiary
        : AppColors.lightBgTertiary;
    final borderColor = isDark
        ? AppColors.borderColor
        : AppColors.lightBorderColor;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    final tertiaryTextColor = isDark
        ? AppColors.textTertiary
        : AppColors.lightTextTertiary;
    final uiBookings = _uiBookings();
    final homeTrips = uiBookings
        .where(
          (b) =>
              b['statusGroup'] == 'Pending' ||
              b['statusGroup'] == 'Approved' ||
              b['statusGroup'] == 'Ongoing',
        )
        .take(10)
        .toList();

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.of(context).padding.top + 24,
                24,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        child: Container(
                          width: 48,
                          height: 48,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: userAvatarUrl?.trim().isNotEmpty == true
                              ? OptimizedNetworkImage(
                                  imageUrl: userAvatarUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  isThumbnail: true,
                                  errorWidget: const Icon(
                                    Icons.person,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.person, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome,',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  status: userVerified
                                      ? 'Verified'
                                      : 'Basic Renter',
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  borderRadius: 6,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Compact location field; the map opens only when needed.
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openCurrentLocationPicker,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(28),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CURRENT LOCATION',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    userLocation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchVehiclesByLocation(),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Search city, location, brand, or model...',
                        hintStyle: TextStyle(color: tertiaryTextColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: tertiaryTextColor,
                        ),
                        suffixIcon: Tooltip(
                          message: 'Search location',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _isSearchingVehicles
                                ? null
                                : _searchVehiclesByLocation,
                            child: Container(
                              width: 42,
                              height: 42,
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _isSearchingVehicles
                                  ? const Padding(
                                      padding: EdgeInsets.all(11),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.search,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_nearbyLatitude != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(28),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.success.withAlpha(120),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.success,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Showing cars near ${_nearbyLocationLabel ?? 'you'}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearNearbyVehicleFilter,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_bookingFilterFrom == null && _bookingFilterTo == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isOpeningBookNowCalendar ? null : _selectBookNowDates,
                        icon: _isOpeningBookNowCalendar
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.calendar_month),
                        label: Text(_isOpeningBookNowCalendar ? 'Checking dates...' : 'Book Now!'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: (_isLoadingVehicles || _isOpeningBookNowCalendar)
                              ? null
                              : _resetBookNowDateFilter,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isOpeningBookNowCalendar ? null : _selectBookNowDates,
                            icon: _isOpeningBookNowCalendar
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.calendar_month, size: 19),
                            label: Text(
                              _isOpeningBookNowCalendar
                                  ? 'Checking...'
                                  : _formatDateRange(
                                      _bookingFilterFrom,
                                      _bookingFilterTo,
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // ── Your Trips ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Trips',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => selectedNavIndex = 1),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 200,
                child: homeTrips.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Center(
                          child: Text(
                            'No trips yet',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: homeTrips.length,
                        itemBuilder: (context, index) {
                          final booking = homeTrips[index];
                          final imageUrl = booking['imageUrl']
                              ?.toString()
                              .trim();
                          final hasImage =
                              imageUrl != null && imageUrl.isNotEmpty;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 260,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 100,
                                      width: double.infinity,
                                      child: _buildFastVehicleImage(
                                        imageUrl: hasImage ? imageUrl : null,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        backgroundColor: mutedCardColor,
                                        iconColor: tertiaryTextColor,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            booking['carName'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            booking['rentalPartner'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 9),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 12,
                                                color: tertiaryTextColor,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${booking['days']} days',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: secondaryTextColor,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              if (((booking['rating'] as num?)
                                                          ?.toDouble() ??
                                                      0) >
                                                  0) ...[
                                                const Icon(
                                                  Icons.star,
                                                  size: 12,
                                                  color: AppColors.ratingGold,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  (booking['rating'] as num)
                                                      .toStringAsFixed(1),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: secondaryTextColor,
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
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Categories ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VehicleSearchScreen(
                            initialCategory: selectedCategory.isEmpty
                                ? null
                                : selectedCategory,
                            initialAvailableFrom: _bookingFilterFrom,
                            initialAvailableTo: _bookingFilterTo,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final categoryName = category['name'] as String;
                    final isSelected = categoryName == 'All Cars'
                        ? selectedCategory.isEmpty
                        : selectedCategory == categoryName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = categoryName == 'All Cars'
                                ? ''
                                : categoryName;
                            _isLoadingVehicles = true;
                          });
                          _loadVehicles();
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : borderColor,
                                ),
                              ),
                              child: Icon(
                                category['icon'] as IconData,
                                color: isSelected
                                    ? Colors.black
                                    : secondaryTextColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              categoryName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Keep partner vehicles visible immediately below categories.
            _buildPartnersNearYouSection(
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Cars',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${_filteredVehicles.length} cars',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VehicleSearchScreen(
                                initialCategory: selectedCategory.isEmpty
                                    ? null
                                    : selectedCategory,
                                initialAvailableFrom: _bookingFilterFrom,
                                initialAvailableTo: _bookingFilterTo,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _isLoadingVehicles
                ? MobilisSkeletonVehicleGrid(
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    count: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  )
                : _vehicles.isEmpty || _filteredVehicles.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Opacity(
                              opacity: 0.3,
                              child: Image.asset(
                                'assets/icon/logo1.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _vehicles.isEmpty
                                ? 'No vehicles available'
                                : _nearbyLatitude != null
                                ? 'No cars found near ${_nearbyLocationLabel ?? 'you'}'
                                : 'No cars match your search',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_filteredVehicles.isEmpty &&
                              _vehicles.isNotEmpty &&
                              _nearbyLatitude != null) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _clearNearbyVehicleFilter,
                              icon: const Icon(Icons.location_off_outlined),
                              label: const Text('Show all cars'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _filteredVehicles.length,
                    itemBuilder: (context, index) {
                      final car = _filteredVehicles[index];
                      final carName = toProfessionalTitleCase(
                        '${car['brand'] ?? 'Unknown'} ${car['model'] ?? 'Model'}',
                      );
                      final category =
                          (car['vehicle_type'] ?? car['category'] ?? 'Standard')
                              .toString()
                              .toUpperCase();

                      // ✅ FIX: Separate hour and day prices
                      final pricePerHour =
                          (car['price_per_hour'] as num?)?.toDouble() ?? 0.0;
                      final pricePerDay =
                          (car['price_per_day'] as num?)?.toDouble() ?? 0.0;

                      final rawRating =
                          (car['rating'] as num?)?.toDouble() ?? 0.0;
                      final rawCount =
                          (car['rating_count'] as num?)?.toInt() ?? 0;
                      // Only show a real rating when there are actual reviews.
                      // Never fabricate a count.
                      final rating = rawRating;
                      final ratingCount = rawCount;
                      final vehicleType = toProfessionalTitleCase(
                        (car['vehicle_type'] ?? 'Standard').toString(),
                      );
                      final color = toProfessionalTitleCase(
                        (car['color'] ?? 'Unknown').toString(),
                      );
                      final seats = car['seats'] ?? 5;

                      // ✅ FIX: Read transmission field instead of reusing vehicleType
                      final transmission = toProfessionalTitleCase(
                        (car['transmission'] ?? 'Manual').toString(),
                      );

                      final isPartnerVehicle =
                          car['source']?.toString().toLowerCase() ==
                              'partner' ||
                          car['is_partner_vehicle'] == true ||
                          car['owner_role']?.toString().toLowerCase() ==
                              'partner' ||
                          car['partner_vehicle_id'] != null;
                      final partnerName =
                          car['partner_name']?.toString().trim().isNotEmpty ==
                              true
                          ? toProfessionalTitleCase(
                              car['partner_name'].toString(),
                            )
                          : 'Mobilis Partner';
                      final providerName = isPartnerVehicle
                          ? 'PSDC Partner'
                          : 'PSDC';
                      final vehicleId = car['id']?.toString() ?? '';
                      final isFavorite = _favoriteVehicleIds.contains(
                        vehicleId,
                      );
                      final distanceKm = (car['distance_km'] as num?)
                          ?.toDouble();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () {
                            _openVehicleDetail(
                              vehicleId: car['id']?.toString() ?? '',
                              vehicleData: car,
                              startDate: _bookingFilterFrom,
                              endDate: _bookingFilterTo,
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        height: 200,
                                        color: mutedCardColor,
                                        child: VehicleImageCarousel(
                                          key: ValueKey(
                                            'renter-car-$vehicleId',
                                          ),
                                          vehicle: car,
                                          height: 200,
                                          backgroundColor: mutedCardColor,
                                          iconColor: tertiaryTextColor,
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        left: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cardColor,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: borderColor,
                                            ),
                                          ),
                                          child: Text(
                                            providerName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cardColor,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: borderColor,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              if (ratingCount > 0) ...
                                                [
                                                  const Icon(
                                                    Icons.star,
                                                    color: AppColors.ratingGold,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${rating.toStringAsFixed(1)} ($ratingCount)',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                ]
                                              else ...
                                                [
                                                  Text(
                                                    'New',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: GestureDetector(
                                          onTap: () =>
                                              _toggleFavoriteVehicle(car),
                                          child: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isFavorite
                                                    ? AppColors.error
                                                    : borderColor,
                                              ),
                                            ),
                                            child: Icon(
                                              isFavorite
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isFavorite
                                                  ? AppColors.error
                                                  : secondaryTextColor,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          carName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        if (isPartnerVehicle) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withOpacity(0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: const Text(
                                                  'FROM PARTNERS',
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  partnerName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: secondaryTextColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: tertiaryTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Keep all primary specs in one row.
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildFeatureIcon(
                                                    Icons.directions_car,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    vehicleType.toString(),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: secondaryTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildFeatureIcon(
                                                    Icons.palette_outlined,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    color.toString(),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: secondaryTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildFeatureIcon(
                                                    Icons.person,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$seats Seats',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: secondaryTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildFeatureIcon(
                                                    Icons.settings_outlined,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    transmission,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: secondaryTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (distanceKm != null) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              _buildFeatureIcon(
                                                Icons.location_on_outlined,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${distanceKm.toStringAsFixed(distanceKm < 10 ? 1 : 0)} km away',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: secondaryTextColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // ✅ FIX: Show both per hour and per day prices
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (pricePerHour > 0)
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              '₱${formatAmount(pricePerHour, decimalDigits: 0)}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: AppColors
                                                                    .primary,
                                                              ),
                                                        ),
                                                        TextSpan(
                                                          text: '/hr',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                secondaryTextColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (pricePerDay > 0)
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              '₱${formatAmount(pricePerDay, decimalDigits: 0)}',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                secondaryTextColor,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: '/day',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                secondaryTextColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            Builder(
                                              builder: (context) {
                                                final carId = car['id']?.toString() ?? '';
                                                final isNavigatingThis = _navigatingVehicleId == carId;

                                                return SizedBox(
                                                  height: 44,
                                                  child: ElevatedButton(
                                                    onPressed: _navigatingVehicleId != null
                                                        ? null
                                                        : () async {
                                                            setState(() => _navigatingVehicleId = carId);
                                                            try {
                                                              if (await _checkRentalVerification() &&
                                                                  await _canOpenVehicleBooking(car)) {
                                                                if (!mounted) return;
                                                                await Navigator.of(context).pushNamed(
                                                                  '/vehicle-detail',
                                                                  arguments: {
                                                                    'vehicleId': carId,
                                                                    'vehicleData': car,
                                                                    'initialStartDate': _bookingFilterFrom,
                                                                    'initialEndDate': _bookingFilterTo,
                                                                  },
                                                                );
                                                              }
                                                            } finally {
                                                              if (mounted) {
                                                                setState(() => _navigatingVehicleId = null);
                                                              }
                                                            }
                                                          },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.primary,
                                                      foregroundColor: Colors.black,
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                    child: isNavigatingThis
                                                        ? const SizedBox(
                                                            width: 18,
                                                            height: 18,
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: Colors.black,
                                                            ),
                                                          )
                                                        : const Text(
                                                            'Book Now',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnersNearYouSection({
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    bool isPartnerVehicle(Map<String, dynamic> vehicle) {
      final source = vehicle['source']?.toString().toLowerCase();
      final ownerRole = vehicle['owner_role']?.toString().toLowerCase();
      final owner = vehicle['owner'];
      final relatedOwnerRole = owner is Map
          ? owner['role']?.toString().toLowerCase()
          : null;
      return source == 'partner' ||
          ownerRole == 'partner' ||
          relatedOwnerRole == 'partner' ||
          vehicle['is_partner_vehicle'] == true;
    }

    final allPartnerVehicles = _vehicles.where(isPartnerVehicle).toList();
    final nearbyPartnerIds = _filteredVehicles
        .where(isPartnerVehicle)
        .map((vehicle) => vehicle['id']?.toString())
        .whereType<String>()
        .toSet();
    final nearbyPartnerVehicles = allPartnerVehicles
        .where(
          (vehicle) => nearbyPartnerIds.contains(vehicle['id']?.toString()),
        )
        .toList();
    final partnerVehicles =
        _nearbyLatitude != null && nearbyPartnerVehicles.isNotEmpty
        ? nearbyPartnerVehicles
        : allPartnerVehicles;

    if (partnerVehicles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Partners',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${partnerVehicles.length} car${partnerVehicles.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VehicleSearchScreen(
                            initialOnlyPartners: true,
                            initialAvailableFrom: _bookingFilterFrom,
                            initialAvailableTo: _bookingFilterTo,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 218,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: partnerVehicles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final vehicle = partnerVehicles[index];
                final vehicleId = vehicle['id']?.toString() ?? '';
                final title = toProfessionalTitleCase(
                  '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}',
                );
                final partnerName =
                    vehicle['partner_name']?.toString().trim().isNotEmpty ==
                        true
                    ? toProfessionalTitleCase(
                        vehicle['partner_name'].toString(),
                      )
                    : toProfessionalTitleCase(
                        vehicle['owner_name']?.toString() ?? 'Mobilis Partner',
                      );
                final dailyPrice =
                    (vehicle['price_per_day'] as num?)?.toDouble() ?? 0;
                final hourlyPrice =
                    (vehicle['price_per_hour'] as num?)?.toDouble() ?? 0;

                return GestureDetector(
                  onTap: vehicleId.isEmpty
                      ? null
                      : () => _openVehicleDetail(
                          vehicleId: vehicleId,
                          vehicleData: vehicle,
                          startDate: _bookingFilterFrom,
                          endDate: _bookingFilterTo,
                        ),
                  child: Container(
                    width: 232,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 112,
                          width: double.infinity,
                          child: VehicleImageCarousel(
                            key: ValueKey('partner-car-$vehicleId'),
                            vehicle: vehicle,
                            height: 112,
                            backgroundColor: cardColor,
                            iconColor: secondaryTextColor,
                            showArrows: false,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? 'Partner Vehicle' : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                partnerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.payments_outlined,
                                    color: AppColors.primary,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dailyPrice > 0
                                          ? 'PHP ${formatAmount(dailyPrice, decimalDigits: 0)} / day'
                                          : 'PHP ${formatAmount(hourlyPrice, decimalDigits: 0)} / hour',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }
}

