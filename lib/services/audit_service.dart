import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized platform audit service.
/// Records comprehensive audit trails for Admin actions, Renter actions,
/// Operator actions, Driver actions, and Partner actions into `admin_audit_logs`.
class AuditService {
  static final AuditService _instance = AuditService._internal();

  factory AuditService() => _instance;

  AuditService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Helper to resolve the current active user info if available
  Map<String, String> _getCurrentActorInfo() {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final meta = user.userMetadata ?? {};
        final name = (meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? 'User').toString();
        final role = (meta['role'] ?? 'user').toString();
        return {
          'actor_id': user.id,
          'actor_name': name,
          'actor_role': role,
          'actor_email': user.email ?? '',
        };
      }
    } catch (_) {}
    return {
      'actor_id': '',
      'actor_name': 'System',
      'actor_role': 'system',
      'actor_email': '',
    };
  }

  /// Core audit logging method.
  /// Writes directly to `admin_audit_logs` without interrupting normal application flow.
  Future<bool> logAudit({
    required String action,
    required String category,
    String? entityId,
    String? entityType,
    String? notes,
    String? adminId,
    String? renterId,
    String? driverId,
    String? partnerId,
    String? vehicleId,
    String? bookingId,
    String? actorName,
    String? actorRole,
    Map<String, dynamic>? metadata,
    String? ipAddress,
  }) async {
    try {
      final actor = _getCurrentActorInfo();
      final effectiveActorName = actorName?.trim().isNotEmpty == true
          ? actorName!.trim()
          : actor['actor_name']!;
      final effectiveActorRole = actorRole?.trim().isNotEmpty == true
          ? actorRole!.trim().toLowerCase()
          : actor['actor_role']!;
      final effectiveAdminId = adminId ?? (effectiveActorRole == 'admin' ? actor['actor_id'] : null);

      final combinedMetadata = <String, dynamic>{
        'category': category,
        'actor_name': effectiveActorName,
        'actor_role': effectiveActorRole,
        'actor_id': actor['actor_id'],
        'actor_email': actor['actor_email'],
        if (metadata != null) ...metadata,
      };

      final payload = <String, dynamic>{
        'action': action,
        'category': category,
        'notes': notes ?? '$action ($category)',
        'created_at': DateTime.now().toIso8601String(),
        'metadata': combinedMetadata,
        'details': combinedMetadata,
      };

      if (entityId != null && entityId.isNotEmpty) payload['entity_id'] = entityId;
      if (entityType != null && entityType.isNotEmpty) payload['entity_type'] = entityType;
      if (effectiveAdminId != null && effectiveAdminId.isNotEmpty) payload['admin_id'] = effectiveAdminId;
      if (renterId != null && renterId.isNotEmpty) payload['renter_id'] = renterId;
      if (driverId != null && driverId.isNotEmpty) payload['driver_id'] = driverId;
      if (partnerId != null && partnerId.isNotEmpty) payload['partner_id'] = partnerId;
      if (vehicleId != null && vehicleId.isNotEmpty) payload['vehicle_id'] = vehicleId;
      if (bookingId != null && bookingId.isNotEmpty) payload['booking_id'] = bookingId;
      if (ipAddress != null && ipAddress.isNotEmpty) payload['ip_address'] = ipAddress;

      await _supabase.from('admin_audit_logs').insert(payload);
      debugPrint('[AuditService] Logged $action [$category] by $effectiveActorName ($effectiveActorRole)');
      return true;
    } catch (e) {
      debugPrint('[AuditService] Warning: Failed to record audit log ($action): $e');
      return false;
    }
  }

  /// Log an Admin action (user ban, verification, partner/driver approval, audit report export, rate updates, etc.)
  Future<bool> logAdminAction({
    required String action,
    String category = 'ADMIN ACTION',
    String? entityId,
    String? entityType,
    String? notes,
    String? adminId,
    String? renterId,
    String? driverId,
    String? partnerId,
    String? vehicleId,
    String? bookingId,
    String? actorName,
    Map<String, dynamic>? metadata,
  }) async {
    return logAudit(
      action: action,
      category: category,
      entityId: entityId,
      entityType: entityType,
      notes: notes,
      adminId: adminId,
      renterId: renterId,
      driverId: driverId,
      partnerId: partnerId,
      vehicleId: vehicleId,
      bookingId: bookingId,
      actorName: actorName,
      actorRole: 'admin',
      metadata: metadata,
    );
  }

  /// Log a Renter action (adding/removing car from favorites, creating booking, payment proof, trip cancellation, rating)
  Future<bool> logRenterAction({
    required String action,
    required String renterId,
    String category = 'RENTER REQUEST',
    String? notes,
    String? vehicleId,
    String? bookingId,
    String? actorName,
    Map<String, dynamic>? metadata,
  }) async {
    return logAudit(
      action: action,
      category: category,
      entityId: renterId,
      entityType: 'renter_activity',
      renterId: renterId,
      vehicleId: vehicleId,
      bookingId: bookingId,
      notes: notes,
      actorName: actorName,
      actorRole: 'renter',
      metadata: metadata,
    );
  }

  /// Log an Operator action (desk payment MPIN, booking approval, driver assignment, release/return inspection, payouts)
  Future<bool> logOperatorAction({
    required String action,
    required String operatorId,
    String category = 'OPERATOR ACTION',
    String? notes,
    String? bookingId,
    String? vehicleId,
    String? driverId,
    String? renterId,
    String? partnerId,
    String? actorName,
    Map<String, dynamic>? metadata,
  }) async {
    return logAudit(
      action: action,
      category: category,
      entityId: operatorId,
      entityType: 'operator_activity',
      bookingId: bookingId,
      vehicleId: vehicleId,
      driverId: driverId,
      renterId: renterId,
      partnerId: partnerId,
      notes: notes,
      actorName: actorName,
      actorRole: 'operator',
      metadata: metadata,
    );
  }
}
