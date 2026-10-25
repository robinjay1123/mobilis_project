part of '../partner_home_screen.dart';

class _PartnerLivePulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PartnerLivePulseDot({
    this.color = const Color(0xFF10B981),
    this.size = 8,
  });

  @override
  State<_PartnerLivePulseDot> createState() => _PartnerLivePulseDotState();
}

class _PartnerLivePulseDotState extends State<_PartnerLivePulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.6),
                blurRadius: widget.size * 1.2,
                spreadRadius: widget.size * 0.4,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Partner Driver Assignment Modal with Live GPS Tracker Auto-Refresh
// ─────────────────────────────────────────────────────────────────────────────
class _PartnerAssignDriverModal extends StatefulWidget {
  final Map<String, dynamic> booking;
  final _PartnerHomeScreenState state;
  final void Function(String driverId) onAssignDriver;

  const _PartnerAssignDriverModal({
    required this.booking,
    required this.state,
    required this.onAssignDriver,
  });

  @override
  State<_PartnerAssignDriverModal> createState() =>
      _PartnerAssignDriverModalState();
}

class _PartnerAssignDriverModalState extends State<_PartnerAssignDriverModal> {
  String? _selectedDriverId;
  final ScrollController _listScrollController = ScrollController();
  Timer? _trackerTimer;
  List<Map<String, double>> _mapTargets = [
    {
      'latitude': PhilippineGeocoding.defaultLat,
      'longitude': PhilippineGeocoding.defaultLng,
    },
  ];
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoadingDrivers = true;
  bool _isRefreshingTracker = false;
  DateTime? _lastTrackerUpdate;

  @override
  void initState() {
    super.initState();
    _fetchDrivers(initial: true);

    // Continuous 15-second live GPS tracker auto-refresh
    _trackerTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _pollLiveTracker();
    });
  }

  @override
  void dispose() {
    _trackerTimer?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDrivers({bool initial = false}) async {
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
            _isLoadingDrivers = false;
            _lastTrackerUpdate = DateTime.now();
          });
        }
      }
    } catch (e) {
      debugPrint('Partner driver fetch error: $e');
      if (mounted && initial) {
        setState(() => _isLoadingDrivers = false);
      }
    }
  }

  Future<void> _pollLiveTracker() async {
    if (!mounted || _isRefreshingTracker) return;
    setState(() => _isRefreshingTracker = true);
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
            _isRefreshingTracker = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Partner auto-refresh live tracker note: $e');
      if (mounted) {
        setState(() => _isRefreshingTracker = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.booking['vehicles'] as Map<String, dynamic>? ?? {};

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.airline_seat_recline_normal_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Assign Certified Driver',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Live tracker indicator chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (_isRefreshingTracker
                                        ? AppColors.primary
                                        : const Color(0xFF10B981))
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PartnerLivePulseDot(
                                  color: _isRefreshingTracker
                                      ? AppColors.primary
                                      : const Color(0xFF10B981),
                                  size: 6,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isRefreshingTracker
                                      ? 'REFRESHING GPS...'
                                      : 'LIVE GPS (8s)',
                                  style: TextStyle(
                                    color: _isRefreshingTracker
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
                        'Drivers continuously ranked by GPS tracker proximity to ${widget.state._partnerVehicleTitle(vehicle)}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Drivers list & Map
          Expanded(
            child: _isLoadingDrivers
                ? MobilisSkeletonList(
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    leadingIcon: Icons.badge_rounded,
                    itemCount: 4,
                  )
                : (_drivers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off_rounded,
                                color: AppColors.textSecondary,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No Available Certified Drivers',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All certified drivers are currently on active trips or unavailable.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _listScrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _drivers.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return widget.state._buildPartnerDriverCoverageSummary(
                              booking: widget.booking,
                              vehicle: vehicle,
                              drivers: _drivers,
                              mapTargets: _mapTargets,
                              selectedDriverId: _selectedDriverId,
                              isRefreshing: _isRefreshingTracker,
                              lastUpdated: _lastTrackerUpdate,
                              onRefreshTap: _pollLiveTracker,
                              onDriverMarkerTap: (driverId, driverIndex) {
                                final newId = (_selectedDriverId == driverId
                                    ? null
                                    : driverId);
                                setState(() => _selectedDriverId = newId);
                                if (newId != null &&
                                    _listScrollController.hasClients) {
                                  final targetIndex = driverIndex + 1;
                                  _listScrollController.animateTo(
                                    targetIndex * 80.0,
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOut,
                                  );
                                }
                              },
                              onEnlargeTap: () {
                                widget.state._showEnlargedPartnerDriverMapDialog(
                                  booking: widget.booking,
                                  vehicle: vehicle,
                                  drivers: _drivers,
                                  mapTargets: _mapTargets,
                                  selectedDriverId: _selectedDriverId,
                                  onSelectDriver: (driverId) {
                                    setState(() => _selectedDriverId = driverId);
                                  },
                                  onFinalize: (driverId) {
                                    Navigator.pop(context); // Close bottom sheet
                                    widget.onAssignDriver(driverId);
                                  },
                                );
                              },
                            );
                          }

                          final driver = _drivers[index - 1];
                          final driverId = driver['id'].toString();
                          final user =
                              driver['users'] as Map<String, dynamic>? ?? {};
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
                          final selected = _selectedDriverId == driverId;
                          final distance =
                              (driver['distance_km'] as num?)?.toDouble();
                          final rating =
                              (driver['rating'] as num?)?.toDouble() ?? 0.0;
                          final trips =
                              (driver['total_trips'] as num?)?.toInt() ?? 0;
                          final locationStr = user['location']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? user['location'].toString().trim()
                              : user['address']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? user['address'].toString().trim()
                                  : user['city']?.toString().trim() ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: InkWell(
                              onTap: () => setState(
                                () => _selectedDriverId =
                                    (_selectedDriverId == driverId
                                        ? null
                                        : driverId),
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.white.withValues(alpha: 0.08),
                                    width: selected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar + Badge
                                    SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? AppColors.primary
                                                  : (isPsdcDriver
                                                      ? const Color(0xFFD97706)
                                                      : const Color(0xFF0284C7)),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.person_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: isPsdcDriver
                                                    ? const Color(0xFFF59E0B)
                                                    : const Color(0xFF0EA5E9),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.sports_motorsports_rounded,
                                                color: Colors.white,
                                                size: 9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (isPsdcDriver)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF59E0B),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'PSDC',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              if (distance != null)
                                                '${distance.toStringAsFixed(1)} km away',
                                              '${rating.toStringAsFixed(1)} ★',
                                              '$trips trips',
                                              if (locationStr.isNotEmpty)
                                                locationStr,
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
                                    const SizedBox(width: 8),
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.circle_outlined,
                                      color: selected
                                          ? AppColors.primary
                                          : Colors.white30,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      )),
          ),

          // Bottom Action
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedDriverId == null
                        ? null
                        : () {
                            Navigator.pop(context);
                            widget.onAssignDriver(_selectedDriverId!);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Assign Driver',
                      style: TextStyle(fontWeight: FontWeight.w800),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Partner Enlarged Driver Proximity Map Dialog with Live Tracker Polling
// ─────────────────────────────────────────────────────────────────────────────

