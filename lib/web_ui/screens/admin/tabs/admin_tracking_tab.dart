part of '../admin_web_screen.dart';

extension _AdminTrackingTab on _AdminWebScreenState {
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
        pickupPoint = _resolveTrackingLocationPoint(
          fBooking?['pickup_latitude'],
          fBooking?['pickup_longitude'],
          fBooking?['pickup_location']?.toString() ?? '',
        );
        destPoint = _resolveTrackingLocationPoint(
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
          routePoints = _getTrackingRoutePoints(carPoint, destPoint);
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            isFocused
                ? 'Live Tracking (Focused Vehicle / Trip)'
                : 'Live Tracking (${visibleLocations.length} Vehicles)',
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
                          foregroundColor:
                              isDark ? Colors.white : Colors.black87,
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
                            : '💡 Hover over any car icon to view its name, or click any card below to focus on its position.',
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
                                      : AppColors.primary
                                          .withValues(alpha: 0.2)),
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
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87)),
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
                        child: mapMarkers.isEmpty
                            ? Center(
                                child: Text(
                                  _focusedTrackingBookingId == null
                                      ? 'No active tracking locations yet'
                                      : 'No live location yet for this vehicle',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
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
                                routeColor: AppColors.primary,
                                initialZoom: isFocused
                                    ? (mapMarkers.length > 1 ? 12 : 15)
                                    : (mapMarkers.length > 1 ? 10 : 14),
                              ),
                      ),
                    ),
                    if (_focusedTrackingBookingId != null &&
                        visibleLocations.isNotEmpty)
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
                              onPlayback: () {
                                final bk = focusedLoc['bookings']
                                    as Map<String, dynamic>?;
                                final veh = (bk?['vehicles'] ??
                                    focusedLoc['vehicle']) as Map<String,
                                    dynamic>?;
                                final vehName =
                                    _resolveTrackingVehicleName(focusedLoc);
                                TripRouteHistoryDialog.show(
                                  context: context,
                                  bookingId: bk?['id']?.toString(),
                                  vehicleId: focusedLoc['vehicle_id']?.toString() ??
                                      focusedLoc['tracker']?['vehicle_id']?.toString() ??
                                      veh?['id']?.toString(),
                                  trackerDeviceId: focusedLoc['tracker_device_id']?.toString() ??
                                      focusedLoc['tracker']?['device_id']?.toString() ??
                                      focusedLoc['tracker']?['imei']?.toString(),
                                  vehicleName: vehName,
                                  plateNumber: veh?['plate_number']?.toString() ??
                                      focusedLoc['plate_number']?.toString(),
                                  renterName: bk?['renter']?['full_name']?.toString(),
                                  initialLat: (focusedLoc['latitude'] as num?)?.toDouble(),
                                  initialLng: (focusedLoc['longitude'] as num?)?.toDouble(),
                                );
                              },
                              onMore: () {
                                var veh = (focusedLoc['bookings']?['vehicles'] ??
                                    focusedLoc['bookings']?['partner_vehicles'] ??
                                    focusedLoc['vehicle']) as Map<String, dynamic>?;
                                final targetId = focusedLoc['vehicle_id']?.toString() ??
                                    focusedLoc['tracker']?['vehicle_id']?.toString() ??
                                    focusedLoc['tracker']?['partner_vehicle_id']?.toString() ??
                                    veh?['id']?.toString();
                                if (targetId != null && targetId.isNotEmpty && !targetId.startsWith('tracker_')) {
                                  final real = _allVehicles.firstWhere(
                                    (v) => v['id']?.toString() == targetId || v['partner_vehicle_id']?.toString() == targetId,
                                    orElse: () => const {},
                                  );
                                  if (real.isNotEmpty) {
                                    veh = real;
                                  }
                                }
                                if (veh != null) {
                                  _showAdminVehicleDetailsDialog(veh, isDark);
                                }
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (visibleLocations.isEmpty)
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
        ],
      ),
    );
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
      final real = _allVehicles.firstWhere(
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
      destPoint = _resolveTrackingLocationPoint(
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

                        final vehicleImageUrl = _adminVehicleImageUrl(vehicle, booking);

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
                              if (booking?['is_partner_vehicle'] == true ||
                                  booking?['partner_id'] != null ||
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
                  onTracking: () {
                    setState(() {
                      _focusedTrackingBookingId = isFocused ? null : rowId;
                    });
                  },
                  onPlayback: () {
                    TripRouteHistoryDialog.show(
                      context: context,
                      bookingId: booking?['id']?.toString(),
                      vehicleId: location['vehicle_id']?.toString() ??
                          location['tracker']?['vehicle_id']?.toString() ??
                          vehicle?['id']?.toString(),
                      trackerDeviceId: location['tracker_device_id']?.toString() ??
                          location['tracker']?['device_id']?.toString() ??
                          location['tracker']?['imei']?.toString(),
                      vehicleName: vehicleName,
                      plateNumber: vehicle?['plate_number']?.toString() ??
                          location['plate_number']?.toString(),
                      renterName: renter?['full_name']?.toString(),
                      initialLat: lat,
                      initialLng: lng,
                    );
                  },
                  onGeofence: () {
                    setState(() {
                      _focusedTrackingBookingId = rowId;
                    });
                  },
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
                if (hasActiveBooking && booking?['id'] != null) ...[
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
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.7),
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
}
