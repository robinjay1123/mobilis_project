part of '../dashboard_screen.dart';

extension _DashboardProfileTab on _DashboardScreenState {
  Widget _buildProfileTab() {
    if (selectedProfilePage == 'settings') {
      return SettingsScreen(
        onThemeToggle: widget.onThemeToggle,
        isDarkMode: widget.isDarkMode,
        onBack: () => setState(() => selectedProfilePage = null),
        onOpenSupport: _openCustomerServiceConversation,
        onProfileUpdated: _loadUserData,
      );
    } else if (selectedProfilePage == 'payment') {
      return PaymentMethodsScreen(
        isDarkMode: widget.isDarkMode,
        onBack: () => setState(() => selectedProfilePage = null),
      );
    } else if (selectedProfilePage == 'verification') {
      return VerificationDocumentsScreen(
        isDarkMode: widget.isDarkMode,
        onBack: () => setState(() => selectedProfilePage = null),
      );
    } else if (selectedProfilePage == 'favorites') {
      return _buildFavoriteVehiclesPage();
    }

    return UnifiedProfileScreen(
      role: 'renter',
      isDarkMode: widget.isDarkMode,
      onThemeToggle: widget.onThemeToggle,
      onProfileUpdated: _loadUserData,
      onOpenSupport: _openCustomerServiceConversation,
      onOpenVerification: () =>
          setState(() => selectedProfilePage = 'verification'),
      onOpenFavorites: () => setState(() => selectedProfilePage = 'favorites'),
      initialProfile: {
        'full_name': userName,
        'location': userLocation,
        'avatar_url': userAvatarUrl,
        'id_verified': userVerified,
      },
      stats: [
        ProfileStatItem(
          label: 'Trips',
          value: '$_totalTrips',
          onTap: () => setState(() => selectedNavIndex = 1),
        ),
        ProfileStatItem(
          label: 'Loyalty',
          value: userVerified ? 'Verified' : 'Basic',
        ),
        ProfileStatItem(
          label: 'Rating',
          value: _userRating > 0 ? _userRating.toStringAsFixed(1) : '0.0',
          onTap: () {
            final userId = AuthService().currentUser?.id;
            if (userId == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RatingsReviewsScreen(
                  userId: userId,
                  title: 'My Ratings & Reviews',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileMenuOption(
    IconData icon,
    String label, {
    int badgeCount = 0,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteVehiclesPage() {
    final user = AuthService().currentUser;

    return Column(
      children: [
        Container(
          color: AppColors.darkBg,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            12,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => selectedProfilePage = null),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
              ),
              const Expanded(
                child: Text(
                  'Liked Cars',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: user == null
              ? const Center(
                  child: Text(
                    'Sign in to see liked cars',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : FutureBuilder<List<Map<String, dynamic>>>(
                  future: FavoriteVehicleService().getFavoriteVehicles(user.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return MobilisSkeletonVehicleGrid(
                        isDark: Theme.of(context).brightness == Brightness.dark,
                        count: 2,
                        padding: const EdgeInsets.all(16),
                      );
                    }

                    final vehicles = snapshot.data ?? [];
                    if (vehicles.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.favorite_border,
                                size: 54,
                                color: AppColors.textTertiary,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No liked cars yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Tap the heart on a car to save it here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _loadFavoriteVehicleIds,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: vehicles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final vehicle = vehicles[index];
                          return _buildLikedVehicleTile(vehicle);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLikedVehicleTile(Map<String, dynamic> vehicle) {
    final name =
        '${vehicle['brand'] ?? 'Unknown'} ${vehicle['model'] ?? 'Vehicle'}';
    final category =
        (vehicle['vehicle_type'] ?? vehicle['category'] ?? 'Standard')
            .toString();
    final price = (vehicle['price_per_day'] as num?)?.toDouble() ?? 0;

    return InkWell(
      onTap: () {
        _openVehicleDetail(
          vehicleId: vehicle['id']?.toString() ?? '',
          vehicleData: vehicle,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                height: 64,
                child: VehicleImageCarousel(
                  key: ValueKey('favorite-car-${vehicle['id']}'),
                  vehicle: vehicle,
                  height: 64,
                  backgroundColor: AppColors.darkBgTertiary,
                  iconColor: AppColors.textTertiary,
                  showArrows: false,
                  showIndicator: false,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₱${formatAmount(price, decimalDigits: 0)} / day',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _toggleFavoriteVehicle(vehicle),
              icon: const Icon(Icons.favorite, color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  bool _isBookingWithDriver(Map<String, dynamic> booking) {
    final rentalType = (booking['rental_type'] ?? booking['rentalType'] ?? '').toString().toLowerCase().trim();
    if (rentalType == 'self_drive' || rentalType == 'self drive' || rentalType == 'selfdrive') {
      return false;
    }
    final withDriver = booking['withDriver'] == true ||
        booking['with_driver'] == true ||
        booking['with_driver'] == 1 ||
        booking['with_driver']?.toString().toLowerCase() == 'true';
    if (!withDriver) return false;
    return true;
  }
}

