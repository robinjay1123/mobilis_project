part of '../partner_home_screen.dart';

class _PartnerEnlargedDriverMapDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> vehicle;
  final List<Map<String, dynamic>> initialDrivers;
  final List<Map<String, double>> initialMapTargets;
  final String? initialSelectedDriverId;
  final _PartnerHomeScreenState state;
  final void Function(String? driverId) onSelectDriver;
  final void Function(String driverId) onFinalize;

  const _PartnerEnlargedDriverMapDialog({
    required this.booking,
    required this.vehicle,
    required this.initialDrivers,
    required this.initialMapTargets,
    this.initialSelectedDriverId,
    required this.state,
    required this.onSelectDriver,
    required this.onFinalize,
  });

  @override
  State<_PartnerEnlargedDriverMapDialog> createState() =>
      _PartnerEnlargedDriverMapDialogState();
}

class _PartnerEnlargedDriverMapDialogState
    extends State<_PartnerEnlargedDriverMapDialog> {
  late String? _activeSelectedId;
  String _searchQuery = '';
  late List<Map<String, double>> _mapTargets;
  late List<Map<String, dynamic>> _drivers;
  Timer? _trackerTimer;
  bool _isRefreshing = false;
  DateTime? _lastTrackerUpdate;

  @override
  void initState() {
    super.initState();
    _activeSelectedId = widget.initialSelectedDriverId;
    _mapTargets = List.from(widget.initialMapTargets);
    _drivers = List.from(widget.initialDrivers);
    _lastTrackerUpdate = DateTime.now();

    // Constant live tracker polling every 15 seconds
    _trackerTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _pollLiveTracker();
    });
  }

  @override
  void dispose() {
    _trackerTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollLiveTracker() async {
    if (!mounted || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    final startDate = DateTime.tryParse(
      (widget.booking['start_at'] ?? widget.booking['start_date'])?.toString() ?? '',
    );
    final endDate = DateTime.tryParse(
      (widget.booking['end_at'] ?? widget.booking['end_date'])?.toString() ?? '',
    );
    final bookingId = widget.booking['id']?.toString();
    try {
      final refinedTargets =
          await widget.state._resolvePartnerBookingVehicleAndProximityTargets(widget.booking);
      if (mounted) {
        if (refinedTargets.isNotEmpty) {
          _mapTargets = refinedTargets;
        }
        final list = await BookingService().getAvailableVerifiedDrivers(
          bookingDate: startDate,
          startDate: startDate,
          endDate: endDate,
          excludeBookingId: bookingId,
          proximityTargets: _mapTargets,
          prioritizeProximity: true,
          prioritizePsdc: false,
        );
        if (mounted) {
          setState(() {
            _drivers = list;
            _lastTrackerUpdate = DateTime.now();
            _isRefreshing = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Partner enlarged map tracker poll error: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitName = widget.state._partnerVehicleTitle(widget.vehicle);
    final plate = widget.vehicle['plate_number']?.toString() ?? '';
    final pickup = widget.booking['pickup_location']?.toString().trim() ?? '';

    final filteredDrivers = _drivers.where((d) {
      if (_searchQuery.trim().isEmpty) return true;
      final user = d['users'] as Map<String, dynamic>? ?? {};
      final name = user['full_name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      final loc = user['location']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase().trim();
      return name.contains(q) || email.contains(q) || loc.contains(q);
    }).toList();

    final enlargedMapMarkers = <MobilisMapMarker>[
      // ── ONLY ONE Car marker: the booked vehicle at its tracker/location ──
      if (_mapTargets.isNotEmpty)
        MobilisMapMarker(
          latitude: _mapTargets.first['latitude']!,
          longitude: _mapTargets.first['longitude']!,
          icon: Icons.directions_car_filled_rounded,
          color: AppColors.primary,
          size: 44,
          label: unitName.isNotEmpty ? unitName : 'Vehicle',
          tooltip: unitName.isNotEmpty ? '$unitName (GPS Tracker)' : 'Vehicle',
        ),

      // Driver pins
      ..._drivers.map((driver) {
        final user = driver['users'] as Map<String, dynamic>? ?? {};
        final rawLocation = user['location'] ??
            user['address'] ??
            user['city'] ??
            driver['address'] ??
            '';
        final point = PhilippineGeocoding.resolveLocationSync(
          rawLocation,
          latitudeValue: user['latitude'] ?? driver['latitude'],
          longitudeValue: user['longitude'] ?? driver['longitude'],
        );

        if (!PhilippineGeocoding.isValidPhilippines(point)) {
          return const MobilisMapMarker(latitude: 0, longitude: 0);
        }

        final driverId = driver['id']?.toString() ?? '';
        final driverName = (user['full_name']?.toString().trim().isNotEmpty == true)
            ? user['full_name'].toString().trim()
            : (user['email']?.toString().split('@').first ?? 'Driver');
        final isSelected = _activeSelectedId == driverId;
        final isPsdcDriver = driver['is_psdc_driver'] == true ||
            user['is_psdc_driver'] == true ||
            driver['driver_tier']?.toString().toLowerCase() == 'psdc';

        final markerColor = isSelected
            ? AppColors.primary
            : isPsdcDriver
                ? const Color(0xFFD97706)
                : AppColors.success;

        final driverWidget = SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: markerColor.withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: isSelected ? 3 : 1,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 3.0 : 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : isPsdcDriver
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF0EA5E9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.sports_motorsports_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            ],
          ),
        );

        return MobilisMapMarker(
          latitude: point.latitude,
          longitude: point.longitude,
          icon: Icons.person_pin_circle_rounded,
          color: markerColor,
          size: 40,
          label: driverName,
          tooltip: driverName,
          customChild: driverWidget,
          onTap: () {
            final newId = (_activeSelectedId == driverId ? null : driverId);
            setState(() => _activeSelectedId = newId);
            widget.onSelectDriver(newId);
          },
        );
      }).where((m) => m.latitude != 0).toList(),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1100,
          maxHeight: 760,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.modalBgOf(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadowOf(context),
            border: Border.all(color: AppColors.modalBorderOf(context)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.map_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Partner Driver Proximity Map',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unitName,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Live indicator badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (_isRefreshing
                                            ? AppColors.primary
                                            : const Color(0xFF10B981))
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _PartnerLivePulseDot(
                                      color: _isRefreshing
                                          ? AppColors.primary
                                          : const Color(0xFF10B981),
                                      size: 5,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isRefreshing
                                          ? 'GPS REFRESHING...'
                                          : 'LIVE GPS (8s)',
                                      style: TextStyle(
                                        color: _isRefreshing
                                            ? AppColors.primary
                                            : const Color(0xFF10B981),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (plate.isNotEmpty) 'Plate: $plate',
                              if (pickup.isNotEmpty) 'Pickup: $pickup',
                              '${_drivers.length} Certified Drivers',
                              if (_lastTrackerUpdate != null)
                                'Last Fix: ${_lastTrackerUpdate!.hour.toString().padLeft(2, '0')}:${_lastTrackerUpdate!.minute.toString().padLeft(2, '0')}:${_lastTrackerUpdate!.second.toString().padLeft(2, '0')}',
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh Tracker',
                      icon: Icon(
                        Icons.sync_rounded,
                        color: _isRefreshing
                            ? AppColors.primary
                            : Colors.white70,
                      ),
                      onPressed: _isRefreshing ? null : _pollLiveTracker,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    final mapWidget = Stack(
                      children: [
                        Positioned.fill(
                          child: MobilisLeafletMap(
                            key: ValueKey(
                              'partner_enlarged_${_activeSelectedId ?? ''}_${enlargedMapMarkers.map((m) => '${m.latitude.toStringAsFixed(4)},${m.longitude.toStringAsFixed(4)}').join('|')}',
                            ),
                            markers: enlargedMapMarkers,
                            initialZoom:
                                enlargedMapMarkers.length > 1 ? 12 : 14,
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_car_filled_rounded,
                                    color: AppColors.primary, size: 14),
                                const SizedBox(width: 4),
                                const Text('Vehicle Tracker',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                                const SizedBox(width: 10),
                                const Icon(Icons.person_pin_circle_rounded,
                                    color: AppColors.success, size: 14),
                                const SizedBox(width: 4),
                                const Text('Verified Driver',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                                const SizedBox(width: 10),
                                const Icon(Icons.person_pin_circle_rounded,
                                    color: Color(0xFFF59E0B), size: 14),
                                const SizedBox(width: 4),
                                const Text('PSDC Driver',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );

                    final listWidget = Container(
                      width: isWide ? 340 : double.infinity,
                      color: const Color(0xFF0B132B),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Search driver by name or town...',
                                hintStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11),
                                prefixIcon: Icon(Icons.search_rounded,
                                    color: AppColors.textSecondary, size: 16),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.06),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: filteredDrivers.isEmpty
                                ? Center(
                                    child: Text(
                                      'No matching drivers',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    itemCount: filteredDrivers.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 6),
                                    itemBuilder: (context, idx) {
                                      final driver = filteredDrivers[idx];
                                      final driverId = driver['id'].toString();
                                      final user = driver['users']
                                              as Map<String, dynamic>? ??
                                          {};
                                      final name = (user['full_name']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ==
                                              true)
                                          ? user['full_name'].toString().trim()
                                          : (user['email']
                                                  ?.toString()
                                                  .split('@')
                                                  .first
                                                  .toUpperCase() ??
                                              'Driver');
                                      final isPsdcDriver =
                                          driver['is_psdc_driver'] == true ||
                                              user['is_psdc_driver'] == true ||
                                              driver['driver_tier']
                                                      ?.toString()
                                                      .toLowerCase() ==
                                                  'psdc';
                                      final selected =
                                          _activeSelectedId == driverId;
                                      final distance =
                                          (driver['distance_km'] as num?)
                                              ?.toDouble();
                                      final rating =
                                          (driver['rating'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                      final trips =
                                          (driver['total_trips'] as num?)
                                                  ?.toInt() ??
                                              0;
                                      final locationStr = user['location']
                                              ?.toString() ??
                                          user['city']?.toString() ??
                                          '';

                                      return InkWell(
                                        onTap: () {
                                          final newId = (_activeSelectedId ==
                                                  driverId
                                              ? null
                                              : driverId);
                                          setState(
                                              () => _activeSelectedId = newId);
                                          widget.onSelectDriver(newId);
                                        },
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 150),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? AppColors.primary
                                                : Colors.white
                                                    .withValues(alpha: 0.05),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: selected
                                                  ? AppColors.primary
                                                  : Colors.white
                                                      .withValues(alpha: 0.08),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? const Color(0xFF0F172A)
                                                      : (isPsdcDriver
                                                          ? const Color(
                                                              0xFFD97706)
                                                          : const Color(
                                                              0xFF0284C7)),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        color: selected
                                                            ? Colors.black
                                                            : Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      [
                                                        if (distance != null)
                                                          '${distance.toStringAsFixed(1)} km away',
                                                        '${rating.toStringAsFixed(1)} ★',
                                                        '$trips trips',
                                                        if (locationStr
                                                            .isNotEmpty)
                                                          locationStr,
                                                      ].join(' • '),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: selected
                                                            ? Colors.black87
                                                            : AppColors
                                                                .textSecondary,
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                selected
                                                    ? Icons.check_circle_rounded
                                                    : Icons.circle_outlined,
                                                color: selected
                                                    ? Colors.black
                                                    : Colors.white30,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              border: Border(
                                  top: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.08))),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: Colors.white24),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                    child: const Text('Close Map',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _activeSelectedId == null
                                        ? null
                                        : () {
                                            Navigator.pop(context);
                                            widget.onFinalize(
                                                _activeSelectedId!);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                    child: const Text('Assign Driver',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: mapWidget),
                          listWidget,
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          Expanded(flex: 3, child: mapWidget),
                          Expanded(flex: 4, child: listWidget),
                        ],
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
