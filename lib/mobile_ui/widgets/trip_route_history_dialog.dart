import 'package:flutter/material.dart';

import '../screens/partner/trip_route_history_screen.dart';
export '../screens/partner/trip_route_history_screen.dart';

class TripRouteHistoryDialog extends StatelessWidget {
  final String? bookingId;
  final String? vehicleId;
  final String? trackerDeviceId;
  final String? vehicleName;
  final String? plateNumber;
  final String? renterName;
  final double? initialLat;
  final double? initialLng;

  const TripRouteHistoryDialog({
    super.key,
    this.bookingId,
    this.vehicleId,
    this.trackerDeviceId,
    this.vehicleName,
    this.plateNumber,
    this.renterName,
    this.initialLat,
    this.initialLng,
  });

  static Future<void> show({
    required BuildContext context,
    String? bookingId,
    String? vehicleId,
    String? trackerDeviceId,
    String? vehicleName,
    String? plateNumber,
    String? renterName,
    double? initialLat,
    double? initialLng,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TripRouteHistoryScreen(
          bookingId: bookingId,
          vehicleId: vehicleId,
          trackerDeviceId: trackerDeviceId,
          vehicleName: vehicleName,
          plateNumber: plateNumber,
          renterName: renterName,
          initialLat: initialLat,
          initialLng: initialLng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 32,
        vertical: isCompact ? 20 : 32,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: size.height * 0.90,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: TripRouteHistoryScreen(
            bookingId: bookingId,
            vehicleId: vehicleId,
            trackerDeviceId: trackerDeviceId,
            vehicleName: vehicleName,
            plateNumber: plateNumber,
            renterName: renterName,
            initialLat: initialLat,
            initialLng: initialLng,
          ),
        ),
      ),
    );
  }
}
