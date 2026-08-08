import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'renter_marketing_notification_service.dart';

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
            'id, email, full_name, phone, role, created_at, id_verified',
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

  Future<List<Map<String, dynamic>>> getRecentAnnouncements({
    int limit = 250,
  }) async {
    try {
      try {
        final processed = await supabase.rpc(
          'process_scheduled_announcements',
        );
        if (processed is num && processed > 0) {
          try {
            await supabase.functions.invoke('send-push-queue');
          } catch (e) {
            debugPrint('Scheduled announcement push dispatch skipped: $e');
          }
        }
      } catch (e) {
        debugPrint('Scheduled announcement processing fallback skipped: $e');
      }

      final response = await supabase
          .from('announcements')
          .select(
            'id, admin_id, title, message, target_role, announcement_type, status, scheduled_at, published_at, expires_at, cancelled_at, completed_at, created_at, updated_at',
          )
          .order('scheduled_at', ascending: false, nullsFirst: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      try {
        final legacyResponse = await supabase
            .from('announcements')
            .select('id, admin_id, title, message, target_role, created_at')
            .order('created_at', ascending: false)
            .limit(limit);
        return List<Map<String, dynamic>>.from(legacyResponse)
            .map(
              (announcement) => {
                ...announcement,
                'announcement_type': 'general',
                'status': 'active',
                'published_at': announcement['created_at'],
              },
            )
            .toList();
      } catch (legacyError) {
        debugPrint('Legacy announcement load failed: $legacyError');
        return [];
      }
    }
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String message,
    required String announcementType,
    required DateTime scheduledAt,
    String targetRole = 'all',
  }) async {
    final adminId = supabase.auth.currentUser?.id;
    final now = DateTime.now().toUtc();
    final scheduledUtc = scheduledAt.toUtc();
    final publishImmediately = !scheduledUtc.isAfter(
      now.add(const Duration(seconds: 30)),
    );
    final normalizedRole = targetRole.trim().toLowerCase();
    final normalizedType = announcementType.trim().toLowerCase();

    final announcement = await supabase
        .from('announcements')
        .insert({
          'admin_id': adminId,
          'title': title,
          'message': message,
          'target_role': normalizedRole,
          'announcement_type': normalizedType,
          'status': publishImmediately ? 'active' : 'scheduled',
          'scheduled_at': scheduledUtc.toIso8601String(),
          'published_at': publishImmediately ? now.toIso8601String() : null,
          'updated_at': now.toIso8601String(),
        })
        .select()
        .single();

    var delivered = 0;
    if (publishImmediately) {
      delivered = await NotificationService().broadcastAnnouncement(
        title: title,
        message: message,
        targetRole: normalizedRole,
        announcementId: announcement['id']?.toString(),
      );
      await supabase
          .from('announcements')
          .update({'notification_delivered_at': now.toIso8601String()})
          .eq('id', announcement['id']);
    }

    return {
      'announcement': Map<String, dynamic>.from(announcement),
      'delivered': delivered,
      'scheduled': !publishImmediately,
    };
  }

  Future<void> updateScheduledAnnouncement({
    required String announcementId,
    required String title,
    required String message,
    required String announcementType,
    required DateTime scheduledAt,
    String targetRole = 'all',
  }) async {
    await supabase
        .from('announcements')
        .update({
          'title': title,
          'message': message,
          'announcement_type': announcementType.trim().toLowerCase(),
          'target_role': targetRole.trim().toLowerCase(),
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'status': 'scheduled',
          'published_at': null,
          'cancelled_at': null,
          'completed_at': null,
          'notification_delivered_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', announcementId)
        .eq('status', 'scheduled');

    try {
      await supabase.rpc('process_scheduled_announcements');
    } catch (e) {
      debugPrint('Announcement due-date processing skipped after update: $e');
    }
  }

  Future<void> cancelScheduledAnnouncement(String announcementId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('announcements')
        .update({
          'status': 'cancelled',
          'cancelled_at': now,
          'updated_at': now,
        })
        .eq('id', announcementId)
        .eq('status', 'scheduled');
  }

  Future<void> completeAnnouncement(String announcementId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('announcements')
        .update({
          'status': 'completed',
          'completed_at': now,
          'updated_at': now,
        })
        .eq('id', announcementId)
        .eq('status', 'active');
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await supabase.from('announcements').delete().eq('id', announcementId);
  }

  Future<int> publishAnnouncement({
    required String title,
    required String message,
    String targetRole = 'all',
  }) async {
    final adminId = supabase.auth.currentUser?.id;
    final announcement = await supabase
        .from('announcements')
        .insert({
          'admin_id': adminId,
          'title': title,
          'message': message,
          'target_role': targetRole.trim().toLowerCase(),
          'announcement_type': 'general',
          'status': 'active',
          'scheduled_at': DateTime.now().toUtc().toIso8601String(),
          'published_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    final recipients = await NotificationService().broadcastAnnouncement(
      title: title,
      message: message,
      targetRole: targetRole,
      announcementId: announcement['id']?.toString(),
    );

    try {
      await supabase.functions.invoke('send-push-queue');
    } catch (e) {
      debugPrint('Announcement push dispatch trigger failed: $e');
    }

    return recipients;
  }

  /// Trigger a daily marketing promo notification to all renters
  Future<int> triggerRenterMarketingPromo() async {
    final promo = RenterMarketingNotificationService().getTodayPromoPrompt();
    final recipients = await NotificationService().broadcastAnnouncement(
      title: promo.title,
      message: promo.message,
      targetRole: 'renter',
    );
    try {
      await supabase.functions.invoke('send-push-queue');
    } catch (e) {
      debugPrint('Marketing promo push dispatch trigger failed: $e');
    }
    return recipients;
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

      await NotificationService().notifyDriverApplicationApproved(
        driverId: driverId,
      );

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
            'id, partner_id, brand, model, year, plate_number, seats, fuel_type, transmission, vehicle_photo_url, application_status, created_at, users(full_name, email)',
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

      await NotificationService().notifyPartnerApplicationApproved(
        partnerId: partnerId,
      );

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

      final application = await supabase
          .from('partner_vehicle_applications')
          .select('*')
          .eq('id', applicationId)
          .single();

      final partnerId = application['partner_id']?.toString();
      if (partnerId == null || partnerId.isEmpty) {
        throw Exception('Application is missing partner_id');
      }

      var partnerProfile = await supabase
          .from('partners')
          .select('id')
          .eq('user_id', partnerId)
          .maybeSingle();

      partnerProfile ??= await supabase
          .from('partners')
          .insert({
            'user_id': partnerId,
            'verification_status': 'approved',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final partnerProfileId = partnerProfile['id']?.toString();
      if (partnerProfileId == null || partnerProfileId.isEmpty) {
        throw Exception('Partner profile could not be resolved');
      }

      final createdVehicle = await supabase
          .from('vehicles')
          .insert({
            'owner_id': partnerId,
            'owner_role': 'partner',
            'vehicle_name':
                '${application['brand'] ?? ''} ${application['model'] ?? ''}'
                    .trim(),
            'brand': application['brand'],
            'model': application['model'],
            'year': application['year'],
            'plate_number': application['plate_number'],
            'seats': application['seats'] ?? 5,
            'price_per_day': application['price_per_day'] ?? 0,
            'price_per_hour': application['price_per_hour'] ?? 0,
            'fuel_type': application['fuel_type'] ?? 'Gasoline',
            'transmission': application['transmission'] ?? 'Manual',
            'owner_is_driver': application['owner_is_driver'] ?? false,
            'is_available': true,
            'is_posted': true,
            'status': 'available',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();
      final vehicleId = createdVehicle['id'];

      final partnerVehicle = await supabase
          .from('partner_vehicles')
          .insert({
            'partner_id': partnerProfileId,
            'brand': application['brand'],
            'model': application['model'],
            'year': application['year'],
            'plate_number': application['plate_number'],
            'seats': application['seats'] ?? 5,
            'price_per_day': application['price_per_day'] ?? 0,
            'price_per_hour': application['price_per_hour'] ?? 0,
            'fuel_type': application['fuel_type'] ?? 'Gasoline',
            'transmission': application['transmission'] ?? 'Manual',
            'owner_is_driver': application['owner_is_driver'] ?? false,
            'is_available': true,
            'vehicle_id': vehicleId,
            'status': 'available',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final partnerVehicleId = partnerVehicle['id'];
      final vehiclePhotoUrl = application['vehicle_photo_url']?.toString();
      final photoUrls = <String>[
        if (vehiclePhotoUrl != null && vehiclePhotoUrl.isNotEmpty)
          vehiclePhotoUrl,
      ];
      final photoDocs = await supabase
          .from('partner_vehicle_documents')
          .select('file_url')
          .eq('partner_vehicle_application_id', applicationId)
          .eq('document_type', 'vehicle_photo');
      for (final doc in List<Map<String, dynamic>>.from(photoDocs)) {
        final url = doc['file_url']?.toString();
        if (url != null && url.isNotEmpty && !photoUrls.contains(url)) {
          photoUrls.add(url);
        }
      }
      if (photoUrls.isNotEmpty) {
        await supabase
            .from('vehicle_images')
            .insert(
              List.generate(photoUrls.length, (index) {
                return {
                  'partner_vehicle_id': partnerVehicleId,
                  'vehicle_id': vehicleId,
                  'image_url': photoUrls[index],
                  'display_order': index,
                };
              }),
            );
      }

      final orUrl = application['or_document_url']?.toString();
      if (orUrl != null && orUrl.isNotEmpty) {
        await supabase.from('partner_vehicle_documents').insert({
          'partner_vehicle_application_id': applicationId,
          'document_type': 'or',
          'file_url': orUrl,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final crUrl = application['cr_document_url']?.toString();
      if (crUrl != null && crUrl.isNotEmpty) {
        await supabase.from('partner_vehicle_documents').insert({
          'partner_vehicle_application_id': applicationId,
          'document_type': 'cr',
          'file_url': crUrl,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await supabase
          .from('partner_vehicle_applications')
          .update({
            'application_status': 'approved',
            'status': 'approved',
            'verified_by': supabase.auth.currentUser?.id,
            'verified_at': DateTime.now().toIso8601String(),
            'reviewed_at': DateTime.now().toIso8601String(),
            'partner_vehicle_id': partnerVehicleId,
            'created_vehicle_id': vehicleId,
            'rejection_reason': null,
          })
          .eq('id', applicationId);

      // Log approval
      await _logApplicationAction(applicationId, 'vehicle', 'approved', notes);

      final vehicleTitle =
          '${application['brand'] ?? ''} ${application['model'] ?? ''}'.trim();
      await NotificationService().notifyPartnerApplicationApproved(
        partnerId: partnerId,
        applicationId: applicationId,
        vehicleTitle: vehicleTitle.isEmpty ? null : vehicleTitle,
      );

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
      final application = await supabase
          .from('partner_vehicle_applications')
          .select('partner_vehicle_id,created_vehicle_id,plate_number')
          .eq('id', applicationId)
          .single();
      await supabase
          .from('partner_vehicle_applications')
          .update({
            'application_status': 'rejected',
            'status': 'rejected',
            'rejection_reason': reason,
            'verified_by': supabase.auth.currentUser?.id,
            'verified_at': DateTime.now().toIso8601String(),
            'reviewed_at': DateTime.now().toIso8601String(),
            'is_available': false,
          })
          .eq('id', applicationId);

      final partnerVehicleId = application['partner_vehicle_id']?.toString();
      if (partnerVehicleId != null && partnerVehicleId.isNotEmpty) {
        await supabase
            .from('partner_vehicles')
            .update({'status': 'disabled', 'is_available': false})
            .eq('id', partnerVehicleId);
      }

      final createdVehicleId = application['created_vehicle_id']?.toString();
      if (createdVehicleId != null && createdVehicleId.isNotEmpty) {
        await supabase
            .from('vehicles')
            .update({
              'status': 'inactive',
              'is_available': false,
              'is_posted': false,
            })
            .eq('id', createdVehicleId);
      }

      final plateNumber = application['plate_number']?.toString().trim();
      if (plateNumber != null && plateNumber.isNotEmpty) {
        await supabase
            .from('vehicles')
            .update({
              'status': 'inactive',
              'is_available': false,
              'is_posted': false,
            })
            .eq('owner_role', 'partner')
            .eq('plate_number', plateNumber);
        await supabase
            .from('partner_vehicles')
            .update({'status': 'disabled', 'is_available': false})
            .eq('plate_number', plateNumber);
      }

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

  /// Get unified system action logs & audit trail with rich details
  Future<List<Map<String, dynamic>>> getSystemActionLogs({
    int limit = 150,
  }) async {
    try {
      final logs = <Map<String, dynamic>>[];
      final seenKeys = <String>{};

      // 1. Fetch direct audit log entries from admin_audit_logs
      try {
        final rawAuditRows = await supabase
            .from('admin_audit_logs')
            .select('*')
            .order('created_at', ascending: false)
            .limit(limit);
        for (final row in List<Map<String, dynamic>>.from(rawAuditRows)) {
          final id = row['id']?.toString() ?? '';
          final key = 'audit-$id';
          if (seenKeys.contains(key)) continue;
          seenKeys.add(key);

          final action = row['action']?.toString() ?? 'system_action';
          final entityType = row['entity_type']?.toString() ?? '';
          final notes = row['notes']?.toString() ?? '';
          final createdAt = row['created_at']?.toString() ?? '';
          final metadata = row['metadata'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(row['metadata'])
              : <String, dynamic>{};

          String category = 'SYSTEM';
          if (action.contains('approved') || action.contains('confirm')) {
            category = 'BOOKING APPROVAL';
          } else if (action.contains('driver') || action.contains('assign')) {
            category = 'DRIVER ASSIGNMENT';
          } else if (action.contains('payment')) {
            category = 'PAYMENT CONFIRMED';
          } else if (action.contains('partner')) {
            category = 'PARTNER APPROVAL';
          } else if (action.contains('verification')) {
            category = 'USER VERIFICATION';
          }

          logs.add({
            'id': key,
            'timestamp': createdAt,
            'category': category,
            'action_type': action,
            'entity_type': entityType,
            'actor_name': metadata['actor_name']?.toString() ?? metadata['operator_name']?.toString() ?? 'System / Operator',
            'actor_role': metadata['actor_role']?.toString() ?? 'operator',
            'notes': notes.isNotEmpty ? notes : '$action ($entityType)',
            'booking_id': row['booking_id']?.toString(),
            'driver_id': row['driver_id']?.toString(),
            'vehicle_id': row['vehicle_id']?.toString(),
            'metadata': metadata,
          });
        }
      } catch (e) {
        debugPrint('Warning fetching raw audit logs: $e');
      }

      // 2. Synthesize rich action logs from bookings
      try {
        final bookingRows = await supabase
            .from('bookings')
            .select('''
              id,
              status,
              completion_stage,
              created_at,
              updated_at,
              operator_trip_confirmed_at,
              partner_trip_confirmed_at,
              picked_up_at,
              returned_at,
              completed_at,
              final_payment_status,
              final_payment_confirmed_at,
              final_payment_confirmed_by,
              with_driver,
              driver_id,
              operator_id,
              renter_id,
              vehicle_id,
              renter:users!renter_id(full_name, email, role),
              vehicle:vehicles!vehicle_id(brand, model, vehicle_name, owner_id),
              driver_user:users!driver_id(full_name),
              operator_user:users!operator_id(full_name)
            ''')
            .order('updated_at', ascending: false)
            .limit(limit);

        for (final booking in List<Map<String, dynamic>>.from(bookingRows)) {
          final bookingId = booking['id']?.toString() ?? '';
          final shortId = bookingId.length > 8
              ? '#${bookingId.substring(0, 8).toUpperCase()}'
              : '#$bookingId';

          final renterMap = booking['renter'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(booking['renter'])
              : <String, dynamic>{};
          final renterName = renterMap['full_name']?.toString().trim().isNotEmpty == true
              ? renterMap['full_name'].toString().trim()
              : 'Renter (${renterMap['email'] ?? 'Unknown'})';

          final vehicleMap = booking['vehicle'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(booking['vehicle'])
              : <String, dynamic>{};
          final vehicleName = vehicleMap['vehicle_name']?.toString().trim().isNotEmpty == true
              ? vehicleMap['vehicle_name'].toString().trim()
              : '${vehicleMap['brand'] ?? ''} ${vehicleMap['model'] ?? ''}'.trim();
          final vehicleDisplay = vehicleName.isNotEmpty ? vehicleName : 'Vehicle';

          final driverMap = booking['driver_user'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(booking['driver_user'])
              : <String, dynamic>{};
          final driverName = driverMap['full_name']?.toString().trim().isNotEmpty == true
              ? driverMap['full_name'].toString().trim()
              : 'Assigned Driver';

          final operatorMap = booking['operator_user'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(booking['operator_user'])
              : <String, dynamic>{};
          final operatorName = operatorMap['full_name']?.toString().trim().isNotEmpty == true
              ? operatorMap['full_name'].toString().trim()
              : 'Operator Desk';

          final createdAt = booking['created_at']?.toString();
          final status = (booking['status'] ?? '').toString().toLowerCase();

          // Log A: Booking Created by Renter
          if (createdAt != null && createdAt.isNotEmpty) {
            final key = 'create-$bookingId';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              logs.add({
                'id': key,
                'timestamp': createdAt,
                'category': 'RENTER REQUEST',
                'action_type': 'booking_requested',
                'entity_type': 'booking',
                'actor_name': renterName,
                'actor_role': 'renter',
                'notes': '$renterName submitted rental reservation $shortId for $vehicleDisplay',
                'booking_id': bookingId,
                'metadata': {'renter_name': renterName, 'vehicle': vehicleDisplay},
              });
            }
          }

          // Log B: Booking Approved by Operator / Partner
          final approvedAt = booking['operator_trip_confirmed_at']?.toString() ??
              booking['partner_trip_confirmed_at']?.toString();
          if (approvedAt != null && approvedAt.isNotEmpty && (status == 'approved' || status == 'confirmed' || status == 'active' || status == 'ongoing' || status == 'completed')) {
            final key = 'approve-$bookingId';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              logs.add({
                'id': key,
                'timestamp': approvedAt,
                'category': 'BOOKING APPROVAL',
                'action_type': 'booking_approved',
                'entity_type': 'booking',
                'actor_name': operatorName,
                'actor_role': 'operator',
                'notes': '$operatorName approved reservation $shortId for Renter $renterName ($vehicleDisplay)',
                'booking_id': bookingId,
                'metadata': {'operator_name': operatorName, 'renter_name': renterName, 'vehicle': vehicleDisplay},
              });
            }
          }

          // Log C: Driver Assigned
          final driverId = booking['driver_id']?.toString();
          if (driverId != null && driverId.isNotEmpty) {
            final key = 'driver-$bookingId-$driverId';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              logs.add({
                'id': key,
                'timestamp': booking['updated_at']?.toString() ?? createdAt ?? '',
                'category': 'DRIVER ASSIGNMENT',
                'action_type': 'driver_assigned',
                'entity_type': 'booking',
                'actor_name': operatorName,
                'actor_role': 'operator',
                'notes': '$operatorName assigned Driver $driverName to reservation $shortId',
                'booking_id': bookingId,
                'driver_id': driverId,
                'metadata': {'operator_name': operatorName, 'driver_name': driverName},
              });
            }
          }

          // Log D: Final Payment Confirmed
          final paymentStatus = booking['final_payment_status']?.toString().toLowerCase();
          final paymentConfirmedAt = booking['final_payment_confirmed_at']?.toString();
          if (paymentStatus == 'paid' && paymentConfirmedAt != null && paymentConfirmedAt.isNotEmpty) {
            final key = 'payment-$bookingId';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              logs.add({
                'id': key,
                'timestamp': paymentConfirmedAt,
                'category': 'PAYMENT CONFIRMED',
                'action_type': 'payment_confirmed',
                'entity_type': 'booking',
                'actor_name': operatorName,
                'actor_role': 'operator',
                'notes': '$operatorName confirmed full final payment for reservation $shortId (Renter: $renterName)',
                'booking_id': bookingId,
                'metadata': {'operator_name': operatorName, 'renter_name': renterName},
              });
            }
          }

          // Log E: Trip Completed
          final completedAt = booking['completed_at']?.toString();
          if (status == 'completed' && completedAt != null && completedAt.isNotEmpty) {
            final key = 'complete-$bookingId';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              logs.add({
                'id': key,
                'timestamp': completedAt,
                'category': 'TRIP COMPLETED',
                'action_type': 'booking_completed',
                'entity_type': 'booking',
                'actor_name': operatorName,
                'actor_role': 'operator',
                'notes': 'Reservation $shortId for Renter $renterName ($vehicleDisplay) is fully completed',
                'booking_id': bookingId,
                'metadata': {'renter_name': renterName, 'vehicle': vehicleDisplay},
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Warning synthesizing booking action logs: $e');
      }

      // 3. Fetch Vehicle Return Inspections
      try {
        final inspectionRows = await supabase
            .from('booking_vehicle_inspections')
            .select('id, booking_id, inspection_type, inspector_id, completed_at, inspector:users!inspector_id(full_name, role)')
            .order('completed_at', ascending: false)
            .limit(limit);

        for (final row in List<Map<String, dynamic>>.from(inspectionRows)) {
          final id = row['id']?.toString() ?? '';
          final key = 'inspection-$id';
          if (seenKeys.contains(key)) continue;
          seenKeys.add(key);

          final type = row['inspection_type']?.toString() ?? 'inspection';
          final bookingId = row['booking_id']?.toString() ?? '';
          final shortId = bookingId.length > 8 ? '#${bookingId.substring(0, 8).toUpperCase()}' : '#$bookingId';
          final inspectorMap = row['inspector'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(row['inspector'])
              : <String, dynamic>{};
          final inspectorName = inspectorMap['full_name']?.toString().trim().isNotEmpty == true
              ? inspectorMap['full_name'].toString().trim()
              : 'Inspector / Operator';
          final inspectorRole = inspectorMap['role']?.toString().trim() ?? 'operator';
          final completedAt = row['completed_at']?.toString() ?? '';

          logs.add({
            'id': key,
            'timestamp': completedAt,
            'category': type == 'after' ? 'RETURN INSPECTION' : 'RELEASE INSPECTION',
            'action_type': 'inspection_$type',
            'entity_type': 'inspection',
            'actor_name': inspectorName,
            'actor_role': inspectorRole,
            'notes': '$inspectorName completed $type-trip vehicle inspection checklist for reservation $shortId',
            'booking_id': bookingId,
            'metadata': {'inspector_name': inspectorName, 'inspection_type': type},
          });
        }
      } catch (e) {
        debugPrint('Warning fetching inspection action logs: $e');
      }

      // 4. Sort all combined logs by timestamp descending
      logs.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      return logs.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting system action logs: $e');
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

  // ================== TRANSACTION/BOOKING HISTORY LOGGING ==================

  /// Log renter transaction (booking, payment, cancellation)
  Future<bool> logRenterTransaction({
    required String renterId,
    required String
    transactionType, // 'booking_created', 'booking_completed', 'payment_made', 'booking_cancelled', 'booking_rejected'
    String? description,
    String? bookingId,
    String? vehicleId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint(
        'Logging renter transaction: $transactionType for renter: $renterId',
      );

      await supabase.from('admin_audit_logs').insert({
        'entity_id': renterId,
        'entity_type': 'renter_transaction',
        'action': transactionType,
        'notes': description ?? '$transactionType - Renter: $renterId',
        'created_at': DateTime.now().toIso8601String(),
        'booking_id': bookingId,
        'vehicle_id': vehicleId,
        'metadata': metadata,
      });

      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error logging renter transaction: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error logging renter transaction: $e');
      return false;
    }
  }

  /// Log driver transaction (job acceptance, completion, cancellation)
  Future<bool> logDriverTransaction({
    required String driverId,
    required String
    transactionType, // 'job_accepted', 'job_completed', 'job_cancelled', 'job_rejected', 'earnings_received'
    String? description,
    String? bookingId,
    String? renterId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint(
        'Logging driver transaction: $transactionType for driver: $driverId',
      );

      await supabase.from('admin_audit_logs').insert({
        'entity_id': driverId,
        'entity_type': 'driver_transaction',
        'action': transactionType,
        'notes': description ?? '$transactionType - Driver: $driverId',
        'created_at': DateTime.now().toIso8601String(),
        'booking_id': bookingId,
        'renter_id': renterId,
        'metadata': metadata,
      });

      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error logging driver transaction: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error logging driver transaction: $e');
      return false;
    }
  }

  /// Log partner transaction (vehicle rental, completion, earnings)
  Future<bool> logPartnerTransaction({
    required String partnerId,
    required String
    transactionType, // 'vehicle_rented', 'rental_completed', 'rental_cancelled', 'earnings_received', 'vehicle_damaged'
    String? description,
    String? bookingId,
    String? vehicleId,
    String? renterId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint(
        'Logging partner transaction: $transactionType for partner: $partnerId',
      );

      await supabase.from('admin_audit_logs').insert({
        'entity_id': partnerId,
        'entity_type': 'partner_transaction',
        'action': transactionType,
        'notes': description ?? '$transactionType - Partner: $partnerId',
        'created_at': DateTime.now().toIso8601String(),
        'booking_id': bookingId,
        'vehicle_id': vehicleId,
        'renter_id': renterId,
        'metadata': metadata,
      });

      return true;
    } on PostgrestException catch (e) {
      debugPrint('Database error logging partner transaction: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error logging partner transaction: $e');
      return false;
    }
  }

  /// Get renter transaction history
  Future<List<Map<String, dynamic>>> getRenterTransactionHistory(
    String renterId, {
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType,
  }) async {
    try {
      debugPrint('Fetching transaction history for renter: $renterId');

      var query = supabase
          .from('admin_audit_logs')
          .select('*')
          .eq('entity_id', renterId)
          .eq('entity_type', 'renter_transaction');

      if (transactionType != null) {
        query = query.eq('action', transactionType);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('Retrieved ${response.length} renter transaction records');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching renter transactions: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching renter transactions: $e');
      return [];
    }
  }

  /// Get driver transaction history
  Future<List<Map<String, dynamic>>> getDriverTransactionHistory(
    String driverId, {
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType,
  }) async {
    try {
      debugPrint('Fetching transaction history for driver: $driverId');

      var query = supabase
          .from('admin_audit_logs')
          .select('*')
          .eq('entity_id', driverId)
          .eq('entity_type', 'driver_transaction');

      if (transactionType != null) {
        query = query.eq('action', transactionType);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('Retrieved ${response.length} driver transaction records');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching driver transactions: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching driver transactions: $e');
      return [];
    }
  }

  /// Get partner transaction history
  Future<List<Map<String, dynamic>>> getPartnerTransactionHistory(
    String partnerId, {
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType,
  }) async {
    try {
      debugPrint('Fetching transaction history for partner: $partnerId');

      var query = supabase
          .from('admin_audit_logs')
          .select('*')
          .eq('entity_id', partnerId)
          .eq('entity_type', 'partner_transaction');

      if (transactionType != null) {
        query = query.eq('action', transactionType);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('Retrieved ${response.length} partner transaction records');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching partner transactions: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching partner transactions: $e');
      return [];
    }
  }

  /// Get transaction history for booking (all parties involved)
  Future<List<Map<String, dynamic>>> getBookingTransactionHistory(
    String bookingId, {
    int limit = 100,
  }) async {
    try {
      debugPrint('Fetching all transactions for booking: $bookingId');

      final response = await supabase
          .from('admin_audit_logs')
          .select('*')
          .eq('booking_id', bookingId)
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('Retrieved ${response.length} booking transaction records');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching booking transactions: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching booking transactions: $e');
      return [];
    }
  }

  /// Get transaction summary for renter (stats)
  Future<Map<String, dynamic>> getRenterTransactionSummary(
    String renterId,
  ) async {
    try {
      debugPrint('Fetching transaction summary for renter: $renterId');

      final transactions = await supabase
          .from('admin_audit_logs')
          .select('action, created_at')
          .eq('entity_id', renterId)
          .eq('entity_type', 'renter_transaction');

      Map<String, int> actionCounts = {};
      DateTime? lastTransactionTime;

      for (var transaction in transactions) {
        final action = transaction['action'] as String;
        final timestamp = DateTime.parse(transaction['created_at'] as String);

        actionCounts[action] = (actionCounts[action] ?? 0) + 1;

        if (lastTransactionTime == null ||
            timestamp.isAfter(lastTransactionTime)) {
          lastTransactionTime = timestamp;
        }
      }

      return {
        'renter_id': renterId,
        'total_transactions': transactions.length,
        'action_breakdown': actionCounts,
        'last_transaction_time': lastTransactionTime?.toIso8601String(),
        'today_transactions': transactions
            .where(
              (t) =>
                  DateTime.parse(t['created_at'] as String).day ==
                  DateTime.now().day,
            )
            .length,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching renter summary: ${e.message}');
      return {};
    } catch (e) {
      debugPrint('Error fetching renter summary: $e');
      return {};
    }
  }

  /// Get transaction summary for driver (stats)
  Future<Map<String, dynamic>> getDriverTransactionSummary(
    String driverId,
  ) async {
    try {
      debugPrint('Fetching transaction summary for driver: $driverId');

      final transactions = await supabase
          .from('admin_audit_logs')
          .select('action, created_at')
          .eq('entity_id', driverId)
          .eq('entity_type', 'driver_transaction');

      Map<String, int> actionCounts = {};
      DateTime? lastTransactionTime;

      for (var transaction in transactions) {
        final action = transaction['action'] as String;
        final timestamp = DateTime.parse(transaction['created_at'] as String);

        actionCounts[action] = (actionCounts[action] ?? 0) + 1;

        if (lastTransactionTime == null ||
            timestamp.isAfter(lastTransactionTime)) {
          lastTransactionTime = timestamp;
        }
      }

      return {
        'driver_id': driverId,
        'total_transactions': transactions.length,
        'action_breakdown': actionCounts,
        'last_transaction_time': lastTransactionTime?.toIso8601String(),
        'today_transactions': transactions
            .where(
              (t) =>
                  DateTime.parse(t['created_at'] as String).day ==
                  DateTime.now().day,
            )
            .length,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching driver summary: ${e.message}');
      return {};
    } catch (e) {
      debugPrint('Error fetching driver summary: $e');
      return {};
    }
  }

  /// Get transaction summary for partner (stats)
  Future<Map<String, dynamic>> getPartnerTransactionSummary(
    String partnerId,
  ) async {
    try {
      debugPrint('Fetching transaction summary for partner: $partnerId');

      final transactions = await supabase
          .from('admin_audit_logs')
          .select('action, created_at')
          .eq('entity_id', partnerId)
          .eq('entity_type', 'partner_transaction');

      Map<String, int> actionCounts = {};
      DateTime? lastTransactionTime;

      for (var transaction in transactions) {
        final action = transaction['action'] as String;
        final timestamp = DateTime.parse(transaction['created_at'] as String);

        actionCounts[action] = (actionCounts[action] ?? 0) + 1;

        if (lastTransactionTime == null ||
            timestamp.isAfter(lastTransactionTime)) {
          lastTransactionTime = timestamp;
        }
      }

      return {
        'partner_id': partnerId,
        'total_transactions': transactions.length,
        'action_breakdown': actionCounts,
        'last_transaction_time': lastTransactionTime?.toIso8601String(),
        'today_transactions': transactions
            .where(
              (t) =>
                  DateTime.parse(t['created_at'] as String).day ==
                  DateTime.now().day,
            )
            .length,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching partner summary: ${e.message}');
      return {};
    } catch (e) {
      debugPrint('Error fetching partner summary: $e');
      return {};
    }
  }

  // ================== DRIVER DOCUMENT VERIFICATION ==================

  /// Get all pending driver documents across all drivers
  Future<List<Map<String, dynamic>>> getAllPendingDriverDocuments() async {
    try {
      debugPrint('Fetching all pending driver documents');

      final response = await supabase
          .from('driver_documents')
          .select('*, drivers(user_id), users(full_name, email)')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching pending documents: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching pending documents: $e');
      return [];
    }
  }

  /// Get driver document details for review
  Future<Map<String, dynamic>?> getDriverDocumentForReview(
    String documentId,
  ) async {
    try {
      debugPrint('Fetching driver document for review: $documentId');

      final response = await supabase
          .from('driver_documents')
          .select(
            '*, drivers(user_id, license_number, verification_status), users(full_name, email)',
          )
          .eq('id', documentId)
          .maybeSingle();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching document: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error fetching document: $e');
      return null;
    }
  }

  /// Verify individual driver document and update drivers table if all docs verified
  Future<Map<String, dynamic>> verifyDriverDocument({
    required String documentId,
    required String driverId,
    String? adminNotes,
  }) async {
    try {
      debugPrint('Verifying driver document: $documentId');

      // Mark document as verified
      await supabase
          .from('driver_documents')
          .update({
            'status': 'verified',
            'verified_at': DateTime.now().toIso8601String(),
            if (adminNotes != null) 'admin_notes': adminNotes,
          })
          .eq('id', documentId);

      // Check if all documents for this driver are now verified
      final pendingDocs = await supabase
          .from('driver_documents')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'pending');

      // If no more pending docs, get the document type that was just verified
      final verifiedDoc = await supabase
          .from('driver_documents')
          .select('document_type')
          .eq('id', documentId)
          .single();

      final docType = verifiedDoc['document_type'] as String;

      // Update drivers table based on document type
      Map<String, dynamic> driverUpdate = {};

      if (docType == 'license') {
        driverUpdate['license_verified'] = true;
      } else if (docType == 'nbi') {
        driverUpdate['nbi_verified'] = true;
      }

      // If all documents are verified, mark as approved
      if (pendingDocs.isEmpty) {
        driverUpdate['verification_status'] = 'approved';
      }

      if (driverUpdate.isNotEmpty) {
        await supabase.from('drivers').update(driverUpdate).eq('id', driverId);
      }

      debugPrint('Document verified successfully');
      return {
        'success': true,
        'message': 'Document verified',
        'all_verified': pendingDocs.isEmpty,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error verifying document: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('Error verifying document: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Reject driver document with reason
  Future<Map<String, dynamic>> rejectDriverDocument({
    required String documentId,
    required String reason,
  }) async {
    try {
      debugPrint('Rejecting driver document: $documentId');

      await supabase
          .from('driver_documents')
          .update({
            'status': 'rejected',
            'admin_notes': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', documentId);

      debugPrint('Document rejected successfully');
      return {'success': true, 'message': 'Document rejected'};
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting document: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('Error rejecting document: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Complete driver verification (all documents approved, mark driver as verified)
  Future<Map<String, dynamic>> completeDriverVerification({
    required String driverId,
    required String tier,
    String? adminNotes,
  }) async {
    try {
      debugPrint('Completing driver verification for: $driverId');

      // Update driver with final verification status and tier
      await supabase
          .from('drivers')
          .update({
            'verification_status': 'approved',
            'license_verified': true,
            'nbi_verified': true,
            'driver_tier': tier,
          })
          .eq('id', driverId);

      final driverProfile = await supabase
          .from('drivers')
          .select('user_id')
          .eq('id', driverId)
          .maybeSingle();
      final driverUserId = driverProfile?['user_id']?.toString();

      // Also update users table application_status.
      await supabase
          .from('users')
          .update({'application_status': 'approved'})
          .eq(
            'id',
            driverUserId != null && driverUserId.isNotEmpty
                ? driverUserId
                : driverId,
          );

      await NotificationService().notifyVerificationApproved(
        userId: driverUserId != null && driverUserId.isNotEmpty
            ? driverUserId
            : driverId,
        role: 'driver',
      );

      debugPrint('Driver verification completed successfully');
      return {
        'success': true,
        'message': 'Driver verification completed',
        'tier': tier,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error completing verification: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('Error completing verification: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Reject entire driver verification
  Future<Map<String, dynamic>> rejectDriverVerification({
    required String driverId,
    required String reason,
  }) async {
    try {
      debugPrint('Rejecting driver verification for: $driverId');

      // Get all pending documents
      final pendingDocs = await supabase
          .from('driver_documents')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'pending');

      // Mark all as rejected
      for (var doc in pendingDocs) {
        await supabase
            .from('driver_documents')
            .update({
              'status': 'rejected',
              'admin_notes': reason,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', doc['id']);
      }

      // Update driver status
      await supabase
          .from('drivers')
          .update({'verification_status': 'rejected'})
          .eq('id', driverId);

      // Update users table
      await supabase
          .from('users')
          .update({'application_status': 'rejected'})
          .eq('id', driverId);

      debugPrint('Driver verification rejected successfully');
      return {
        'success': true,
        'message': 'Driver verification rejected',
        'documents_rejected': pendingDocs.length,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting verification: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('Error rejecting verification: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get driver verification summary
  Future<Map<String, dynamic>> getDriverVerificationSummary(
    String driverId,
  ) async {
    try {
      debugPrint('Fetching verification summary for driver: $driverId');

      final driver = await supabase
          .from('drivers')
          .select()
          .eq('id', driverId)
          .single();

      final documents = await supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId);

      final user = await supabase
          .from('users')
          .select()
          .eq('id', driver['user_id'])
          .single();

      return {
        'driver_id': driverId,
        'user_id': driver['user_id'],
        'full_name': user['full_name'],
        'email': user['email'],
        'verification_status': driver['verification_status'],
        'tier': driver['driver_tier'],
        'license_verified': driver['license_verified'],
        'nbi_verified': driver['nbi_verified'],
        'documents': documents,
        'total_documents': documents.length,
        'verified_documents': (documents as List)
            .where((d) => d['status'] == 'verified')
            .length,
        'pending_documents': (documents as List)
            .where((d) => d['status'] == 'pending')
            .length,
        'rejected_documents': (documents as List)
            .where((d) => d['status'] == 'rejected')
            .length,
      };
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching summary: ${e.message}');
      return {'error': e.message};
    } catch (e) {
      debugPrint('Error fetching summary: $e');
      return {'error': e.toString()};
    }
  }

  // ================== PARTNER VERIFICATION ==================

  /// Get all pending partner identity verifications (separate from vehicle docs)
  /// Partners complete this FIRST (like renters)
  Future<List<Map<String, dynamic>>> getPendingPartnerVerifications() async {
    try {
      debugPrint('Fetching pending partner verifications');

      final response = await supabase
          .from('user_verifications')
          .select(
            '*, users!inner(id, full_name, email, phone, created_at, role)',
          )
          .eq('verification_status', 'pending')
          .eq('users.role', 'partner') // works with !inner join
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching partner verifications: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching partner verifications: $e');
      return [];
    }
  }

  /// Get partner verification details for review
  Future<Map<String, dynamic>?> getPartnerVerificationForReview(
    String userId,
  ) async {
    try {
      debugPrint('Fetching partner verification for review: $userId');

      final response = await supabase
          .from('user_verifications')
          .select('*, users(id, full_name, email, phone, location, created_at)')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching verification: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error fetching verification: $e');
      return null;
    }
  }

  /// Approve partner identity verification
  Future<Map<String, dynamic>> approvePartnerVerification({
    required String userId,
    String? adminNotes,
  }) async {
    try {
      debugPrint('Approving partner verification for: $userId');

      // Update user_verifications
      await supabase
          .from('user_verifications')
          .update({
            'verification_status': 'verified',
            'verified_at': DateTime.now().toIso8601String(),
            if (adminNotes != null) 'admin_notes': adminNotes,
          })
          .eq('user_id', userId);

      // Update users table
      await supabase
          .from('users')
          .update({'id_verified': true, 'application_status': 'approved'})
          .eq('id', userId);

      debugPrint('Partner verification approved successfully');
      return {'success': true, 'message': 'Partner verification approved'};
    } on PostgrestException catch (e) {
      debugPrint('Database error approving verification: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('Error approving verification: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Reject partner identity verification
  Future<Map<String, dynamic>> rejectPartnerVerification({
    required String userId,
    required String reason,
  }) async {
    try {
      debugPrint('Rejecting partner verification for: $userId');

      // Update user_verifications
      await supabase
          .from('user_verifications')
          .update({
            'verification_status': 'rejected',
            'rejection_reason': reason,
          })
          .eq('user_id', userId);

      // Update users table
      await supabase
          .from('users')
          .update({'id_verified': false, 'application_status': 'rejected'})
          .eq('id', userId);

      debugPrint('Partner verification rejected successfully');
      return {'success': true, 'message': 'Partner verification rejected'};
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting verification: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('Error rejecting verification: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================== VEHICLE DOCUMENT VERIFICATION ==================

  /// Get all pending vehicle documents (for vehicle applications)
  /// This is SEPARATE from partner verification
  /// Called AFTER partner submits a vehicle for approval
  Future<List<Map<String, dynamic>>> getAllPendingVehicleDocuments() async {
    try {
      debugPrint('Fetching all pending vehicle documents');

      final response = await supabase
          .from('vehicle_documents')
          .select(
            '*, partner_vehicle_applications(id, partner_id, vehicle_info), users(full_name, email)',
          )
          .eq('status', 'pending')
          .order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching vehicle documents: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching vehicle documents: $e');
      return [];
    }
  }

  /// Verify individual vehicle document (OR/CR, etc)
  Future<Map<String, dynamic>> verifyVehicleDocument({
    required String documentId,
    String? adminNotes,
  }) async {
    try {
      debugPrint('Verifying vehicle document: $documentId');

      await supabase
          .from('vehicle_documents')
          .update({
            'status': 'verified',
            'verified_at': DateTime.now().toIso8601String(),
            if (adminNotes != null) 'admin_notes': adminNotes,
          })
          .eq('id', documentId);

      debugPrint('Vehicle document verified successfully');
      return {'success': true, 'message': 'Document verified'};
    } on PostgrestException catch (e) {
      debugPrint('Database error verifying document: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('Error verifying document: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Reject vehicle document
  Future<Map<String, dynamic>> rejectVehicleDocument({
    required String documentId,
    required String reason,
  }) async {
    try {
      debugPrint('Rejecting vehicle document: $documentId');

      await supabase
          .from('vehicle_documents')
          .update({'status': 'rejected', 'admin_notes': reason})
          .eq('id', documentId);

      debugPrint('Vehicle document rejected successfully');
      return {'success': true, 'message': 'Document rejected'};
    } on PostgrestException catch (e) {
      debugPrint('Database error rejecting document: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('Error rejecting document: $e');
      return {'success': false, 'error': e.toString()};
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
