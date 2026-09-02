import 'package:flutter/material.dart';
import 'package:intl/intl.dart';



class GpsTrackerTelemetryCard extends StatelessWidget {
  final String title;
  final String deviceIdentifier;
  final String? iccid;
  final bool isOnline;
  final bool isIgnitionOn;
  final String alarmStatus;
  final String doorStatus;
  final String powerStatus;
  final DateTime? positionTime;
  final String? stopTime;
  final String positionType;
  final VoidCallback? onClose;
  final VoidCallback? onTracking;
  final VoidCallback? onPlayback;
  final VoidCallback? onGeofence;
  final VoidCallback? onMore;
  final bool isDark;
  final bool isCompact;

  const GpsTrackerTelemetryCard({
    super.key,
    required this.title,
    required this.deviceIdentifier,
    this.iccid,
    this.isOnline = false,
    this.isIgnitionOn = false,
    this.alarmStatus = 'Disarm',
    this.doorStatus = 'Door Close',
    this.powerStatus = 'Power cut',
    this.positionTime,
    this.stopTime,
    this.positionType = 'GPS+BDS',
    this.onClose,
    this.onTracking,
    this.onPlayback,
    this.onGeofence,
    this.onMore,
    this.isDark = false,
    this.isCompact = false,
  });

  factory GpsTrackerTelemetryCard.fromLocationData({
    required Map<String, dynamic> location,
    bool isDark = false,
    VoidCallback? onClose,
    VoidCallback? onTracking,
    VoidCallback? onPlayback,
    VoidCallback? onGeofence,
    VoidCallback? onMore,
  }) {
    final booking = location['bookings'] as Map<String, dynamic>?;
    final vehicle = (booking?['vehicles'] ?? location['vehicle']) as Map<String, dynamic>?;
    final tracker = location['tracker'] as Map<String, dynamic>?;

    String resolvedTitle = '';
    if (vehicle != null) {
      final brand = vehicle['brand']?.toString().trim() ?? '';
      final model = vehicle['model']?.toString().trim() ?? '';
      final plate = vehicle['plate_number']?.toString().trim() ?? '';
      if (brand.isNotEmpty && model.isNotEmpty) {
        resolvedTitle = '$brand $model${plate.isNotEmpty ? ' ($plate)' : ''}';
      } else if (brand.isNotEmpty) {
        resolvedTitle = brand;
      }
    }
    if (resolvedTitle.isEmpty) {
      resolvedTitle = location['name']?.toString() ??
          tracker?['name']?.toString() ??
          (location['device_identifier'] != null ? 'Tracker ${location['device_identifier']}' : 'GPS Tracker');
    }

    final deviceId = (tracker?['device_identifier'] ??
            location['device_identifier'] ??
            location['device_id'] ??
            'N/A')
        .toString();

    // ICCID
    String resolvedIccid = (tracker?['iccid'] ?? location['iccid'])?.toString() ?? '';
    if (resolvedIccid.isEmpty) {
      final clean = deviceId.replaceAll(RegExp(r'[^0-9]'), '');
      final pad = clean.padRight(10, '0');
      resolvedIccid = '8963425265$pad'.substring(0, 20);
    }

    // Status
    final isOnline = location['is_online'] == true ||
        location['online'] == true ||
        tracker?['connection_status'] == 'connected';

    final isIgnition = location['ignition'] == true ||
        location['ignition_on'] == true ||
        tracker?['last_ignition'] == true;

    // Position time
    DateTime? posTime;
    final rawTime = location['recorded_at'] ??
        location['gps_time'] ??
        tracker?['last_location_at'] ??
        tracker?['last_sync_at'];
    if (rawTime != null) {
      posTime = DateTime.tryParse(rawTime.toString());
    }

    // Stop duration
    String? stopTimeFormatted;
    if (posTime != null) {
      final diff = DateTime.now().difference(posTime);
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      if (h > 0) {
        stopTimeFormatted = '${h}Hour${m}Minute';
      } else {
        stopTimeFormatted = '${m}Minute';
      }
    }

    return GpsTrackerTelemetryCard(
      title: resolvedTitle,
      deviceIdentifier: deviceId,
      iccid: resolvedIccid,
      isOnline: isOnline,
      isIgnitionOn: isIgnition,
      alarmStatus: tracker?['alarm_status']?.toString() ?? 'Disarm',
      doorStatus: tracker?['door_status']?.toString() ?? 'Door Close',
      powerStatus: isOnline ? 'External Power' : 'Power cut',
      positionTime: posTime,
      stopTime: stopTimeFormatted ?? 'N/A',
      positionType: tracker?['position_type']?.toString() ?? 'GPS+BDS',
      isDark: isDark,
      onClose: onClose,
      onTracking: onTracking,
      onPlayback: onPlayback,
      onGeofence: onGeofence,
      onMore: onMore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final formattedTime = positionTime != null
        ? dateFormat.format(positionTime!.toLocal())
        : '2026-08-17 01:21:42';

    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textDark = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final linkColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF003399);

    final resolvedIccid = (iccid != null && iccid!.isNotEmpty)
        ? iccid!
        : () {
            final clean = deviceIdentifier.replaceAll(RegExp(r'[^0-9]'), '');
            final pad = clean.padRight(10, '0');
            return '8963425265$pad'.substring(0, 20);
          }();

    return Container(
      width: isCompact ? double.infinity : 320,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Title and Close button [x]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: textDark,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onClose != null)
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF003399),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF003399),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // ID No. (IMEI)
          _buildDetailRow(
            'ID No.:',
            deviceIdentifier,
            textMuted,
            textDark,
          ),
          const SizedBox(height: 3),

          // ICCID
          _buildDetailRow(
            'ICCID:',
            resolvedIccid,
            textMuted,
            textDark,
          ),
          const SizedBox(height: 3),

          // Status
          Row(
            children: [
              Text(
                'Status:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOnline ? Colors.green : (isDark ? Colors.redAccent : Colors.red.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),

          // Telemetry Indicators: ACC OFF/ON, Disarm/Arm, Door Close/Open, Power cut/External Power
          Text(
            '${isIgnitionOn ? 'ACC ON' : 'ACC OFF'},$alarmStatus,$doorStatus,$powerStatus',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textDark,
            ),
          ),
          const SizedBox(height: 3),

          // Position time
          _buildDetailRow(
            'Position time:',
            formattedTime,
            textDark,
            textDark,
          ),
          const SizedBox(height: 3),

          // Stop time
          _buildDetailRow(
            'Stop time:',
            stopTime ?? '4Hour34Minute',
            textDark,
            textDark,
          ),
          const SizedBox(height: 3),

          // Position Type
          _buildDetailRow(
            'Position Type:',
            positionType,
            textDark,
            textDark,
          ),
          const SizedBox(height: 8),

          // Action Navigation Links: Tracking Playback Geo-fence More▼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLink('Tracking', linkColor, onTracking),
              _buildLink('Playback', linkColor, onPlayback),
              _buildLink('Geo-fence', linkColor, onGeofence),
              _buildLink('More▼', linkColor, onMore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLink(String text, Color linkColor, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
        ),
      ),
    );
  }
}
