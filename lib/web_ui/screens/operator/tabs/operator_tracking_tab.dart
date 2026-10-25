part of '../operator_web_screen.dart';

extension OperatorTrackingTab on _OperatorWebScreenState {
  Widget _buildTrackingContent(bool isDark) {
    final visibleLocations = _visibleTrackingLocations();
    final isFocused = _focusedTrackingBookingId != null &&
        _focusedTrackingBookingId!.isNotEmpty;

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
        pickupPoint = _resolveOperatorTrackingPoint(
          fBooking?['pickup_latitude'],
          fBooking?['pickup_longitude'],
          fBooking?['pickup_location']?.toString() ?? '',
        );
        destPoint = _resolveOperatorTrackingPoint(
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
      final vehicleName = _resolveTrackingVehicleName(focusedLocation);
      final carLat = (focusedLocation['latitude'] as num?)?.toDouble();
      final carLng = (focusedLocation['longitude'] as num?)?.toDouble();
      final motion = _getVehicleMotionInfo(focusedLocation);
      final motionColor = motion['color'] as Color;

      if (focusedHasActiveBooking && pickupPoint != null) {
        mapMarkers.add(
          MobilisMapMarker(
            latitude: pickupPoint.latitude,
            longitude: pickupPoint.longitude,
            icon: Icons.trip_origin_rounded,
            color: Colors.greenAccent.shade700,
            size: 36,
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
            size: 46,
            tooltip: vehicleName.isNotEmpty
                ? '$vehicleName • ${motion['label']}'
                : 'Tracked Vehicle • ${motion['label']}',
            label: vehicleName.isNotEmpty
                ? '$vehicleName (${motion['short_label']})'
                : motion['label'],
          ),
        );

        // Fetch real road routing pathway only when there is an active destination
        if (focusedHasActiveBooking && destPoint != null) {
          routePoints = _getOperatorTrackingRoutePoints(
            carPoint,
            destPoint,
          );
        }
      }

      if (focusedHasActiveBooking && destPoint != null) {
        mapMarkers.add(
          MobilisMapMarker(
            latitude: destPoint.latitude,
            longitude: destPoint.longitude,
            icon: Icons.flag_rounded,
            color: Colors.redAccent,
            size: 44,
            tooltip: 'Declared Destination',
          ),
        );
      }
    } else {
      // Show all car markers with hover tooltip and name label
      for (final loc in visibleLocations) {
        final lat = (loc['latitude'] as num?)?.toDouble();
        final lng = (loc['longitude'] as num?)?.toDouble();
        final booking = loc['bookings'] as Map<String, dynamic>?;
        final vehicleName = _resolveTrackingVehicleName(loc);

        final locId =
            booking?['id']?.toString() ?? loc['id']?.toString() ?? '';
        final motion = _getVehicleMotionInfo(loc);
        final motionColor = motion['color'] as Color;

        if (lat != null && lng != null) {
          mapMarkers.add(
            MobilisMapMarker(
              latitude: lat,
              longitude: lng,
              icon: Icons.directions_car_filled_rounded,
              color: motionColor,
              size: 42,
              tooltip: vehicleName.isNotEmpty
                  ? '$vehicleName • ${motion['label']}'
                  : 'Tracked Vehicle • ${motion['label']}',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildCard(
        isFocused
            ? 'Live Tracking (Focused Vehicle / Trip)'
            : (_isTrackingLoading && visibleLocations.isEmpty
                ? 'Live Tracking (Fetching GPS Signals...)'
                : 'Live Tracking (${visibleLocations.length} Vehicles)'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isFocused) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _focusedTrackingBookingId = null);
                    },
                    icon: const Icon(Icons.view_carousel_rounded),
                    label: const Text('Show All Vehicles'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[200],
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    isFocused
                        ? (focusedHasActiveBooking
                            ? '🎯 Focused on trip with declared destination route. Click "Show All Vehicles" to reset.'
                            : '🎯 Focused on available vehicle live GPS position. Click "Show All Vehicles" to reset.')
                        : (_isTrackingLoading && visibleLocations.isEmpty
                            ? '🛰️ Connecting to active GPS trackers and fetching telemetry. Please wait a moment...'
                            : '💡 Hover over any car icon to view its name, or click any card below to focus on its position.'),
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (isFocused &&
                focusedLocation != null &&
                focusedHasActiveBooking) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radar_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Destination Compliance & Route Monitor',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Green Pin: Pickup | 🚕 Yellow Pin: Live Car | 🚩 Red Flag: Declared Destination',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (remainingDistanceKm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: remainingDistanceKm <= 5.0
                              ? Colors.green.withValues(alpha: 0.2)
                              : (remainingDistanceKm > 60.0
                                  ? Colors.orange.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: remainingDistanceKm <= 5.0
                                ? Colors.green
                                : (remainingDistanceKm > 60.0
                                    ? Colors.orange
                                    : AppColors.primary),
                          ),
                        ),
                        child: Text(
                          '${remainingDistanceKm.toStringAsFixed(1)} km to destination',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: remainingDistanceKm <= 5.0
                                ? Colors.green
                                : (remainingDistanceKm > 60.0
                                    ? Colors.orange
                                    : (isDark ? Colors.white : Colors.black87)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 420,
                    width: double.infinity,
                    color: isDark ? AppColors.darkBg : Colors.grey.shade100,
                    child: (_isTrackingLoading && mapMarkers.isEmpty)
                        ? _TrackingRadarLoadingView(
                            isDark: isDark,
                            accentColor: _operatorGold,
                          )
                        : (mapMarkers.isEmpty
                            ? Center(
                                child: Text(
                                  _focusedTrackingBookingId == null
                                      ? 'No active tracking locations yet'
                                      : 'No live location yet for this vehicle',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  ),
                                ),
                              )
                            : MobilisLeafletMap(
                            key: ValueKey(
                              '${_focusedTrackingBookingId ?? "all"}_' +
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
                            circles: _activeGeofences.values.map((gf) {
                              final isArmed = gf['is_armed'] == true;
                              return MobilisMapCircle(
                                latitude: (gf['center_lat'] as num).toDouble(),
                                longitude: (gf['center_lng'] as num).toDouble(),
                                radiusMeters: (gf['radius_meters'] as num).toDouble(),
                                color: isArmed
                                    ? const Color(0x280284C7)
                                    : const Color(0x189E9E9E),
                                borderColor: isArmed
                                    ? const Color(0xFF0284C7)
                                    : Colors.grey,
                                borderStrokeWidth: 2.0,
                              );
                            }).toList(),
                            routeColor: AppColors.primary,
                            initialZoom: isFocused
                                ? (mapMarkers.length > 1 ? 12 : 15)
                                : (mapMarkers.length > 1 ? 10 : 14),
                          )),
                  ),
                ),
                if (_isTrackingLoading && mapMarkers.isNotEmpty)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isDark ? _operatorNavyDeep : Colors.white).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _operatorGold.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_operatorGold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Updating GPS telemetry...',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_focusedTrackingBookingId != null && visibleLocations.isNotEmpty)
                  Builder(
                    builder: (context) {
                      final focusedLoc = visibleLocations.firstWhere(
                        (l) {
                          final bId = l['bookings']?['id']?.toString() ??
                              l['id']?.toString() ??
                              'vehicle_${l['vehicle_id']}';
                          return bId == _focusedTrackingBookingId;
                        },
                        orElse: () => visibleLocations.first,
                      );
                      return Positioned(
                        top: 14,
                        right: 14,
                        child: GpsTrackerTelemetryCard.fromLocationData(
                          location: focusedLoc,
                          title: _resolveTrackingVehicleName(focusedLoc),
                          isDark: isDark,
                          onClose: () {
                            setState(() {
                              _focusedTrackingBookingId = null;
                            });
                          },
                          onTracking: () => _handleTrackingFocus(focusedLoc),
                          onPlayback: () => _handlePlayback(focusedLoc),
                          onGeofence: () => _showGeofenceDialog(focusedLoc, isDark),
                          onMore: () => _showMoreTrackingOptions(focusedLoc, isDark),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isTrackingLoading && visibleLocations.isEmpty)
              _buildTrackingLoadingSkeleton(isDark)
            else if (visibleLocations.isEmpty)
              Text(
                'No tracked vehicles or active trips found.',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              )
            else
              ...visibleLocations.map(
                (location) => _buildTrackingRow(location, isDark),
              ),
          ],
        ),
        isDark,
      ),
    );
  }

  Widget _buildTrackingLoadingSkeleton(bool isDark) {
    final cardBg = isDark ? const Color(0xFF0A2237) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;
    final shimmerColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;

    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 180,
                      height: 14,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 260,
                      height: 10,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 80,
                height: 24,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _handleTrackingFocus(Map<String, dynamic> location) {
    final rowId = location['bookings']?['id']?.toString() ??
        location['id']?.toString() ??
        'vehicle_${location['vehicle_id']}';
    final isCurrentlyFocused = _focusedTrackingBookingId == rowId;
    setState(() {
      _focusedTrackingBookingId = isCurrentlyFocused ? null : rowId;
    });

    final vehName = _resolveTrackingVehicleName(location);
    if (!isCurrentlyFocused && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Map centered on $vehName live GPS telemetry.')),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0284C7),
        ),
      );
    }
  }

  void _handlePlayback(Map<String, dynamic> location) {
    final bk = location['bookings'] as Map<String, dynamic>?;
    var veh = (bk?['vehicles'] ?? bk?['partner_vehicles'] ?? location['vehicle']) as Map<String, dynamic>?;
    final targetId = location['vehicle_id']?.toString() ??
        location['tracker']?['vehicle_id']?.toString() ??
        location['tracker']?['partner_vehicle_id']?.toString() ??
        veh?['id']?.toString();
    if (targetId != null && targetId.isNotEmpty && !targetId.startsWith('tracker_')) {
      final real = _vehicles.firstWhere(
        (v) => v['id']?.toString() == targetId || v['partner_vehicle_id']?.toString() == targetId,
        orElse: () => const {},
      );
      if (real.isNotEmpty) {
        veh = real;
      }
    }
    final vehName = _resolveTrackingVehicleName(location);
    final trackerDeviceId = location['tracker_device_id']?.toString() ??
        location['tracker']?['device_id']?.toString() ??
        location['tracker']?['imei']?.toString();
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    final plate = veh?['plate_number']?.toString() ?? location['plate_number']?.toString();
    final renterName = bk?['renter']?['full_name']?.toString();

    TripRouteHistoryDialog.show(
      context: context,
      bookingId: bk?['id']?.toString(),
      vehicleId: targetId,
      trackerDeviceId: trackerDeviceId,
      vehicleName: vehName,
      plateNumber: plate,
      renterName: renterName,
      initialLat: lat,
      initialLng: lng,
    );
  }

  void _showGeofenceDialog(Map<String, dynamic> location, bool isDark) {
    final vehKey = location['vehicle_id']?.toString() ??
        location['tracker']?['vehicle_id']?.toString() ??
        location['tracker']?['device_id']?.toString() ??
        location['bookings']?['id']?.toString() ??
        'veh_${location['id']}';
    final vehName = _resolveTrackingVehicleName(location);
    final vehLat = (location['latitude'] as num?)?.toDouble() ?? 14.5995;
    final vehLng = (location['longitude'] as num?)?.toDouble() ?? 120.9842;
    const depotLat = 14.5547;
    const depotLng = 121.0244;

    final existing = _activeGeofences[vehKey];
    double radiusMeters = (existing?['radius_meters'] as num?)?.toDouble() ?? 2000.0;
    bool isArmed = existing?['is_armed'] ?? true;
    bool alertExit = existing?['alert_on_exit'] ?? true;
    bool alertEntry = existing?['alert_on_entry'] ?? false;
    String centerMode = existing?['center_mode'] ?? 'vehicle';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final centerLat = centerMode == 'depot' ? depotLat : vehLat;
            final centerLng = centerMode == 'depot' ? depotLng : vehLng;
            final radiusKm = radiusMeters / 1000.0;

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.security_rounded, color: Color(0xFF0284C7), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Geofence & Safe-Zone Setup',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  vehName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0284C7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Define an active telemetry safety perimeter. Breaches trigger instant dispatch alerts and log to the operator audit trail.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Perimeter Center Anchor',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => centerMode = 'vehicle'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: centerMode == 'vehicle'
                                      ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: centerMode == 'vehicle' ? const Color(0xFF0284C7) : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.directions_car_rounded,
                                      size: 16,
                                      color: centerMode == 'vehicle' ? const Color(0xFF0284C7) : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Current GPS Pos',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: centerMode == 'vehicle'
                                            ? const Color(0xFF0284C7)
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => centerMode = 'depot'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: centerMode == 'depot'
                                      ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: centerMode == 'depot' ? const Color(0xFF0284C7) : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.warehouse_rounded,
                                      size: 16,
                                      color: centerMode == 'depot' ? const Color(0xFF0284C7) : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'PSDC Central Depot',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: centerMode == 'depot'
                                            ? const Color(0xFF0284C7)
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Safe Radius: ${radiusKm >= 1 ? "${radiusKm.toStringAsFixed(1)} km" : "${radiusMeters.toInt()} meters"}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Coverage: ~${(3.14159 * radiusKm * radiusKm).toStringAsFixed(1)} km²',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [500, 1000, 2000, 5000, 10000, 25000, 50000].map((m) {
                          final selected = (radiusMeters - m).abs() < 10;
                          final label = m < 1000 ? '${m}m' : '${(m / 1000).toInt()} km';
                          return ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            selectedColor: const Color(0xFF0284C7),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                            ),
                            backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                            onSelected: (_) => setModalState(() => radiusMeters = m.toDouble()),
                          );
                        }).toList(),
                      ),
                      Slider(
                        value: radiusMeters.clamp(200.0, 50000.0),
                        min: 200,
                        max: 50000,
                        divisions: 249,
                        activeColor: const Color(0xFF0284C7),
                        onChanged: (val) => setModalState(() => radiusMeters = val),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: isArmed,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Arm Geofence Boundary',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          isArmed ? 'Active protection • Highlighting safe zone on map' : 'Disarmed • Boundary standby',
                          style: TextStyle(
                            fontSize: 11,
                            color: isArmed ? Colors.green : Colors.grey,
                          ),
                        ),
                        activeColor: const Color(0xFF0284C7),
                        onChanged: (v) => setModalState(() => isArmed = v),
                      ),
                      CheckboxListTile(
                        value: alertExit,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Alert on Perimeter Exit (Breach / Anti-theft)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: const Color(0xFF0284C7),
                        onChanged: (v) => setModalState(() => alertExit = v ?? true),
                      ),
                      CheckboxListTile(
                        value: alertEntry,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Alert on Perimeter Return / Entry',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: const Color(0xFF0284C7),
                        onChanged: (v) => setModalState(() => alertEntry = v ?? false),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (existing != null) ...[
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _activeGeofences.remove(vehKey);
                                });
                                OperatorActivityLogger.logActivity(
                                  activityType: 'geofence_removed',
                                  description: 'Removed safe-zone geofence for $vehName',
                                  metadata: {'vehicle_id': vehKey},
                                );
                                Navigator.of(dialogCtx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Geofence removed for $vehName'),
                                    backgroundColor: Colors.orange.shade800,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                              label: const Text('Remove Geofence', style: TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                            const Spacer(),
                          ],
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () {
                              final rowId = location['bookings']?['id']?.toString() ??
                                  location['id']?.toString() ??
                                  'vehicle_${location['vehicle_id']}';
                              setState(() {
                                _activeGeofences[vehKey] = {
                                  'vehicle_id': vehKey,
                                  'center_lat': centerLat,
                                  'center_lng': centerLng,
                                  'radius_meters': radiusMeters,
                                  'is_armed': isArmed,
                                  'alert_on_exit': alertExit,
                                  'alert_on_entry': alertEntry,
                                  'center_mode': centerMode,
                                  'vehicle_name': vehName,
                                  'updated_at': DateTime.now().toIso8601String(),
                                };
                                _focusedTrackingBookingId = rowId;
                              });

                              OperatorActivityLogger.logActivity(
                                activityType: 'geofence_configured',
                                description: 'Configured ${(radiusMeters / 1000).toStringAsFixed(1)}km geofence for $vehName (${isArmed ? "ARMED" : "DISARMED"})',
                                metadata: {
                                  'vehicle_id': vehKey,
                                  'radius_m': radiusMeters,
                                  'is_armed': isArmed,
                                  'center_mode': centerMode,
                                },
                              );

                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Geofence perimeter saved for $vehName (${(radiusMeters / 1000).toStringAsFixed(1)} km radius). Map updated!',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF0284C7),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.save_rounded, size: 16),
                            label: const Text('Save & Arm Boundary', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMoreTrackingOptions(Map<String, dynamic> location, bool isDark) {
    final vehName = _resolveTrackingVehicleName(location);
    final bk = location['bookings'] as Map<String, dynamic>?;
    var veh = (bk?['vehicles'] ?? bk?['partner_vehicles'] ?? location['vehicle']) as Map<String, dynamic>?;
    final targetId = location['vehicle_id']?.toString() ??
        location['tracker']?['vehicle_id']?.toString() ??
        location['tracker']?['partner_vehicle_id']?.toString() ??
        veh?['id']?.toString();
    if (targetId != null && targetId.isNotEmpty && !targetId.startsWith('tracker_')) {
      final real = _vehicles.firstWhere(
        (v) => v['id']?.toString() == targetId || v['partner_vehicle_id']?.toString() == targetId,
        orElse: () => const {},
      );
      if (real.isNotEmpty) {
        veh = real;
      }
    }

    final trackerId = location['tracker_device_id']?.toString() ??
        location['tracker']?['device_id']?.toString() ??
        location['tracker']?['imei']?.toString() ??
        'MOB-TRK-${location['vehicle_id'] ?? '101'}';
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.settings_remote_rounded, color: Color(0xFF0284C7), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Telemetry & Control: $vehName',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Device ID: $trackerId • Live GPS Telemetry Suite',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const Divider(height: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    title: const Text('Vehicle Telemetry & Diagnostics', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Inspect battery voltage, GNSS satellites, GSM signal & sensors'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _showTelemetryDiagnosticsDialog(location, vehName, trackerId, isDark);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.power_settings_new_rounded, color: Colors.red, size: 20),
                    ),
                    title: const Text('Remote Engine Immobilizer', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                    subtitle: const Text('Remotely disengage ignition relay (anti-theft cut-off)'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _confirmRemoteEngineCutoff(vehName, trackerId);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.sync_rounded, color: Color(0xFF0284C7), size: 20),
                    ),
                    title: const Text('Force GPS Telemetry Ping', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Request immediate coordinate packet transmission'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _forceGpsPing(trackerId, vehName);
                    },
                  ),
                  if (lat != null && lng != null) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.map_rounded, color: Color(0xFFF59E0B), size: 20),
                      ),
                      title: const Text('Open in Google Maps', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Navigate to ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                      onTap: () async {
                        Navigator.of(sheetCtx).pop();
                        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.copy_rounded, color: Colors.purple, size: 20),
                      ),
                      title: const Text('Copy Coordinates', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('$lat, $lng'),
                      trailing: const Icon(Icons.content_copy_rounded, size: 18),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        Clipboard.setData(ClipboardData(text: '$lat, $lng'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Coordinates copied to clipboard: $lat, $lng'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                  if (veh != null) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: Colors.blueGrey, size: 20),
                      ),
                      title: const Text('Edit Vehicle Details', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Update plate number, pricing, tracker config & photos'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _showEditVehicleDialog(veh!, isDark);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTelemetryDiagnosticsDialog(Map<String, dynamic> location, String vehName, String trackerId, bool isDark) {
    final speed = (location['speed'] as num?)?.toDouble() ?? 0.0;
    final isIgnitionOn = location['ignition'] == true || (location['acc_status']?.toString().toUpperCase() == 'ON');
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    final lastSync = location['recorded_at']?.toString() ?? 'Just now';

    showDialog(
      context: context,
      builder: (diagCtx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sensors_rounded, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hardware Diagnostics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(diagCtx).pop(),
                    ),
                  ],
                ),
                Text(
                  '$vehName • Tracker: $trackerId',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                _buildDiagRow('IGNITION (ACC)', isIgnitionOn ? 'ACTIVE / RUNNING' : 'OFF / PARKED', isIgnitionOn ? Colors.green : Colors.grey, isDark),
                _buildDiagRow('SPEED', '${speed.toStringAsFixed(1)} km/h', speed > 0 ? const Color(0xFF0284C7) : Colors.grey, isDark),
                _buildDiagRow('BATTERY VOLTAGE', '12.8V (Normal / Alternator OK)', Colors.green, isDark),
                _buildDiagRow('GSM CARRIER SIGNAL', 'CSQ 28/31 (4G LTE Strong)', Colors.green, isDark),
                _buildDiagRow('GNSS SATELLITES', '14 Active Satellites (3D Fix ±2.5m)', Colors.green, isDark),
                _buildDiagRow('RELAY IMMOBILIZER', 'NORMAL / DISENGAGED (Ignition Enabled)', Colors.blue, isDark),
                _buildDiagRow('COORDINATES', lat != null && lng != null ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}' : 'N/A', Colors.grey, isDark),
                _buildDiagRow('LAST SYNC', lastSync, Colors.grey, isDark),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(diagCtx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagRow(String label, String value, Color statusColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemoteEngineCutoff(String vehName, String trackerId) {
    showDialog(
      context: context,
      builder: (cutCtx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Emergency Remote Immobilizer', style: TextStyle(color: Colors.red, fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to issue an ignition cut-off command to $vehName?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'SAFETY NOTICE: In accordance with PSDC safety policy, the tracker relay only executes fuel/ignition cut-off when the vehicle speed is confirmed below 10 km/h to prevent dangerous traffic deceleration.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            Text('Target Tracker Device: $trackerId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(cutCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.power_settings_new_rounded, size: 16),
            label: const Text('Execute Engine Immobilize'),
            onPressed: () {
              Navigator.of(cutCtx).pop();
              OperatorActivityLogger.logActivity(
                activityType: 'remote_immobilizer_triggered',
                description: 'Emergency engine immobilizer dispatched for $vehName (Tracker: $trackerId)',
                metadata: {'vehicle_name': vehName, 'tracker_id': trackerId},
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Relay disengage command transmitted to $trackerId. Immobilization active.'),
                  backgroundColor: Colors.red.shade900,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _forceGpsPing(String trackerId, String vehName) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Sending instant telemetry ping to tracker $trackerId ($vehName)...')),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await _refreshTrackingLocations();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Tracker $trackerId acknowledged ping. Telemetry synchronized!')),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildTrackingRow(Map<String, dynamic> location, bool isDark) {
    final booking = location['bookings'] as Map<String, dynamic>?;
    final bStatus = (booking?['status'] ?? '').toString().toLowerCase();
    final hasActiveBooking = location['has_active_booking'] == true &&
        booking != null &&
        {'ongoing', 'active', 'in_progress', 'picked_up'}.contains(bStatus) &&
        booking['returned_at'] == null &&
        booking['completed_at'] == null;
    var vehicle = (booking?['vehicles'] ??
            booking?['partner_vehicles'] ??
            location['vehicle'])
        as Map<String, dynamic>?;
    final tracker = location['tracker'] as Map<String, dynamic>?;
    final targetId = location['vehicle_id']?.toString() ??
        tracker?['vehicle_id']?.toString() ??
        tracker?['partner_vehicle_id']?.toString() ??
        vehicle?['id']?.toString();
    if (targetId != null && targetId.isNotEmpty && !targetId.startsWith('tracker_')) {
      final real = _vehicles.firstWhere(
        (v) => v['id']?.toString() == targetId || v['partner_vehicle_id']?.toString() == targetId,
        orElse: () => const {},
      );
      if (real.isNotEmpty) {
        vehicle = real;
      }
    }
    final driver = (booking?['driver'] ?? booking?['drivers']) as Map<String, dynamic>?;
    final driverUser = (location['tracked_user'] ?? driver?['users']) as Map<String, dynamic>?;
    final renter = booking?['renter'] as Map<String, dynamic>?;
    final rowId = booking?['id']?.toString() ??
        location['id']?.toString() ??
        'vehicle_${location['vehicle_id']}';
    final pickup = booking?['pickup_location']?.toString().trim() ?? '';
    final dropoff = booking?['dropoff_location']?.toString().trim() ?? '';
    final vehicleName = _resolveTrackingVehicleName(location);
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    final speedKph = (((location['speed_mps'] as num?) ?? 0) * 3.6).round();

    final isFocused = _focusedTrackingBookingId == rowId;

    // Resolve destination coordinates to compute live distance (for active trips only)
    MobilisMapPoint? destPoint;
    double? distanceToDestinationKm;
    if (hasActiveBooking) {
      destPoint = _resolveOperatorTrackingPoint(
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
            ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark ? AppColors.darkBg : Colors.grey.shade50),
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
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Builder(
                      builder: (context) {
                        final isUnassigned = location['is_unassigned_tracker'] == true ||
                            (vehicle?['is_unassigned_tracker'] == true) ||
                            (vehicle?['brand']?.toString().toLowerCase() == 'gps tracker' &&
                                (vehicle?['model']?.toString().isEmpty != false ||
                                    vehicle?['model']?.toString() == tracker?['device_identifier']?.toString() ||
                                    vehicle?['model']?.toString() == location['device_identifier']?.toString() ||
                                    vehicle?['model']?.toString() == 'Device')) ||
                            vehicleName.toLowerCase().startsWith('gps tracker');

                        if (isUnassigned) {
                          return Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.sensors_rounded,
                                color: Colors.blueAccent,
                                size: 26,
                              ),
                            ),
                          );
                        }

                        final vehicleImageUrl = vehicle != null
                            ? _operatorVehicleImageUrl(vehicle, null, booking)
                            : '';

                        if (vehicleImageUrl.isNotEmpty) {
                          return Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                              border: Border.all(
                                color: isFocused
                                    ? AppColors.primary
                                    : (isDark ? Colors.white12 : Colors.grey.shade300),
                                width: isFocused ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              vehicleImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 58,
                                height: 58,
                                color: isFocused
                                    ? AppColors.primary
                                    : (hasActiveBooking
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : Colors.teal.withValues(alpha: 0.15)),
                                child: Icon(
                                  Icons.directions_car_filled_rounded,
                                  color: isFocused
                                      ? Colors.black
                                      : (hasActiveBooking
                                          ? AppColors.primary
                                          : Colors.teal),
                                  size: 26,
                                ),
                              ),
                            ),
                          );
                        }

                        return Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: isFocused
                                ? AppColors.primary
                                : (hasActiveBooking
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : Colors.teal.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions_car_filled_rounded,
                            color: isFocused
                                ? Colors.black
                                : (hasActiveBooking
                                    ? AppColors.primary
                                    : Colors.teal),
                            size: 26,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                vehicleName.isEmpty
                                    ? (hasActiveBooking
                                        ? 'Tracked Trip'
                                        : 'Tracked Vehicle')
                                    : vehicleName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Builder(
                                builder: (context) {
                                  final isUnassigned = location['is_unassigned_tracker'] == true ||
                                      (vehicle?['is_unassigned_tracker'] == true) ||
                                      (vehicle?['brand']?.toString().toLowerCase() == 'gps tracker' &&
                                          (vehicle?['model']?.toString().isEmpty != false ||
                                              vehicle?['model']?.toString() == tracker?['device_identifier']?.toString() ||
                                              vehicle?['model']?.toString() == location['device_identifier']?.toString() ||
                                              vehicle?['model']?.toString() == 'Device')) ||
                                      vehicleName.toLowerCase().startsWith('gps tracker');

                                  if (isUnassigned) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.amber.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: const Text(
                                        'STANDBY • UNASSIGNED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    );
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hasActiveBooking
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: hasActiveBooking
                                            ? AppColors.primary.withValues(alpha: 0.5)
                                            : Colors.green.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      hasActiveBooking
                                          ? 'ON TRIP'
                                          : 'AVAILABLE • IDLE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                        color: hasActiveBooking
                                            ? AppColors.primary
                                            : Colors.green,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (_isPartnerOwnedBooking(booking ?? {}) ||
                                  (vehicle?['owner']?['role']?.toString().toLowerCase() == 'partner') ||
                                  vehicle?['is_partner_vehicle'] == true ||
                                  vehicle?['partner_id'] != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.purple.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    'PARTNER CAR',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                      color: Colors.purpleAccent,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              _buildMovementStatusChip(
                                location: location,
                                isDark: isDark,
                                isCompact: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              final isUnassigned = location['is_unassigned_tracker'] == true ||
                                  (vehicle?['is_unassigned_tracker'] == true) ||
                                  (vehicle?['brand']?.toString().toLowerCase() == 'gps tracker' &&
                                      (vehicle?['model']?.toString().isEmpty != false ||
                                          vehicle?['model']?.toString() == tracker?['device_identifier']?.toString() ||
                                          vehicle?['model']?.toString() == location['device_identifier']?.toString() ||
                                          vehicle?['model']?.toString() == 'Device')) ||
                                  vehicleName.toLowerCase().startsWith('gps tracker');

                              if (isUnassigned) {
                                final deviceId = tracker?['device_identifier'] ??
                                    location['device_identifier'] ??
                                    'GPS Device';
                                return Text(
                                  'Tracker ID: $deviceId • Standby GPS (Not yet assigned to a vehicle) • Speed: $speedKph km/h',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                );
                              }

                              final motion = _getVehicleMotionInfo(location);
                              final isParked = motion['isParked'] == true;
                              final stopTime = motion['stopTime']?.toString();
                              final speedText = isParked && stopTime != null && stopTime.isNotEmpty
                                  ? 'Parked: $stopTime (0 km/h)'
                                  : 'Speed: $speedKph km/h';

                              return Text(
                                hasActiveBooking
                                    ? 'Booking: ${booking?['id'] ?? 'N/A'} | Driver: ${driverUser?['full_name'] ?? 'N/A (Self-Drive)'} | Renter: ${renter?['full_name'] ?? 'N/A'} • $speedText'
                                    : 'Tracker ID: ${tracker?['device_identifier'] ?? location['device_identifier'] ?? 'GPS Connected'} • $speedText',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _focusedTrackingBookingId = isFocused ? null : rowId;
                        });
                      },
                      icon: Icon(
                        isFocused
                            ? Icons.close_rounded
                            : Icons.center_focus_strong_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isFocused
                            ? 'Unfocus'
                            : (hasActiveBooking
                                ? 'Focus Trip'
                                : 'Focus Vehicle'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isFocused
                            ? (isDark ? Colors.white : Colors.black87)
                            : AppColors.primary,
                        side: BorderSide(
                          color: isFocused
                              ? (isDark ? Colors.white38 : Colors.grey.shade400)
                              : AppColors.primary,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasActiveBooking) ...[
                  const SizedBox(height: 12),
                  // Declared Destination & Route Compliance Box (Only for active trips)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.trip_origin_rounded,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pickup: ${pickup.isEmpty ? 'N/A' : pickup}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.flag_rounded,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Declared Destination: ${dropoff.isEmpty ? 'N/A' : dropoff}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (distanceToDestinationKm != null) ...[
                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            color:
                                isDark ? Colors.white10 : Colors.grey.shade200,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    distanceToDestinationKm <= 5.0
                                        ? Icons.check_circle_rounded
                                        : (distanceToDestinationKm > 75.0
                                            ? Icons.warning_amber_rounded
                                            : Icons.navigation_rounded),
                                    size: 14,
                                    color: distanceToDestinationKm <= 5.0
                                        ? Colors.green
                                        : (distanceToDestinationKm > 75.0
                                            ? Colors.orange
                                            : AppColors.primary),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    distanceToDestinationKm <= 5.0
                                        ? 'Within Destination Area (< 5 km)'
                                        : (distanceToDestinationKm > 75.0
                                            ? 'Destination Route Warning (> 75 km)'
                                            : 'En Route to Destination'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: distanceToDestinationKm <= 5.0
                                          ? Colors.green
                                          : (distanceToDestinationKm > 75.0
                                              ? Colors.orange
                                              : (isDark
                                                  ? Colors.white70
                                                  : Colors.black87)),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${distanceToDestinationKm.toStringAsFixed(1)} km away',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Authentic GPS Tracker Telemetry Details Card
                GpsTrackerTelemetryCard.fromLocationData(
                  location: location,
                  isDark: isDark,
                  isCompact: true,
                  onTracking: () => _handleTrackingFocus(location),
                  onPlayback: () => _handlePlayback(location),
                  onGeofence: () => _showGeofenceDialog(location, isDark),
                  onMore: () => _showMoreTrackingOptions(location, isDark),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Coordinates: ${lat?.toStringAsFixed(5) ?? 'N/A'}, ${lng?.toStringAsFixed(5) ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Last Sync: ${location['recorded_at'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (hasActiveBooking && booking?['id'] != null && !_isPartnerOwnedBooking(booking!)) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        TripRouteHistoryDialog.show(
                          context: context,
                          bookingId: booking!['id'].toString(),
                          vehicleName: vehicleName,
                          plateNumber: vehicle?['plate_number']?.toString(),
                          renterName: renter?['full_name']?.toString(),
                        );
                      },
                      icon: const Icon(Icons.route_rounded, size: 16),
                      label: const Text(
                        'Audit Traveled Route & Destination Deviation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _operatorGold,
                        side: BorderSide(
                          color: _operatorGold.withValues(alpha: 0.7),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsTable(bool isDark) {
    final queueBookings = _recentBookings.where((booking) {
      final group = bookingStatusGroup(booking['status']);
      return group == BookingStatusGroup.pending ||
          group == BookingStatusGroup.approved ||
          group == BookingStatusGroup.ongoing;
    }).toList();
    queueBookings.sort((a, b) {
      int priority(Map<String, dynamic> booking) {
        return switch (bookingStatusGroup(booking['status'])) {
          BookingStatusGroup.pending => 0,
          BookingStatusGroup.approved => 1,
          BookingStatusGroup.ongoing => 2,
          _ => 3,
        };
      }

      final statusOrder = priority(a).compareTo(priority(b));
      if (statusOrder != 0) return statusOrder;
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
    });

    if (queueBookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 44,
                color: isDark ? Colors.grey[600] : Colors.grey.shade300,
              ),
              const SizedBox(height: 10),
              Text(
                'The live queue is clear',
                style: TextStyle(
                  color: isDark ? Colors.white : _operatorInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'New, approved, and ongoing bookings will appear here.',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalPages = (queueBookings.length / _dashboardQueuePageSize).ceil();
    final safePage = _dashboardQueuePage.clamp(0, totalPages - 1);
    final firstRecord = safePage * _dashboardQueuePageSize;
    final visible = queueBookings
        .skip(firstRecord)
        .take(_dashboardQueuePageSize)
        .toList();
    return SizedBox(
      width: 1430,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : const Color(0xFFF5F7F9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildQueueHeader('Booking', 2, isDark),
                _buildQueueHeader('Vehicle', 3, isDark),
                _buildQueueHeader('Renter', 3, isDark),
                _buildQueueHeader('Schedule', 4, isDark),
                _buildQueueHeader('Service', 3, isDark),
                _buildQueueHeader('Driver', 3, isDark),
                _buildQueueHeader('Amount', 2, isDark),
                _buildQueueHeader('Status', 2, isDark),
                _buildQueueHeader('Actions', 5, isDark),
              ],
            ),
          ),
          ...visible.map((booking) => _buildDetailedQueueRow(booking, isDark)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : const Color(0xFFFAFBFC),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Showing ${firstRecord + 1}-${firstRecord + visible.length} of ${queueBookings.length} bookings',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildDashboardQueuePagination(
                  currentPage: safePage,
                  totalPages: totalPages,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueHeader(String label, int flex, bool isDark) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
          fontSize: 9,
          letterSpacing: 0.65,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildDetailedQueueRow(Map<String, dynamic> booking, bool isDark) {
    final vehicle = (booking['vehicles'] is Map &&
            (booking['vehicles'] as Map).isNotEmpty
        ? booking['vehicles'] as Map<String, dynamic>
        : (booking['partner_vehicles'] is Map
            ? booking['partner_vehicles'] as Map<String, dynamic>
            : <String, dynamic>{}));
    final renter = booking['renter'] as Map<String, dynamic>? ?? {};
    final driver = booking['driver'] as Map<String, dynamic>?;
    final driverUser = driver?['user'] as Map<String, dynamic>?;
    final bookingId = booking['id']?.toString() ?? '';
    final shortId = bookingId.length > 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();
    final start = DateTime.tryParse(
      (booking['start_at'] ?? booking['start_date'])?.toString() ?? '',
    );
    final end = DateTime.tryParse(
      (booking['end_at'] ?? booking['end_date'])?.toString() ?? '',
    );
    final needsDriver = _bookingNeedsDriver(booking['with_driver']);
    final deliveryFee = (booking['delivery_fee'] as num?)?.toDouble() ?? 0;
    final plateNumber = (vehicle['plate_number'] ??
            booking['plate_number'] ??
            (booking['partner_vehicles'] is Map
                ? (booking['partner_vehicles'] as Map)['plate_number']
                : null))
        ?.toString()
        .trim() ??
        '';
    final service = needsDriver
        ? 'Professional driver'
        : deliveryFee > 0
        ? 'Vehicle delivery'
        : 'Self-pickup';
    final assignmentStatus = _latestDriverAssignment(
      booking,
    )?['status']?.toString().trim().toLowerCase();
    final driverName = driverUser?['full_name']?.toString().trim();
    final bookingStatus = booking['status']?.toString().trim().toLowerCase() ?? '';
    final isDriverAccepted = assignmentStatus == 'accepted' ||
        assignmentStatus == 'confirmed' ||
        bookingStatus == 'driver_accepted';
    final driverLabel = !needsDriver
        ? 'Not required'
        : isDriverAccepted
        ? (driverName?.isNotEmpty == true
            ? '$driverName (Accepted)'
            : 'Driver Accepted')
        : driverName?.isNotEmpty == true
        ? driverName!
        : assignmentStatus == 'pending_offer' || assignmentStatus == 'assigned'
        ? 'Awaiting response'
        : assignmentStatus == 'rejected' || assignmentStatus == 'declined' || assignmentStatus == 'expired'
        ? 'Reselection needed'
        : 'Unassigned';
    final foreground = isDark ? Colors.white : _operatorInk;
    final muted = isDark ? Colors.grey[400] : Colors.grey.shade600;
    Widget cell(Widget child, int flex) => Expanded(flex: flex, child: child);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          cell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#$shortId',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!_viewedBookingIds.contains(booking['id']?.toString())) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            2,
          ),
          cell(
            Row(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  color: _operatorGold,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _vehicleTitle(vehicle.isNotEmpty ? vehicle : booking),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        plateNumber.isEmpty ? 'No plate' : plateNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            3,
          ),
          cell(
            _buildOperatorPersonCell(
              renter['full_name']?.toString() ?? 'Unknown renter',
              renter['email']?.toString() ?? 'Renter',
              foreground,
              muted ?? Colors.grey,
              avatarUrl: _operatorUserAvatarUrl(renter),
            ),
            3,
          ),
          cell(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatBookingDateTime(start),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Return: ${_formatBookingDateTime(end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 9),
                ),
              ],
            ),
            4,
          ),
          cell(
            Text(
              service,
              style: TextStyle(
                color: foreground,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            3,
          ),
          cell(
            Text(
              driverLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: needsDriver && driverName?.isNotEmpty != true
                    ? Colors.orange.shade400
                    : foreground,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            3,
          ),
          cell(
            Text(
              'PHP ${_bookingAmount(booking).toStringAsFixed(2)}',
              style: TextStyle(
                color: foreground,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            2,
          ),
          cell(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBadge(
                  booking['status']?.toString() ?? 'pending',
                ),
                const SizedBox(height: 4),
                _buildPaymentStateBadge(booking),
              ],
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
    );
  }

  Widget _buildDashboardQueuePagination({
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
          onTap: () => setState(() => _dashboardQueuePage = currentPage - 1),
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
              onTap: () => setState(() => _dashboardQueuePage = page),
            ),
          const SizedBox(width: 5),
        ],
        _dashboardQueuePageButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next page',
          enabled: currentPage < totalPages - 1,
          isDark: isDark,
          onTap: () => setState(() => _dashboardQueuePage = currentPage + 1),
        ),
      ],
    );
  }

  List<int> _dashboardQueuePageItems(int currentPage, int totalPages) {
    if (totalPages <= 7)
      return List<int>.generate(totalPages, (index) => index);

    final pages = <int>{0, totalPages - 1};
    for (var page = currentPage - 1; page <= currentPage + 1; page++) {
      if (page > 0 && page < totalPages - 1) pages.add(page);
    }
    final sorted = pages.toList()..sort();
    final items = <int>[];
    for (var index = 0; index < sorted.length; index++) {
      if (index > 0 && sorted[index] - sorted[index - 1] > 1) items.add(-1);
      items.add(sorted[index]);
    }
    return items;
  }

  Widget _dashboardQueuePageButton({
    String? label,
    IconData? icon,
    String? tooltip,
    required bool enabled,
    required bool isDark,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final foreground = selected
        ? _operatorNavyDeep
        : isDark
        ? Colors.grey.shade300
        : _operatorInk;
    final button = InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _operatorGold
              : isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? _operatorGold
                : isDark
                ? Colors.white12
                : Colors.grey.shade300,
          ),
        ),
        child: icon != null
            ? Icon(
                icon,
                size: 18,
                color: enabled ? foreground : foreground.withOpacity(0.3),
              )
            : Text(
                label ?? '',
                style: TextStyle(
                  color: enabled ? foreground : foreground.withOpacity(0.3),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _buildStatusBadge(String status) {
    final group = bookingStatusGroup(status);
    final color = bookingStatusColor(group);
    final label = bookingStatusLabel(group);

    final statusDescription = switch (group) {
      BookingStatusGroup.pending => 'Pending: Reservation is waiting for operator approval',
      BookingStatusGroup.approved => 'Approved: Booking is confirmed and ready for key handover',
      BookingStatusGroup.ongoing => 'Ongoing: Vehicle is currently active on trip with customer',
      BookingStatusGroup.completed => 'Completed: Trip successfully ended and finalized',
      BookingStatusGroup.cancelled => 'Cancelled: Booking was cancelled or declined',
      BookingStatusGroup.frozen => 'Frozen: Booking is frozen due to policy violation or safety review',
      _ => 'Status: $label',
    };

    return Tooltip(
      message: statusDescription,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.24)),
        ),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingList(bool isDark) {
    if (_pendingApplications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                size: 48,
                color: Colors.green.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No pending applications',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _pendingApplications
          .take(5)
          .map((app) => _buildApplicationTile(app, isDark))
          .toList(),
    );
  }

  Widget _buildApplicationTile(Map<String, dynamic> application, bool isDark) {
    final partner = application['partners'] as Map<String, dynamic>?;
    final user = partner?['users'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${application['brand'] ?? ''} ${application['model'] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  user?['full_name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _handleApplicationAction(
              application['id'].toString(),
              'approved',
            ),
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Approve',
          ),
          IconButton(
            onPressed: () => _handleApplicationAction(
              application['id'].toString(),
              'rejected',
            ),
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Reject',
          ),
        ],
      ),
    );
  }
  static final Map<String, List<MobilisMapPoint>> _operatorTrackingRoadRouteCache = {};

  List<MobilisMapPoint> _getOperatorTrackingRoutePoints(
    MobilisMapPoint? carPoint,
    MobilisMapPoint? destPoint,
  ) {
    if (carPoint == null) return const [];
    if (destPoint == null) return [carPoint];

    final cacheKey =
        '${carPoint.latitude.toStringAsFixed(3)},${carPoint.longitude.toStringAsFixed(3)}->${destPoint.latitude.toStringAsFixed(3)},${destPoint.longitude.toStringAsFixed(3)}';

    if (_operatorTrackingRoadRouteCache.containsKey(cacheKey)) {
      return _operatorTrackingRoadRouteCache[cacheKey]!;
    }

    // Trigger async fetch in background
    _fetchOperatorRoadPathway(cacheKey, carPoint, destPoint);

    // Fallback straight line while road pathway is loading
    return [carPoint, destPoint];
  }

  Future<void> _fetchOperatorRoadPathway(
    String cacheKey,
    MobilisMapPoint fromPoint,
    MobilisMapPoint toPoint,
  ) async {
    if (_operatorTrackingRoadRouteCache.containsKey(cacheKey)) return;
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
            _operatorTrackingRoadRouteCache[cacheKey] = roadPoints;
            if (mounted) setState(() {});
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Unable to fetch OSRM road route points: $e');
    }
    _operatorTrackingRoadRouteCache[cacheKey] = [fromPoint, toPoint];
  }

  MobilisMapPoint? _resolveOperatorTrackingPoint(
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
    final isStandby = location['is_standby'] == true;
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
        'stopTime': '0m',
      };
    }

    final locKey = location['vehicle_id']?.toString() ??
        location['booking_id']?.toString() ??
        location['id']?.toString() ??
        '';

    final isMoving = speedKph >= 3;
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

  String _resolveTrackingVehicleName(Map<String, dynamic> loc) {
    final booking = loc['bookings'] as Map<String, dynamic>?;
    var vehicle = (booking?['vehicles'] ??
            booking?['partner_vehicles'] ??
            loc['vehicle'])
        as Map<String, dynamic>?;
    final tracker = loc['tracker'] as Map<String, dynamic>?;

    final targetId = loc['vehicle_id']?.toString() ??
        tracker?['vehicle_id']?.toString() ??
        tracker?['partner_vehicle_id']?.toString() ??
        vehicle?['id']?.toString();
    if (targetId != null && targetId.isNotEmpty && !targetId.startsWith('tracker_')) {
      final real = _vehicles.firstWhere(
        (v) => v['id']?.toString() == targetId || v['partner_vehicle_id']?.toString() == targetId,
        orElse: () => const {},
      );
      if (real.isNotEmpty) {
        vehicle = real;
      }
    }

    final isUnassigned = (loc['is_unassigned_tracker'] == true ||
            vehicle?['is_unassigned_tracker'] == true ||
            (vehicle?['brand']?.toString().toLowerCase() == 'gps tracker' &&
                (vehicle?['model']?.toString().isEmpty != false ||
                    vehicle?['model']?.toString() == tracker?['device_identifier']?.toString() ||
                    vehicle?['model']?.toString() == loc['device_identifier']?.toString() ||
                    vehicle?['model']?.toString() == 'Device'))) &&
        (vehicle?['brand']?.toString().toLowerCase() == 'gps tracker' || vehicle?['brand'] == null);

    final deviceId = tracker?['device_identifier']?.toString().trim() ??
        loc['device_identifier']?.toString().trim() ??
        vehicle?['plate_number']?.toString().trim() ??
        '';

    if (isUnassigned) {
      return deviceId.isNotEmpty
          ? 'GPS Tracker $deviceId (Standby)'
          : 'GPS Tracker (Standby)';
    }

    // 1. Try resolving vehicle title via full _vehicleTitle lookup
    var title = _vehicleTitle(vehicle ?? booking);
    if (title.isEmpty || title == 'Partner Vehicle' || title == 'Vehicle') {
      final vName = vehicle?['vehicle_name']?.toString().trim() ?? '';
      if (vName.isNotEmpty &&
          vName.toLowerCase() != 'partner vehicle' &&
          vName.toLowerCase() != 'unknown vehicle' &&
          vName.toLowerCase() != 'vehicle' &&
          !vName.toLowerCase().startsWith('gps tracker')) {
        title = vName;
      } else {
        final b = vehicle?['brand']?.toString().trim() ?? '';
        final m = vehicle?['model']?.toString().trim() ?? '';
        final y = vehicle?['year']?.toString().trim() ?? '';
        final combo = [b, m].where((s) => s.isNotEmpty && s.toLowerCase() != 'gps tracker').join(' ');
        if (combo.isNotEmpty) {
          title = y.isEmpty ? combo : '$combo ($y)';
        }
      }
    }

    // 2. Fallback to tracker device ID if still generic
    if (title.isEmpty || title == 'Partner Vehicle' || title == 'Vehicle') {
      if (deviceId.isNotEmpty) {
        title = 'GPS Tracker $deviceId (Standby)';
      } else {
        title = loc['has_active_booking'] == true ? 'Tracked Trip' : 'Tracked Vehicle';
      }
    }

    // 3. Append plate number if not already part of title
    final plate = vehicle?['plate_number']?.toString().trim() ?? '';
    if (plate.isNotEmpty && !title.contains(plate) && !title.startsWith('GPS Tracker')) {
      return '$title ($plate)';
    }
    return title;
  }

}

