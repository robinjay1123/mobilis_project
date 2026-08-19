import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import 'leaflet_map.dart';

typedef MobilisLocationResolver =
    Future<String> Function(
      double latitude,
      double longitude, {
      required String fallbackAddress,
    });

class MobilisLocationSelection {
  final String address;
  final double latitude;
  final double longitude;

  const MobilisLocationSelection({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

/// Compact, reusable map picker used by location fields and map previews.
/// The map is intentionally contained in a modal so forms and dashboards stay compact.
class MobilisLocationPickerModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final String confirmLabel;
  final String initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final double fallbackLatitude;
  final double fallbackLongitude;
  final List<MobilisMapMarker> additionalMarkers;
  final MobilisLocationResolver? resolveAddress;

  const MobilisLocationPickerModal({
    super.key,
    this.title = 'Pin trip destination',
    this.subtitle =
        'Search an address or use your current location to set the exact pin.',
    this.confirmLabel = 'Use this location',
    this.initialAddress = '',
    this.initialLatitude,
    this.initialLongitude,
    this.fallbackLatitude = 15.9758,
    this.fallbackLongitude = 120.5719,
    this.additionalMarkers = const [],
    this.resolveAddress,
  });

  static Future<MobilisLocationSelection?> show(
    BuildContext context, {
    String title = 'Pin trip destination',
    String subtitle =
        'Search an address or use your current location to set the exact pin.',
    String confirmLabel = 'Use this location',
    String initialAddress = '',
    double? initialLatitude,
    double? initialLongitude,
    double fallbackLatitude = 15.9758,
    double fallbackLongitude = 120.5719,
    List<MobilisMapMarker> additionalMarkers = const [],
    MobilisLocationResolver? resolveAddress,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<MobilisLocationSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => MobilisLocationPickerModal(
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
        initialAddress: initialAddress,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        fallbackLatitude: fallbackLatitude,
        fallbackLongitude: fallbackLongitude,
        additionalMarkers: additionalMarkers,
        resolveAddress: resolveAddress,
      ),
    );
  }

  @override
  State<MobilisLocationPickerModal> createState() =>
      _MobilisLocationPickerModalState();
}

class _MobilisLocationPickerModalState
    extends State<MobilisLocationPickerModal> {
  late final TextEditingController _searchController;
  final MapController _mapController = MapController();
  MobilisLocationSelection? _selection;
  bool _isResolving = false;
  String? _errorMessage;

  LatLng get _mapCenter {
    final selection = _selection;
    return selection == null
        ? LatLng(widget.fallbackLatitude, widget.fallbackLongitude)
        : LatLng(selection.latitude, selection.longitude);
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialAddress);
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selection = MobilisLocationSelection(
        address: widget.initialAddress.trim().isEmpty
            ? 'Pinned location'
            : widget.initialAddress.trim(),
        latitude: widget.initialLatitude!,
        longitude: widget.initialLongitude!,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _moveMap(LatLng point, {double zoom = 16}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(point, zoom);
      } catch (_) {
        // The map may not be attached when the modal is first displayed.
      }
    });
  }

  Future<String> _resolveAddress(
    double latitude,
    double longitude, {
    required String fallbackAddress,
  }) async {
    if (widget.resolveAddress != null) {
      return widget.resolveAddress!(
        latitude,
        longitude,
        fallbackAddress: fallbackAddress,
      );
    }

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts =
            [
                  place.name,
                  place.street,
                  place.subLocality,
                  place.locality,
                  place.subAdministrativeArea,
                  place.administrativeArea,
                ]
                .whereType<String>()
                .map((part) => part.trim())
                .where((part) => part.isNotEmpty && part != 'Unnamed Road')
                .toList();
        if (parts.isNotEmpty) return parts.toSet().join(', ');
      }
    } catch (_) {
      // Coordinates are still a valid selection when reverse geocoding fails.
    }

    return fallbackAddress.trim().isEmpty
        ? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
        : fallbackAddress.trim();
  }

  Future<void> _setMapSelection(LatLng point, {String? fallbackAddress}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      final address = await _resolveAddress(
        point.latitude,
        point.longitude,
        fallbackAddress: fallbackAddress ?? 'Pinned location',
      );
      if (!mounted) return;
      setState(() {
        _selection = MobilisLocationSelection(
          address: address,
          latitude: point.latitude,
          longitude: point.longitude,
        );
        _searchController.text = address;
      });
      _moveMap(point);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _isResolving) return;

    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });
    FocusScope.of(context).unfocus();

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) throw Exception('No matching location found.');
      final location = locations.first;
      final address = await _resolveAddress(
        location.latitude,
        location.longitude,
        fallbackAddress: query,
      );
      if (!mounted) return;
      setState(() {
        _selection = MobilisLocationSelection(
          address: address,
          latitude: location.latitude,
          longitude: location.longitude,
        );
        _searchController.text = address;
      });
      _moveMap(LatLng(location.latitude, location.longitude));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isResolving) return;

    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please turn on location services first.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission is required to pin this.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      await _setMapSelection(
        LatLng(position.latitude, position.longitude),
        fallbackAddress: 'Current location',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  List<MobilisMapMarker> get _markers {
    final selection = _selection;
    return [
      ...widget.additionalMarkers,
      if (selection != null)
        MobilisMapMarker(
          latitude: selection.latitude,
          longitude: selection.longitude,
          icon: Icons.location_pin,
          color: AppColors.primary,
          size: 44,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final tertiaryText = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;
    final fieldFill = isDark ? AppColors.darkBgTertiary : const Color(0xFFF1F5F9);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final mapHeight = (screenHeight * 0.30).clamp(220.0, 270.0).toDouble();
    final selection = _selection;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.94),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 18 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close map',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: secondaryText,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchAddress(),
              style: TextStyle(color: primaryText),
              decoration: InputDecoration(
                hintText: 'Search complete address',
                hintStyle: TextStyle(color: tertiaryText),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: secondaryText,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Search address',
                  onPressed: _isResolving ? null : _searchAddress,
                  icon: _isResolving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                  color: isDark ? AppColors.primary : AppColors.primaryDark,
                ),
                filled: true,
                fillColor: fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.primary : AppColors.primaryDark,
                    width: 1.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isResolving ? null : _useCurrentLocation,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Use current location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.primary : AppColors.primaryDark,
                  side: BorderSide(color: isDark ? AppColors.primary : AppColors.primaryDark),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: mapHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    MobilisLeafletMap(
                      mapController: _mapController,
                      fallbackLatitude: _mapCenter.latitude,
                      fallbackLongitude: _mapCenter.longitude,
                      initialZoom: selection == null ? 11 : 16,
                      markers: _markers,
                      onTap: (latitude, longitude) =>
                          _setMapSelection(LatLng(latitude, longitude)),
                    ),
                    const Positioned(
                      left: 10,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xDD111827),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          child: Text(
                            'Tap the map to place the pin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selection == null || _isResolving
                    ? null
                    : () => Navigator.pop(context, selection),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(widget.confirmLabel),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.darkBgTertiary,
                  foregroundColor: Colors.black,
                  disabledForegroundColor: AppColors.textTertiary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MobilisMapViewerModal extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<MobilisMapMarker> markers;
  final List<MobilisMapPoint> routePoints;
  final double fallbackLatitude;
  final double fallbackLongitude;

  const MobilisMapViewerModal({
    super.key,
    required this.title,
    required this.subtitle,
    this.markers = const [],
    this.routePoints = const [],
    this.fallbackLatitude = 15.9758,
    this.fallbackLongitude = 120.5719,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    List<MobilisMapMarker> markers = const [],
    List<MobilisMapPoint> routePoints = const [],
    double fallbackLatitude = 15.9758,
    double fallbackLongitude = 120.5719,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => MobilisMapViewerModal(
        title: title,
        subtitle: subtitle,
        markers: markers,
        routePoints: routePoints,
        fallbackLatitude: fallbackLatitude,
        fallbackLongitude: fallbackLongitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.borderColor : AppColors.lightBorderColor;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final mapHeight = (screenHeight * 0.58).clamp(300.0, 520.0).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close map',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: secondaryText,
                ),
              ],
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: mapHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    MobilisLeafletMap(
                      markers: markers,
                      routePoints: routePoints,
                      fallbackLatitude: fallbackLatitude,
                      fallbackLongitude: fallbackLongitude,
                      showAttribution: true,
                    ),
                    const Positioned(
                      left: 10,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xDD111827),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          child: Text(
                            'Drag or pinch the map to explore',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
