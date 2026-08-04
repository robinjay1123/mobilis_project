import 'package:flutter/foundation.dart';

enum GpsConnectionStatus {
  pendingVerification,
  verified,
  connected,
  disconnected,
  offline,
  failed,
}

extension GpsConnectionStatusExtension on GpsConnectionStatus {
  String get value {
    switch (this) {
      case GpsConnectionStatus.pendingVerification:
        return 'pending_verification';
      case GpsConnectionStatus.verified:
        return 'verified';
      case GpsConnectionStatus.connected:
        return 'connected';
      case GpsConnectionStatus.disconnected:
        return 'disconnected';
      case GpsConnectionStatus.offline:
        return 'offline';
      case GpsConnectionStatus.failed:
        return 'failed';
    }
  }

  static GpsConnectionStatus fromString(String? status) {
    switch ((status ?? '').toLowerCase().trim()) {
      case 'verified':
        return GpsConnectionStatus.verified;
      case 'connected':
        return GpsConnectionStatus.connected;
      case 'disconnected':
        return GpsConnectionStatus.disconnected;
      case 'offline':
        return GpsConnectionStatus.offline;
      case 'failed':
        return GpsConnectionStatus.failed;
      case 'pending_verification':
      default:
        return GpsConnectionStatus.pendingVerification;
    }
  }
}

class VehicleTracker {
  final String id;
  final String? vehicleId;
  final String? partnerVehicleId;
  final String? vehicleApplicationId;
  final String? partnerId;
  final String? operatorId;
  final String provider;
  final String deviceIdentifier;
  final GpsConnectionStatus connectionStatus;
  final double? lastLatitude;
  final double? lastLongitude;
  final double? lastSpeed;
  final bool? lastIgnition;
  final DateTime? lastLocationAt;
  final DateTime? lastSyncAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleTracker({
    required this.id,
    this.vehicleId,
    this.partnerVehicleId,
    this.vehicleApplicationId,
    this.partnerId,
    this.operatorId,
    this.provider = 'aika168',
    required this.deviceIdentifier,
    this.connectionStatus = GpsConnectionStatus.pendingVerification,
    this.lastLatitude,
    this.lastLongitude,
    this.lastSpeed,
    this.lastIgnition,
    this.lastLocationAt,
    this.lastSyncAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleTracker.fromJson(Map<String, dynamic> json) {
    return VehicleTracker(
      id: json['id']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString(),
      partnerVehicleId: json['partner_vehicle_id']?.toString(),
      vehicleApplicationId: json['vehicle_application_id']?.toString(),
      partnerId: json['partner_id']?.toString(),
      operatorId: json['operator_id']?.toString(),
      provider: json['provider']?.toString() ?? 'aika168',
      deviceIdentifier: json['device_identifier']?.toString() ?? '',
      connectionStatus: GpsConnectionStatusExtension.fromString(
        json['connection_status']?.toString(),
      ),
      lastLatitude: (json['last_latitude'] as num?)?.toDouble(),
      lastLongitude: (json['last_longitude'] as num?)?.toDouble(),
      lastSpeed: (json['last_speed'] as num?)?.toDouble(),
      lastIgnition: json['last_ignition'] == true,
      lastLocationAt: json['last_location_at'] != null
          ? DateTime.tryParse(json['last_location_at'].toString())
          : null,
      lastSyncAt: json['last_sync_at'] != null
          ? DateTime.tryParse(json['last_sync_at'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'partner_vehicle_id': partnerVehicleId,
      'vehicle_application_id': vehicleApplicationId,
      'partner_id': partnerId,
      'operator_id': operatorId,
      'provider': provider,
      'device_identifier': deviceIdentifier,
      'connection_status': connectionStatus.value,
      'last_latitude': lastLatitude,
      'last_longitude': lastLongitude,
      'last_speed': lastSpeed,
      'last_ignition': lastIgnition,
      'last_location_at': lastLocationAt?.toIso8601String(),
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get maskedDeviceId {
    if (deviceIdentifier.length <= 4) return deviceIdentifier;
    final lastFour = deviceIdentifier.substring(deviceIdentifier.length - 4);
    return '********$lastFour';
  }

  bool get isConnected =>
      connectionStatus == GpsConnectionStatus.connected ||
      connectionStatus == GpsConnectionStatus.verified;

  bool get isOnline {
    if (lastSyncAt == null) return false;
    final diff = DateTime.now().difference(lastSyncAt!);
    return diff.inMinutes < 5;
  }
}

class GpsPositionData {
  final String vehicleId;
  final double latitude;
  final double longitude;
  final double speedKph;
  final bool ignitionOn;
  final bool isOnline;
  final String statusText;
  final DateTime? gpsTime;
  final DateTime receivedAt;

  GpsPositionData({
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    this.speedKph = 0,
    this.ignitionOn = false,
    this.isOnline = true,
    this.statusText = 'Connected',
    this.gpsTime,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory GpsPositionData.fromJson(Map<String, dynamic> json) {
    return GpsPositionData(
      vehicleId: json['vehicle_id']?.toString() ?? json['vehicleId']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      speedKph: (json['speed_kph'] as num?)?.toDouble() ?? (json['speed'] as num?)?.toDouble() ?? 0.0,
      ignitionOn: json['ignition'] == true || json['ignition_on'] == true,
      isOnline: json['online'] == true || json['is_online'] == true,
      statusText: json['status_text']?.toString() ?? json['status']?.toString() ?? 'Connected',
      gpsTime: json['gps_time'] != null ? DateTime.tryParse(json['gps_time'].toString()) : null,
      receivedAt: json['received_at'] != null ? DateTime.tryParse(json['received_at'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_id': vehicleId,
      'latitude': latitude,
      'longitude': longitude,
      'speed_kph': speedKph,
      'ignition': ignitionOn,
      'online': isOnline,
      'status_text': statusText,
      'gps_time': gpsTime?.toIso8601String(),
      'received_at': receivedAt.toIso8601String(),
    };
  }
}
