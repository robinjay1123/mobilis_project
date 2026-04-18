import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();

  factory AdminService() {
    return _instance;
  }

  AdminService._internal();

  final supabase = Supabase.instance.client;

  // ================== USER MANAGEMENT ==================

  /// Get all unverified users
  Future<List<Map<String, dynamic>>> getUnverifiedUsers() async {
    try {
      debugPrint('Fetching unverified users');
      final response = await supabase
          .from('users')
          .select('id, email, full_name, phone, role, created_at, id_verified')
          .eq('id_verified', false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching unverified users: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching unverified users: $e');
      return [];
    }
  }

  /// Get all verified users
  Future<List<Map<String, dynamic>>> getVerifiedUsers() async {
    try {
      debugPrint('Fetching verified users');
      final response = await supabase
          .from('users')
          .select('id, email, full_name, phone, role, created_at, id_verified')
          .eq('id_verified', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching verified users: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching verified users: $e');
      return [];
    }
  }

  /// Get users by role
  Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    try {
      debugPrint('Fetching users with role: $role');
      final response = await supabase
          .from('users')
          .select(
            'id, email, full_name, phone, role, created_at, id_verified, application_status',
          )
          .eq('role', role)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching users by role: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching users by role: $e');
      return [];
    }
  }

  /// Verify/approve user ID
  Future<void> verifyUser(String userId) async {
    try {
      debugPrint('Verifying user: $userId');
      await supabase
          .from('users')
          .update({'id_verified': true})
          .eq('id', userId);

      debugPrint('User verified successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error verifying user: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error verifying user: $e');
      rethrow;
    }
  }

  /// Reject user verification
  Future<void> rejectUserVerification(String userId, String reason) async {
    try {
      debugPrint('Rejecting user verification: $userId with reason: $reason');
      await supabase
          .from('users')
          .update({'id_verified': false, 'verification_status': 'rejected'})
          .eq('id', userId);

      debugPrint('User verification rejected');
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting verification: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error rejecting verification: $e');
      rethrow;
    }
  }

  /// Suspend a user
  Future<void> suspendUser(String userId, String reason) async {
    try {
      debugPrint('Suspending user: $userId with reason: $reason');
      await supabase
          .from('users')
          .update({
            'is_active': false,
            'suspension_reason': reason,
            'suspended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      debugPrint('User suspended successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error suspending user: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error suspending user: $e');
      rethrow;
    }
  }

  /// Unsuspend a user
  Future<void> unsuspendUser(String userId) async {
    try {
      debugPrint('Unsuspending user: $userId');
      await supabase
          .from('users')
          .update({
            'is_active': true,
            'suspension_reason': null,
            'suspended_at': null,
          })
          .eq('id', userId);

      debugPrint('User unsuspended successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error unsuspending user: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error unsuspending user: $e');
      rethrow;
    }
  }

  // ================== DRIVER APPLICATIONS ==================

  /// Get all pending driver applications
  Future<List<Map<String, dynamic>>> getPendingDriverApplications() async {
    try {
      debugPrint('Fetching pending driver applications');
      final response = await supabase
          .from('users')
          .select(
            'id, email, full_name, phone, application_status, created_at, role',
          )
          .eq('role', 'driver')
          .eq('application_status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching driver applications: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching driver applications: $e');
      return [];
    }
  }

  /// Get driver documents for review
  Future<List<Map<String, dynamic>>> getDriverDocumentsForReview(
    String driverId,
  ) async {
    try {
      debugPrint('Fetching driver documents for: $driverId');
      final response = await supabase
          .from('driver_documents')
          .select(
            'id, document_type, file_url, uploaded_at, expiry_date, status',
          )
          .eq('driver_id', driverId)
          .order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching driver documents: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching driver documents: $e');
      return [];
    }
  }

  /// Approve driver application
  Future<void> approveDriverApplication(String driverId, String notes) async {
    try {
      debugPrint('Approving driver application: $driverId');
      await supabase
          .from('users')
          .update({'application_status': 'approved'})
          .eq('id', driverId);

      // Log approval action
      await _logApplicationAction(driverId, 'driver', 'approved', notes);

      debugPrint('Driver application approved');
    } on PostgrestException catch (e) {
      debugPrint('Database error approving driver: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error approving driver: $e');
      rethrow;
    }
  }

  /// Reject driver application
  Future<void> rejectDriverApplication(String driverId, String reason) async {
    try {
      debugPrint('Rejecting driver application: $driverId');
      await supabase
          .from('users')
          .update({'application_status': 'rejected'})
          .eq('id', driverId);

      // Log rejection action
      await _logApplicationAction(driverId, 'driver', 'rejected', reason);

      debugPrint('Driver application rejected');
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting driver: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error rejecting driver: $e');
      rethrow;
    }
  }

  // ================== PARTNER APPLICATIONS ==================

  /// Get all pending partner applications
  Future<List<Map<String, dynamic>>> getPendingPartnerApplications() async {
    try {
      debugPrint('Fetching pending partner applications');
      final response = await supabase
          .from('users')
          .select(
            'id, email, full_name, phone, application_status, created_at, role',
          )
          .eq('role', 'partner')
          .eq('application_status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching partner applications: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching partner applications: $e');
      return [];
    }
  }

  /// Get pending vehicle applications for review
  Future<List<Map<String, dynamic>>> getPendingVehicleApplications() async {
    try {
      debugPrint('Fetching pending vehicle applications');
      final response = await supabase
          .from('partner_vehicle_applications')
          .select(
            'id, partner_id, brand, model, year, plate_number, vehicle_photo_url, application_status, created_at, users(full_name, email)',
          )
          .eq('application_status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching vehicle applications: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching vehicle applications: $e');
      return [];
    }
  }

  /// Approve partner application
  Future<void> approvePartnerApplication(String partnerId, String notes) async {
    try {
      debugPrint('Approving partner application: $partnerId');
      await supabase
          .from('users')
          .update({'application_status': 'approved'})
          .eq('id', partnerId);

      // Log approval action
      await _logApplicationAction(partnerId, 'partner', 'approved', notes);

      debugPrint('Partner application approved');
    } on PostgrestException catch (e) {
      debugPrint('Database error approving partner: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error approving partner: $e');
      rethrow;
    }
  }

  /// Reject partner application
  Future<void> rejectPartnerApplication(String partnerId, String reason) async {
    try {
      debugPrint('Rejecting partner application: $partnerId');
      await supabase
          .from('users')
          .update({'application_status': 'rejected'})
          .eq('id', partnerId);

      // Log rejection action
      await _logApplicationAction(partnerId, 'partner', 'rejected', reason);

      debugPrint('Partner application rejected');
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting partner: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error rejecting partner: $e');
      rethrow;
    }
  }

  /// Approve vehicle application
  Future<void> approveVehicleApplication(
    String applicationId,
    String notes,
  ) async {
    try {
      debugPrint('Approving vehicle application: $applicationId');
      await supabase
          .from('partner_vehicle_applications')
          .update({'application_status': 'approved'})
          .eq('id', applicationId);

      // Log approval
      await _logApplicationAction(applicationId, 'vehicle', 'approved', notes);

      debugPrint('Vehicle application approved');
    } on PostgrestException catch (e) {
      debugPrint('Database error approving vehicle: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error approving vehicle: $e');
      rethrow;
    }
  }

  /// Reject vehicle application
  Future<void> rejectVehicleApplication(
    String applicationId,
    String reason,
  ) async {
    try {
      debugPrint('Rejecting vehicle application: $applicationId');
      await supabase
          .from('partner_vehicle_applications')
          .update({
            'application_status': 'rejected',
            'rejection_reason': reason,
          })
          .eq('id', applicationId);

      // Log rejection
      await _logApplicationAction(applicationId, 'vehicle', 'rejected', reason);

      debugPrint('Vehicle application rejected');
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting vehicle: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error rejecting vehicle: $e');
      rethrow;
    }
  }

  // ================== DASHBOARD STATS ==================

  /// Get comprehensive dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      debugPrint('Fetching dashboard stats');

      // Count total users by role
      final totalUsers = await supabase.from('users').select('id');

      final drivers = await supabase
          .from('users')
          .select('id')
          .eq('role', 'driver');

      final partners = await supabase
          .from('users')
          .select('id')
          .eq('role', 'partner');

      final renters = await supabase
          .from('users')
          .select('id')
          .eq('role', 'renter');

      // Pending verifications
      final pendingVerifications = await supabase
          .from('users')
          .select('id')
          .eq('id_verified', false);

      // Pending applications
      final pendingDriverApps = await supabase
          .from('users')
          .select('id')
          .eq('role', 'driver')
          .eq('application_status', 'pending');

      final pendingPartnerApps = await supabase
          .from('users')
          .select('id')
          .eq('role', 'partner')
          .eq('application_status', 'pending');

      // Active bookings
      final activeBookings = await supabase
          .from('bookings')
          .select('id')
          .eq('status', 'active');

      // Total vehicles
      final totalVehicles = await supabase
          .from('partner_vehicle_applications')
          .select('id')
          .eq('application_status', 'approved');

      return {
        'total_users': totalUsers.length,
        'total_drivers': drivers.length,
        'total_partners': partners.length,
        'total_renters': renters.length,
        'pending_verifications': pendingVerifications.length,
        'pending_driver_applications': pendingDriverApps.length,
        'pending_partner_applications': pendingPartnerApps.length,
        'active_bookings': activeBookings.length,
        'approved_vehicles': totalVehicles.length,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching dashboard stats: ${e.message}');
      return {
        'total_users': 0,
        'total_drivers': 0,
        'total_partners': 0,
        'total_renters': 0,
        'pending_verifications': 0,
        'pending_driver_applications': 0,
        'pending_partner_applications': 0,
        'active_bookings': 0,
        'approved_vehicles': 0,
      };
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      return {
        'total_users': 0,
        'total_drivers': 0,
        'total_partners': 0,
        'total_renters': 0,
        'pending_verifications': 0,
        'pending_driver_applications': 0,
        'pending_partner_applications': 0,
        'active_bookings': 0,
        'approved_vehicles': 0,
      };
    }
  }

  // ================== HELPER METHODS ==================

  /// Log application action (approval/rejection)
  Future<void> _logApplicationAction(
    String entityId,
    String entityType,
    String action,
    String notes,
  ) async {
    try {
      await supabase.from('admin_audit_logs').insert({
        'entity_id': entityId,
        'entity_type': entityType,
        'action': action,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Warning: Failed to log action: $e');
      // Don't rethrow - logging failure shouldn't block main operation
    }
  }

  // ================== DOCUMENT EXPIRY CHECK ==================

  /// Get all users with expiring or expired documents
  Future<List<Map<String, dynamic>>> getUsersWithExpiringDocuments({
    int daysThreshold = 90,
  }) async {
    try {
      debugPrint('Fetching users with expiring documents');

      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      // Check driver documents
      final driverDocs = await supabase
          .from('driver_documents')
          .select('driver_id, document_type, expiry_date')
          .gte('expiry_date', now.toIso8601String())
          .lte('expiry_date', thresholdDate.toIso8601String());

      // Get unique driver IDs and fetch user info
      final driverIds = Set.from(
        driverDocs.map((d) => d['driver_id']).cast<String>(),
      );

      List<Map<String, dynamic>> usersWithExpiring = [];

      for (var driverId in driverIds) {
        final userResponse = await supabase
            .from('users')
            .select('id, email, full_name, role')
            .eq('id', driverId)
            .maybeSingle();

        if (userResponse != null) {
          usersWithExpiring.add({
            ...userResponse,
            'document_type': 'driver_license',
            'expiry_in_days': thresholdDate
                .difference(DateTime.parse(driverDocs.first['expiry_date']))
                .inDays,
          });
        }
      }

      return usersWithExpiring;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching expiring documents: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching expiring documents: $e');
      return [];
    }
  }

  /// Check if driver is eligible (documents valid)
  Future<bool> isDriverEligible(String driverId) async {
    try {
      final docs = await supabase
          .from('driver_documents')
          .select('expiry_date')
          .eq('driver_id', driverId);

      if (docs.isEmpty) return false;

      final now = DateTime.now();
      for (var doc in docs) {
        final expiryDate = doc['expiry_date'] as String?;
        if (expiryDate != null) {
          final expiry = DateTime.parse(expiryDate);
          if (expiry.isBefore(now)) {
            return false; // Document expired
          }
        }
      }

      return true; // All documents valid
    } catch (e) {
      debugPrint('Error checking driver eligibility: $e');
      return false;
    }
  }

  // ================== SEARCH & FILTER ==================

  /// Filter applications by role and status
  Future<List<Map<String, dynamic>>> filterApplications({
    String? role,
    String? status,
    DateTime? afterDate,
    DateTime? beforeDate,
  }) async {
    try {
      debugPrint('Filtering applications');

      var query = supabase
          .from('users')
          .select(
            'id, email, full_name, phone, role, application_status, created_at, id_verified',
          );

      if (role != null) {
        query = query.eq('role', role);
      }

      if (status != null) {
        query = query.eq('application_status', status);
      }

      if (afterDate != null) {
        query = query.gte('created_at', afterDate.toIso8601String());
      }

      if (beforeDate != null) {
        query = query.lte('created_at', beforeDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error filtering applications: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error filtering applications: $e');
      return [];
    }
  }

  /// Get audit log for entity
  Future<List<Map<String, dynamic>>> getAuditLog({
    String? entityId,
    String? entityType,
    int limit = 50,
  }) async {
    try {
      debugPrint('Fetching audit log');

      var query = supabase.from('admin_audit_logs').select('*');

      if (entityId != null) {
        query = query.eq('entity_id', entityId);
      }

      if (entityType != null) {
        query = query.eq('entity_type', entityType);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching audit log: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching audit log: $e');
      return [];
    }
  }

  // ================== OPERATOR ACTIVITY LOGGING ==================

  /// Log operator activity (login, logout, booking approval, driver assignment, etc.)
  Future<bool> logOperatorActivity({
    required String operatorId,
    required String
    activityType, // 'login', 'logout', 'booking_approved', 'driver_assigned', 'driver_rejected', 'profile_updated'
    String? description,
    String? bookingId,
    String? driverId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint(
        'Logging operator activity: $activityType for operator: $operatorId',
      );

      await supabase.from('admin_audit_logs').insert({
        'entity_id': operatorId,
        'entity_type': 'operator_activity',
        'action': activityType,
        'notes': description ?? '$activityType - Operator: $operatorId',
        'created_at': DateTime.now().toIso8601String(),
        'booking_id': bookingId,
        'driver_id': driverId,
        'metadata': metadata,
      });

      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error logging operator activity: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error logging operator activity: $e');
      return false;
    }
  }

  /// Get operator activity history (movements/actions)
  Future<List<Map<String, dynamic>>> getOperatorActivityHistory(
    String operatorId, {
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('Fetching activity history for operator: $operatorId');

      var query = supabase
          .from('admin_audit_logs')
          .select('*')
          .eq('entity_id', operatorId)
          .eq('entity_type', 'operator_activity');

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('Retrieved ${response.length} activity records for operator');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error fetching operator activity history: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint('Error fetching operator activity history: $e');
      return [];
    }
  }

  /// Get all operators with recent activity
  Future<List<Map<String, dynamic>>> getOperatorsWithRecentActivity({
    int minutesThreshold = 60,
  }) async {
    try {
      debugPrint(
        'Fetching operators with activity in last $minutesThreshold minutes',
      );

      final thresholdTime = DateTime.now().subtract(
        Duration(minutes: minutesThreshold),
      );

      final activities = await supabase
          .from('admin_audit_logs')
          .select('entity_id, action, created_at, notes')
          .eq('entity_type', 'operator_activity')
          .gte('created_at', thresholdTime.toIso8601String())
          .order('created_at', ascending: false);

      // Get unique operator IDs with their last activity
      final Map<String, dynamic> operatorMap = {};

      for (var activity in activities) {
        final operatorId = activity['entity_id'] as String;

        if (!operatorMap.containsKey(operatorId)) {
          // Fetch operator user info
          final userInfo = await supabase
              .from('users')
              .select('id, email, full_name, role')
              .eq('id', operatorId)
              .eq('role', 'operator')
              .maybeSingle();

          if (userInfo != null) {
            operatorMap[operatorId] = {
              ...userInfo,
              'last_activity': activity['action'],
              'last_activity_time': activity['created_at'],
              'activity_count': 0,
            };
          }
        }

        operatorMap[operatorId]?['activity_count'] =
            (operatorMap[operatorId]['activity_count'] ?? 0) + 1;
      }

      debugPrint('Found ${operatorMap.length} operators with recent activity');
      return operatorMap.values.cast<Map<String, dynamic>>().toList();
    } on PostgrestException catch (e) {
      debugPrint(
        'Database error fetching operators with activity: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint('Error fetching operators with activity: $e');
      return [];
    }
  }

  /// Get operator activity summary (aggregated stats)
  Future<Map<String, dynamic>> getOperatorActivitySummary(
    String operatorId,
  ) async {
    try {
      debugPrint('Fetching activity summary for operator: $operatorId');

      final activities = await supabase
          .from('admin_audit_logs')
          .select('action, created_at')
          .eq('entity_id', operatorId)
          .eq('entity_type', 'operator_activity');

      Map<String, int> actionCounts = {};
      DateTime? lastActivityTime;

      for (var activity in activities) {
        final action = activity['action'] as String;
        final timestamp = DateTime.parse(activity['created_at'] as String);

        actionCounts[action] = (actionCounts[action] ?? 0) + 1;

        if (lastActivityTime == null || timestamp.isAfter(lastActivityTime)) {
          lastActivityTime = timestamp;
        }
      }

      return {
        'operator_id': operatorId,
        'total_activities': activities.length,
        'action_breakdown': actionCounts,
        'last_activity_time': lastActivityTime?.toIso8601String(),
        'today_activities': activities
            .where(
              (a) =>
                  DateTime.parse(a['created_at'] as String).day ==
                  DateTime.now().day,
            )
            .length,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching activity summary: ${e.message}');
      return {};
    } catch (e) {
      debugPrint('Error fetching activity summary: $e');
      return {};
    }
  }

  /// Get operator activities by type (for filtering)
  Future<List<Map<String, dynamic>>> getOperatorActivitiesByType(
    String operatorId,
    String activityType, {
    int limit = 50,
  }) async {
    try {
      debugPrint('Fetching $activityType activities for operator: $operatorId');

      final response = await supabase
          .from('admin_audit_logs')
          .select('*')
          .eq('entity_id', operatorId)
          .eq('entity_type', 'operator_activity')
          .eq('action', activityType)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching activities by type: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching activities by type: $e');
      return [];
    }
  }

  // ================== DOCUMENT RENEWAL MANAGEMENT ==================

  /// Approve document renewal
  Future<bool> approveDocumentRenewal({
    required String documentId,
    required String docType, // 'driver', 'vehicle', 'renter'
    String? notes,
  }) async {
    try {
      debugPrint('Approving document renewal: $documentId');

      final tableName = docType == 'driver'
          ? 'driver_documents'
          : docType == 'vehicle'
          ? 'vehicle_documents'
          : 'renter_verification_documents';

      // Update document status to approved
      await supabase
          .from(tableName)
          .update({
            'status': 'approved',
            'approval_date': DateTime.now().toIso8601String(),
          })
          .eq('id', documentId);

      // Log the action
      await _logApplicationAction(
        documentId,
        'document_renewal',
        'approved',
        notes ?? 'Document renewal approved',
      );

      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error approving document renewal: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error approving document renewal: $e');
      return false;
    }
  }

  /// Reject document renewal with reason
  Future<bool> rejectDocumentRenewal({
    required String documentId,
    required String docType,
    required String reason,
  }) async {
    try {
      debugPrint('Rejecting document renewal: $documentId');

      final tableName = docType == 'driver'
          ? 'driver_documents'
          : docType == 'vehicle'
          ? 'vehicle_documents'
          : 'renter_verification_documents';

      // Update document status to rejected
      await supabase
          .from(tableName)
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'rejection_date': DateTime.now().toIso8601String(),
          })
          .eq('id', documentId);

      // Log the action
      await _logApplicationAction(
        documentId,
        'document_renewal',
        'rejected',
        reason,
      );

      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting document renewal: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error rejecting document renewal: $e');
      return false;
    }
  }

  /// Get all pending document renewals
  Future<List<Map<String, dynamic>>> getPendingDocumentRenewals({
    String? docType, // 'driver', 'vehicle', 'renter' or null for all
  }) async {
    try {
      debugPrint('Fetching pending document renewals');

      List<Map<String, dynamic>> pendingDocs = [];

      // Get pending driver documents
      if (docType == null || docType == 'driver') {
        final driverDocs = await supabase
            .from('driver_documents')
            .select('*, drivers(user_id), users(full_name, email)')
            .eq('status', 'pending')
            .order('created_at', ascending: false);

        for (var doc in driverDocs) {
          pendingDocs.add({...doc, 'document_type': 'driver_documents'});
        }
      }

      // Get pending vehicle documents
      if (docType == null || docType == 'vehicle') {
        final vehicleDocs = await supabase
            .from('vehicle_documents')
            .select('*, vehicles(brand, model), users(full_name, email, role)')
            .eq('status', 'pending')
            .order('created_at', ascending: false);

        for (var doc in vehicleDocs) {
          pendingDocs.add({...doc, 'document_type': 'vehicle_documents'});
        }
      }

      // Get pending renter documents
      if (docType == null || docType == 'renter') {
        final renterDocs = await supabase
            .from('renter_verification_documents')
            .select('*, users(full_name, email)')
            .eq('status', 'pending')
            .order('created_at', ascending: false);

        for (var doc in renterDocs) {
          pendingDocs.add({...doc, 'document_type': 'renter_documents'});
        }
      }

      return pendingDocs;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching pending renewals: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching pending renewals: $e');
      return [];
    }
  }

  /// Get document renewal history for user/vehicle
  Future<List<Map<String, dynamic>>> getDocumentRenewalHistory({
    required String entityId,
    String? docType,
  }) async {
    try {
      debugPrint('Fetching renewal history for: $entityId');

      final response = await supabase
          .from('admin_audit_logs')
          .select('*')
          .eq('entity_id', entityId)
          .or(
            'action.eq.document_renewal_approved,action.eq.document_renewal_rejected,action.eq.renewal_requested',
          )
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching renewal history: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching renewal history: $e');
      return [];
    }
  }

  /// Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
