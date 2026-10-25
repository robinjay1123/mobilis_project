part of '../partner_home_screen.dart';

extension _PartnerTrackingTab on _PartnerHomeScreenState {

  List<Map<String, dynamic>> _visiblePartnerTrackingLocations() {
    final query = _partnerTrackingSearchController.text.trim().toLowerCase();
    var list = List<Map<String, dynamic>>.from(trackingLocations);

    // 🔒 STRICT PARTNER VEHICLE ISOLATION:
    // Ensure that only the partner's registered or applied vehicles can be shown
    if (applications.isNotEmpty || bookings.isNotEmpty) {
      final allowedIds = <String>{};
      final allowedPlates = <String>{};

      for (final app in applications) {
        final id = app['id']?.toString().trim();
        final pvid = app['partner_vehicle_id']?.toString().trim();
        final cvid = app['created_vehicle_id']?.toString().trim();
        final plate = (app['plate_number'] ?? '')
            .toString()
            .trim()
            .toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (id != null && id.isNotEmpty) allowedIds.add(id);
        if (pvid != null && pvid.isNotEmpty) allowedIds.add(pvid);
        if (cvid != null && cvid.isNotEmpty) allowedIds.add(cvid);
        if (plate.isNotEmpty) allowedPlates.add(plate);
      }

      for (final b in bookings) {
        final bId = b['id']?.toString().trim();
        final bVid = b['vehicle_id']?.toString().trim();
        final vMap = b['vehicles'] as Map<String, dynamic>?;
        final vId = vMap?['id']?.toString().trim();
        final plate = (vMap?['plate_number'] ?? '')
            .toString()
            .trim()
            .toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (bId != null && bId.isNotEmpty) allowedIds.add(bId);
        if (bVid != null && bVid.isNotEmpty) allowedIds.add(bVid);
        if (vId != null && vId.isNotEmpty) allowedIds.add(vId);
        if (plate.isNotEmpty) allowedPlates.add(plate);
      }

      list = list.where((loc) {
        final vid = loc['vehicle_id']?.toString().trim() ?? '';
        final b = loc['bookings'] as Map<String, dynamic>?;
        final bId = (b?['id'] ?? loc['booking_id'])?.toString().trim() ?? '';
        final bVid = (b?['vehicle_id'] ?? b?['vehicles']?['id'])?.toString().trim() ?? '';
        final vMap = (loc['vehicle'] ?? b?['vehicles']) as Map<String, dynamic>?;
        final vId = vMap?['id']?.toString().trim() ?? '';
        final plate = (vMap?['plate_number'] ?? '')
            .toString()
            .trim()
            .toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]'), '');

        return allowedIds.contains(vid) ||
            allowedIds.contains(bId) ||
            allowedIds.contains(bVid) ||
            allowedIds.contains(vId) ||
            (plate.isNotEmpty && allowedPlates.contains(plate));
      }).toList();
    }

    // Filter by tab: all, active, idle
    if (_partnerTrackingFilter == 'active') {
      list = list.where((loc) => loc['has_active_booking'] == true).toList();
    } else if (_partnerTrackingFilter == 'idle') {
      list = list.where((loc) => loc['has_active_booking'] != true).toList();
    }

    // Filter by search query
    if (query.isNotEmpty) {
      list = list.where((loc) {
        final vName = _resolvePartnerTrackingVehicleName(loc).toLowerCase();
        final booking = loc['bookings'] as Map<String, dynamic>?;
        final renter = booking?['renter'] as Map<String, dynamic>?;
        final renterName = (renter?['full_name'] ?? '').toString().toLowerCase();
        final driver = (booking?['driver'] ?? booking?['drivers'])?['users'] as Map<String, dynamic>?;
        final driverName = (driver?['full_name'] ?? '').toString().toLowerCase();
        final plate = ((loc['vehicle'] ?? booking?['vehicles'])?['plate_number'] ?? '').toString().toLowerCase();
        return vName.contains(query) ||
            renterName.contains(query) ||
            driverName.contains(query) ||
            plate.contains(query);
      }).toList();
    }

    // If focused on a specific vehicle, put it first
    if (_focusedTrackingBookingId != null && _focusedTrackingBookingId!.isNotEmpty) {
      final focusedIndex = list.indexWhere((loc) {
        final booking = loc['bookings'] as Map<String, dynamic>?;
        final rowId = booking?['id']?.toString() ??
            loc['id']?.toString() ??
            'vehicle_${loc['vehicle_id']}';
        return rowId == _focusedTrackingBookingId;
      });
      if (focusedIndex > 0) {
        final focusedItem = list.removeAt(focusedIndex);
        list.insert(0, focusedItem);
      }
    }

    return list;
  }

  Map<String, dynamic> _getPartnerVehicleMotionInfo(Map<String, dynamic> loc) {
    final speedMps = (loc['speed_mps'] as num?)?.toDouble() ?? 0.0;
    final speedKph = (speedMps * 3.6).round();
    final isTripActive = loc['has_active_booking'] == true;
    final recordedAt = DateTime.tryParse(loc['recorded_at']?.toString() ?? '');
    final isStale = recordedAt == null ||
        DateTime.now().toUtc().difference(recordedAt) > const Duration(minutes: 30);

    final isStandby = loc['is_standby'] == true;
    if (isStandby) {
      return {
        'status': 'standby',
        'label': 'STANDBY • AWAITING GPS FIX',
        'short_label': 'STANDBY',
        'color': const Color(0xFF38BDF8),
        'icon': Icons.satellite_alt_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': true,
        'isStopped': false,
      };
    }

    if (speedKph >= 5) {
      return {
        'status': 'moving',
        'label': 'MOVING • $speedKph KM/H',
        'short_label': '$speedKph KM/H',
        'color': const Color(0xFF00E676),
        'icon': Icons.navigation_rounded,
        'speedKph': speedKph,
        'isMoving': true,
        'isParked': false,
        'isStopped': false,
      };
    } else if (isTripActive) {
      return {
        'status': 'on_trip_stopped',
        'label': 'ON TRIP • IDLING',
        'short_label': 'IDLING',
        'color': const Color(0xFFFFB300),
        'icon': Icons.pause_circle_filled_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': false,
        'isStopped': true,
      };
    } else if (isStale) {
      return {
        'status': 'parked',
        'label': 'PARKED • ENGINE OFF',
        'short_label': 'PARKED (OFF)',
        'color': const Color(0xFF9E9E9E),
        'icon': Icons.power_settings_new_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': true,
        'isStopped': false,
      };
    } else {
      return {
        'status': 'stopped',
        'label': 'AVAILABLE • IDLE',
        'short_label': 'IDLE',
        'color': const Color(0xFF38BDF8),
        'icon': Icons.local_parking_rounded,
        'speedKph': 0,
        'isMoving': false,
        'isParked': false,
        'isStopped': true,
      };
    }
  }

  Widget _buildPartnerMovementStatusChip({
    required Map<String, dynamic> location,
    required bool isDark,
    bool isCompact = false,
  }) {
    final motion = _getPartnerVehicleMotionInfo(location);
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

  String _resolvePartnerTrackingVehicleName(Map<String, dynamic> loc) {
    final booking = loc['bookings'] as Map<String, dynamic>?;
    final vehicle = (booking?['vehicles'] ?? loc['vehicle']) as Map<String, dynamic>?;
    final tracker = loc['tracker'] as Map<String, dynamic>?;

    var title = _partnerVehicleTitle(vehicle ?? booking);
    if (title.isEmpty || title == 'Partner Vehicle' || title == 'Vehicle') {
      final vName = vehicle?['vehicle_name']?.toString().trim() ?? '';
      if (vName.isNotEmpty &&
          vName.toLowerCase() != 'partner vehicle' &&
          vName.toLowerCase() != 'vehicle') {
        title = vName;
      } else {
        final b = vehicle?['brand']?.toString().trim() ?? '';
        final m = vehicle?['model']?.toString().trim() ?? '';
        final y = vehicle?['year']?.toString().trim() ?? '';
        final combo = [b, m].where((s) => s.isNotEmpty).join(' ');
        if (combo.isNotEmpty) {
          title = y.isEmpty ? combo : '$combo ($y)';
        }
      }
    }

    final deviceId = tracker?['device_identifier']?.toString().trim() ?? '';
    if (title.isEmpty || title == 'Partner Vehicle' || title == 'Vehicle') {
      if (deviceId.isNotEmpty) {
        title = 'GPS Tracker ($deviceId)';
      } else {
        title = loc['has_active_booking'] == true ? 'Tracked Trip' : 'Partner Vehicle';
      }
    }

    final plate = vehicle?['plate_number']?.toString().trim() ?? '';
    if (plate.isNotEmpty && !title.contains(plate)) {
      return '$title ($plate)';
    }
    return title;
  }

  MobilisMapPoint? _resolvePartnerTrackingPoint(
    dynamic latVal,
    dynamic lngVal,
    String locText,
  ) {
    final lat = latVal is num
        ? latVal.toDouble()
        : double.tryParse(latVal?.toString() ?? '');
    final lng = lngVal is num
        ? lngVal.toDouble()
        : double.tryParse(lngVal?.toString() ?? '');
    if (lat != null && lng != null && PhilippineGeocoding.isValidPhilippines(MobilisMapPoint(latitude: lat, longitude: lng))) {
      return MobilisMapPoint(latitude: lat, longitude: lng);
    }
    final parsed = PhilippineGeocoding.parseCoordinate(latVal, lngVal);
    if (parsed != null && PhilippineGeocoding.isValidPhilippines(parsed)) {
      return parsed;
    }
    return PhilippineGeocoding.resolveLocationSync(locText);
  }

  List<MobilisMapPoint> _getPartnerTrackingRoutePoints(
    MobilisMapPoint start,
    MobilisMapPoint end,
  ) {
    return [
      start,
      MobilisMapPoint(
        latitude: (start.latitude + end.latitude) / 2,
        longitude: (start.longitude + end.longitude) / 2,
      ),
      end,
    ];
  }

  void _openLiveTracking({String? focusBookingId}) {
    if (focusBookingId != null && focusBookingId.isNotEmpty) {
      setState(() {
        _focusedTrackingBookingId = focusBookingId;
      });
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: widget.isDarkMode ? AppColors.darkBg : AppColors.lightBg,
          appBar: AppBar(
            backgroundColor: widget.isDarkMode ? AppColors.darkBgSecondary : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Live Fleet Tracking',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.primary,
                tooltip: 'Refresh GPS locations',
                onPressed: () => _refreshPartnerTracking(silent: false),
              ),
            ],
          ),
          body: _buildTrackingTab(isStandalonePage: true),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildTrackingTab({bool isStandalonePage = false}) {
    final isDark = widget.isDarkMode;
    final visibleLocations = _visiblePartnerTrackingLocations();
    final isFocused = _focusedTrackingBookingId != null &&
        _focusedTrackingBookingId!.isNotEmpty;

    final totalCount = trackingLocations.length;
    final activeCount = trackingLocations
        .where((loc) => loc['has_active_booking'] == true)
        .length;
    final idleCount = totalCount - activeCount;

    // Focused trip details
    Map<String, dynamic>? focusedLocation;
    MobilisMapPoint? pickupPoint;
    MobilisMapPoint? destPoint;
    double? remainingDistanceKm;
    bool focusedHasActiveBooking = false;

    if (isFocused && visibleLocations.isNotEmpty) {
      focusedLocation = visibleLocations.first;
      focusedHasActiveBooking = focusedLocation['has_active_booking'] == true &&
          focusedLocation['bookings'] != null;

      if (focusedHasActiveBooking) {
        final fBooking = focusedLocation['bookings'] as Map<String, dynamic>?;
        pickupPoint = _resolvePartnerTrackingPoint(
          fBooking?['pickup_latitude'],
          fBooking?['pickup_longitude'],
          fBooking?['pickup_location']?.toString() ?? '',
        );
        destPoint = _resolvePartnerTrackingPoint(
          fBooking?['dropoff_latitude'],
          fBooking?['dropoff_longitude'],
          fBooking?['dropoff_location']?.toString() ?? '',
        );

        final carLat = (focusedLocation['latitude'] as num?)?.toDouble();
        final carLng = (focusedLocation['longitude'] as num?)?.toDouble();
        if (carLat != null && carLng != null && destPoint != null) {
          remainingDistanceKm = Geolocator.distanceBetween(
                carLat,
                carLng,
                destPoint.latitude,
                destPoint.longitude,
              ) /
              1000;
        }
      }
    }

    // Build map markers
    final mapMarkers = <MobilisMapMarker>[];
    List<MobilisMapPoint> routePoints = const [];

    if (isFocused && focusedLocation != null) {
      final vehicleName = _resolvePartnerTrackingVehicleName(focusedLocation);
      final carLat = (focusedLocation['latitude'] as num?)?.toDouble();
      final carLng = (focusedLocation['longitude'] as num?)?.toDouble();
      final motion = _getPartnerVehicleMotionInfo(focusedLocation);
      final motionColor = motion['color'] as Color;

      if (focusedHasActiveBooking && pickupPoint != null) {
        mapMarkers.add(
          MobilisMapMarker(
            latitude: pickupPoint.latitude,
            longitude: pickupPoint.longitude,
            icon: Icons.trip_origin_rounded,
            color: Colors.greenAccent.shade700,
            size: 32,
            tooltip: 'Pickup Location',
          ),
        );
      }

      if (carLat != null && carLng != null) {
        final carPoint = MobilisMapPoint(latitude: carLat, longitude: carLng);
        mapMarkers.add(
          MobilisMapMarker(
            latitude: carLat,
            longitude: carLng,
            icon: Icons.directions_car_filled_rounded,
            color: motionColor,
            size: 42,
            tooltip: vehicleName.isNotEmpty
                ? '$vehicleName • ${motion['label']}'
                : 'Partner Vehicle • ${motion['label']}',
            label: vehicleName.isNotEmpty
                ? '$vehicleName (${motion['short_label']})'
                : motion['label'],
          ),
        );

        if (focusedHasActiveBooking && destPoint != null) {
          routePoints = _getPartnerTrackingRoutePoints(carPoint, destPoint);
        }
      }

      if (focusedHasActiveBooking && destPoint != null) {
        mapMarkers.add(
          MobilisMapMarker(
            latitude: destPoint.latitude,
            longitude: destPoint.longitude,
            icon: Icons.flag_rounded,
            color: Colors.redAccent,
            size: 38,
            tooltip: 'Declared Destination',
          ),
        );
      }
    } else {
      // Show all partner vehicle markers
      for (final loc in visibleLocations) {
        final lat = (loc['latitude'] as num?)?.toDouble();
        final lng = (loc['longitude'] as num?)?.toDouble();
        final booking = loc['bookings'] as Map<String, dynamic>?;
        final vehicleName = _resolvePartnerTrackingVehicleName(loc);

        final locId = booking?['id']?.toString() ??
            loc['id']?.toString() ??
            'vehicle_${loc['vehicle_id']}';
        final motion = _getPartnerVehicleMotionInfo(loc);
        final motionColor = motion['color'] as Color;

        if (lat != null && lng != null) {
          mapMarkers.add(
            MobilisMapMarker(
              latitude: lat,
              longitude: lng,
              icon: Icons.directions_car_filled_rounded,
              color: motionColor,
              size: 36,
              tooltip: vehicleName.isNotEmpty
                  ? '$vehicleName • ${motion['label']}'
                  : 'Partner Vehicle • ${motion['label']}',
              label: vehicleName.isNotEmpty
                  ? '$vehicleName (${motion['short_label']})'
                  : motion['short_label'],
              onTap: () {
                if (locId.isNotEmpty) {
                  setState(() => _focusedTrackingBookingId = locId);
                }
              },
            ),
          );
        }
      }
    }

    final trackingContent = RefreshIndicator(
            onRefresh: () => _refreshPartnerTracking(silent: false),
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                // Top Header Card
                RoleTabHeader(
                  title: 'Live Tracking',
                  subtitle: 'Real-time GPS monitor for your vehicles ($totalCount total)',
                  icon: Icons.radar_rounded,
                  badge: '${visibleLocations.length} Online',
                ),
                const SizedBox(height: 14),

                // Focus banner or Filter Chips & Search
                if (isFocused) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.gps_fixed_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                focusedLocation != null
                                    ? _resolvePartnerTrackingVehicleName(focusedLocation)
                                    : 'Focused Vehicle',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() => _focusedTrackingBookingId = null);
                              },
                              icon: const Icon(Icons.grid_view_rounded, size: 14),
                              label: const Text('Show All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                                foregroundColor: isDark ? Colors.white : Colors.black87,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                            ),
                          ],
                        ),
                        if (focusedHasActiveBooking) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.borderColor),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.alt_route_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  '🟢 Pickup  ➔  🚕 Live Car  ➔  🚩 Destination',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                                ),
                              ),
                              if (remainingDistanceKm != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: remainingDistanceKm <= 5.0
                                        ? Colors.green.withValues(alpha: 0.25)
                                        : Colors.amber.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: remainingDistanceKm <= 5.0 ? Colors.green : Colors.amber,
                                    ),
                                  ),
                                  child: Text(
                                    '${remainingDistanceKm.toStringAsFixed(1)} km away',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: remainingDistanceKm <= 5.0 ? Colors.green : Colors.amber,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTrackingFilterChip('all', 'All ($totalCount)', isDark),
                        const SizedBox(width: 8),
                        _buildTrackingFilterChip('active', 'Active Trips ($activeCount)', isDark),
                        const SizedBox(width: 8),
                        _buildTrackingFilterChip('idle', 'Available / Idle ($idleCount)', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.borderColor : Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _partnerTrackingSearchController,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search your vehicles, plate, or trip...',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _partnerTrackingSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _partnerTrackingSearchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Live Map Viewport
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 280,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBgSecondary : Colors.grey.shade100,
                      border: Border.all(
                        color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: mapMarkers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_off_rounded, size: 36, color: AppColors.textSecondary),
                                const SizedBox(height: 8),
                                Text(
                                  _focusedTrackingBookingId == null
                                      ? 'No live GPS coordinates received yet'
                                      : 'No coordinates found for this vehicle',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : MobilisLeafletMap(
                            key: ValueKey(
                              'partner_fleet_${_focusedTrackingBookingId ?? "all"}_' +
                                  mapMarkers
                                      .map(
                                        (m) =>
                                            '${m.latitude.toStringAsFixed(4)},${m.longitude.toStringAsFixed(4)}',
                                      )
                                      .join('|') +
                                  '_${routePoints.length}',
                            ),
                            markers: mapMarkers,
                            routePoints: routePoints,
                            routeColor: AppColors.primary,
                            initialZoom: isFocused
                                ? (mapMarkers.length > 1 ? 12 : 15)
                                : (mapMarkers.length > 1 ? 11 : 14),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Vehicle List Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFocused ? 'Focused Vehicle Details' : 'Tracked Vehicles (${visibleLocations.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (isFocused)
                      GestureDetector(
                        onTap: () => setState(() => _focusedTrackingBookingId = null),
                        child: const Text(
                          'Show All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Vehicle Cards
                if (visibleLocations.isEmpty)
                  RoleEmptyStateCard(
                    icon: Icons.directions_car_filled_outlined,
                    title: 'No vehicles found',
                    message: _partnerTrackingFilter == 'active'
                        ? 'None of your vehicles are currently on an active trip.'
                        : 'No partner vehicles matched your search.',
                  )
                else
                  ...visibleLocations.map(
                    (location) => _buildPartnerTrackingCard(location, isDark),
                  ),
              ],
            ),
    );

    if (isStandalonePage) {
      return trackingContent;
    }
    return Column(
      children: [
        _buildCenteredTabHeader('Live Tracking'),
        Expanded(child: trackingContent),
      ],
    );
  }

  Widget _buildTrackingFilterChip(String filterKey, String label, bool isDark) {
    final isSelected = _partnerTrackingFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _partnerTrackingFilter = filterKey;
          _focusedTrackingBookingId = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.borderColor : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerTrackingCard(Map<String, dynamic> location, bool isDark) {
    final booking = location['bookings'] as Map<String, dynamic>?;
    final bStatus = (booking?['status'] ?? '').toString().toLowerCase();
    final hasActiveBooking = location['has_active_booking'] == true &&
        booking != null &&
        {'ongoing', 'active', 'in_progress', 'picked_up'}.contains(bStatus) &&
        booking['returned_at'] == null &&
        booking['completed_at'] == null;
    final vehicle = (booking?['vehicles'] ?? location['vehicle']) as Map<String, dynamic>?;
    final tracker = location['tracker'] as Map<String, dynamic>?;
    final driver = (booking?['driver'] ?? booking?['drivers']) as Map<String, dynamic>?;
    final driverUser = (location['tracked_user'] ?? driver?['users']) as Map<String, dynamic>?;
    final renter = booking?['renter'] as Map<String, dynamic>?;
    final rowId = booking?['id']?.toString() ??
        location['id']?.toString() ??
        'vehicle_${location['vehicle_id']}';
    final pickup = booking?['pickup_location']?.toString().trim() ?? '';
    final dropoff = booking?['dropoff_location']?.toString().trim() ?? '';
    final vehicleName = _resolvePartnerTrackingVehicleName(location);
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    final speedKph = (((location['speed_mps'] as num?) ?? 0) * 3.6).round();

    final isFocused = _focusedTrackingBookingId == rowId;

    // Distance to destination if on active trip
    double? distanceToDestinationKm;
    if (hasActiveBooking) {
      final destPoint = _resolvePartnerTrackingPoint(
        booking?['dropoff_latitude'],
        booking?['dropoff_longitude'],
        dropoff,
      );
      if (lat != null && lng != null && destPoint != null) {
        distanceToDestinationKm = Geolocator.distanceBetween(
              lat,
              lng,
              destPoint.latitude,
              destPoint.longitude,
            ) /
            1000;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isFocused
            ? AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08)
            : (isDark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused
              ? AppColors.primary
              : (isDark ? AppColors.borderColor : Colors.grey.shade300),
          width: isFocused ? 2 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _focusedTrackingBookingId = isFocused ? null : rowId;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header: Icon + Title + Status Chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? AppColors.primary
                            : (hasActiveBooking
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : const Color(0xFF38BDF8).withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        color: isFocused
                            ? Colors.black
                            : (hasActiveBooking ? AppColors.primary : const Color(0xFF38BDF8)),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicleName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasActiveBooking
                                ? 'On Active Rental Trip'
                                : (location['is_applied_pending'] == true
                                    ? 'Application Pending Approval • Standby'
                                    : 'Available • Parked / Idle'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPartnerMovementStatusChip(
                      location: location,
                      isDark: isDark,
                      isCompact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Speed & Tracker Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBgSecondary : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        size: 14,
                        color: speedKph > 0 ? const Color(0xFF00E676) : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Speed: $speedKph km/h',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      if (tracker?['battery_level'] != null) ...[
                        const Spacer(),
                        const Icon(Icons.battery_charging_full_rounded, size: 14, color: Colors.green),
                        const SizedBox(width: 3),
                        Text(
                          '${tracker!['battery_level']}%',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                      if (location['recorded_at'] != null) ...[
                        const Spacer(),
                        Text(
                          'Pinged ',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        RelativeTimeText(
                          value: location['recorded_at'],
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trip Information (Active)
                if (hasActiveBooking) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (renter != null)
                          Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Renter: ${renter['full_name'] ?? 'Guest Renter'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (driverUser != null) ...[
                                const SizedBox(width: 8),
                                const Text('•', style: TextStyle(color: Colors.grey)),
                                const SizedBox(width: 8),
                                Text(
                                  'Driver: ${driverUser['full_name']}',
                                  style: const TextStyle(fontSize: 11, color: Colors.cyan, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        if (pickup.isNotEmpty || dropoff.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: Colors.redAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Route: ${pickup.isEmpty ? "Current Location" : pickup} ➔ ${dropoff.isEmpty ? "Unspecified Destination" : dropoff}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (distanceToDestinationKm != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.straighten_rounded, size: 13, color: Colors.amber),
                              const SizedBox(width: 6),
                              Text(
                                '${distanceToDestinationKm.toStringAsFixed(1)} km to declared destination',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Action Buttons Row
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _focusedTrackingBookingId = isFocused ? null : rowId;
                          });
                        },
                        icon: Icon(isFocused ? Icons.check_circle_rounded : Icons.gps_fixed_rounded, size: 14),
                        label: Text(isFocused ? 'Focused ✓' : 'Focus Map', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFocused ? AppColors.primary : (isDark ? Colors.grey[800] : Colors.grey[200]),
                          foregroundColor: isFocused ? Colors.black : (isDark ? Colors.white : Colors.black87),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    if (hasActiveBooking) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openBookingConversation(booking),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                          label: const Text('Message', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          TripLocationMapDialog.show(
                            context: context,
                            booking: booking,
                            vehicleName: vehicleName,
                            plateNumber: (vehicle?['plate_number'] ?? tracker?['device_identifier'])?.toString(),
                          );
                        },
                        icon: const Icon(Icons.map_outlined, size: 18),
                        tooltip: 'Trip Route Map',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? AppColors.darkBgSecondary : Colors.grey.shade100,
                          padding: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

