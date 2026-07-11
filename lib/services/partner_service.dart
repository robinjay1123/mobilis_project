import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'notification_service.dart';
import 'user_restriction_service.dart';
import 'admin_service.dart';

class PartnerService {
  static final PartnerService _instance = PartnerService._internal();

  factory PartnerService() {
    return _instance;
  }

  PartnerService._internal();

  final supabase = Supabase.instance.client;

  // Get partner profile by user ID
  Future<Map<String, dynamic>?> getPartnerProfile(String userId) async {
    try {
      debugPrint('Fetching partner profile for user: $userId');

      final response = await supabase
          .from('partners')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint('Partner profile fetched: ${response != null}');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching partner: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching partner: $e');
      rethrow;
    }
  }

  // Create partner profile
  Future<Map<String, dynamic>> createPartnerProfile({
    required String userId,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    try {
      debugPrint('Creating partner profile for user: $userId');

      final response = await supabase
          .from('partners')
          .insert({
            'user_id': userId,
            'business_name': businessName,
            'business_address': businessAddress,
            'business_phone': businessPhone,
            'verification_status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint('Partner profile created successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error creating partner: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error creating partner: $e');
      rethrow;
    }
  }

  // Update partner profile
  Future<void> updatePartnerProfile(
    String partnerId,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('Updating partner profile: $partnerId');

      await supabase.from('partners').update(data).eq('id', partnerId);

      debugPrint('Partner profile updated successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating partner: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating partner: $e');
      rethrow;
    }
  }

  // Get vehicle applications for partner
  Future<List<Map<String, dynamic>>> getVehicleApplications(
    String partnerId,
  ) async {
    try {
      debugPrint('Fetching vehicle applications for partner: $partnerId');

      final response = await supabase
          .from('partner_vehicle_applications')
          .select()
          .eq('partner_id', partnerId)
          .order('created_at', ascending: false);

      debugPrint('Fetched ${response.length} vehicle applications');
      final applications = List<Map<String, dynamic>>.from(
        response.map((app) {
          final map = Map<String, dynamic>.from(app);
          map['status'] = map['application_status'] ?? map['status'];
          return map;
        }),
      );

      final partnerVehicleIds = applications
          .map((app) => app['partner_vehicle_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final partnerVehiclesById = <String, Map<String, dynamic>>{};
      if (partnerVehicleIds.isNotEmpty) {
        final partnerVehicles = await supabase
            .from('partner_vehicles')
            .select('id,vehicle_id,is_available,status')
            .inFilter('id', partnerVehicleIds);
        for (final vehicle in List<Map<String, dynamic>>.from(
          partnerVehicles,
        )) {
          partnerVehiclesById[vehicle['id'].toString()] = vehicle;
        }
      }

      final canonicalVehicleIds = applications
          .map((app) => app['created_vehicle_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      for (final vehicle in partnerVehiclesById.values) {
        final id = vehicle['vehicle_id']?.toString();
        if (id != null && id.isNotEmpty) canonicalVehicleIds.add(id);
      }

      final vehiclesById = <String, Map<String, dynamic>>{};
      if (canonicalVehicleIds.isNotEmpty) {
        final vehicles = await supabase
            .from('vehicles')
            .select('id,is_posted,is_available,status')
            .inFilter('id', canonicalVehicleIds.toList());
        for (final vehicle in List<Map<String, dynamic>>.from(vehicles)) {
          vehiclesById[vehicle['id'].toString()] = vehicle;
        }
      }

      for (final application in applications) {
        final partnerVehicle =
            partnerVehiclesById[application['partner_vehicle_id']?.toString()];
        final canonicalId =
            application['created_vehicle_id']?.toString() ??
            partnerVehicle?['vehicle_id']?.toString();
        final vehicle = vehiclesById[canonicalId];
        application['vehicle_status'] =
            vehicle?['status'] ?? partnerVehicle?['status'];
        application['is_available'] =
            vehicle?['is_available'] ??
            partnerVehicle?['is_available'] ??
            false;
        application['is_posted'] = vehicle?['is_posted'] ?? false;
        application['created_vehicle_id'] ??= canonicalId;
      }

      return applications;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching applications: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching applications: $e');
      rethrow;
    }
  }

  // Get vehicle applications by status
  Future<List<Map<String, dynamic>>> getVehicleApplicationsByStatus(
    String partnerId,
    String status,
  ) async {
    try {
      debugPrint('Fetching $status applications for partner: $partnerId');
      final applications = await getVehicleApplications(partnerId);
      final expectedStatus = status.trim().toLowerCase();
      return applications.where((application) {
        final currentStatus =
            (application['application_status'] ?? application['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
        return currentStatus == expectedStatus;
      }).toList();
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching applications: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching applications: $e');
      rethrow;
    }
  }

  // Submit vehicle application
  Future<Map<String, dynamic>> submitVehicleApplication({
    required String partnerId,
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
    required int seats,
    required double pricePerDay,
    required double pricePerHour,
    required String orDocumentUrl,
    required String crDocumentUrl,
    String fuelType = 'Gasoline',
    String transmission = 'Manual',
    String? vehiclePhotoUrl,
    bool ownerIsDriver = false,
  }) async {
    try {
      debugPrint('Submitting vehicle application for partner: $partnerId');

      final response = await supabase
          .from('partner_vehicle_applications')
          .insert({
            'partner_id': partnerId,
            'brand': brand,
            'model': model,
            'year': year,
            'plate_number': plateNumber,
            'seats': seats,
            'fuel_type': fuelType,
            'transmission': transmission,
            'price_per_day': pricePerDay,
            'price_per_hour': pricePerHour,
            'or_document_url': orDocumentUrl,
            'cr_document_url': crDocumentUrl,
            if (vehiclePhotoUrl != null && vehiclePhotoUrl.isNotEmpty)
              'vehicle_photo_url': vehiclePhotoUrl,
            'owner_is_driver': ownerIsDriver,
            'is_available': false,
            'application_status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint('Vehicle application submitted successfully');
      return response;
    } on PostgrestException catch (e) {
      debugPrint('Database error submitting application: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error submitting application: $e');
      rethrow;
    }
  }

  Future<void> updateApprovedVehicleSettings({
    required String applicationId,
    required String partnerVehicleId,
    String? vehicleId,
    required bool ownerIsDriver,
    required bool isAvailable,
  }) async {
    try {
      if (isAvailable) {
        final restriction = await UserRestrictionService()
            .getCurrentUserRestriction();
        if (restriction.isBlocked || restriction.isAccountRestricted) {
          throw Exception(
            'Restricted partner accounts cannot relist vehicles right now',
          );
        }
      }

      final updates = {
        'owner_is_driver': ownerIsDriver,
        'is_available': isAvailable,
        'updated_at': DateTime.now().toIso8601String(),
      };

      String? partnerId;
      if (ownerIsDriver) {
        final application = await supabase
            .from('partner_vehicle_applications')
            .select('partner_id')
            .eq('id', applicationId)
            .maybeSingle();
        partnerId = application?['partner_id']?.toString();

        if (partnerId != null && partnerId.isNotEmpty) {
          await supabase
              .from('partner_vehicle_applications')
              .update({
                'owner_is_driver': false,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('partner_id', partnerId)
              .eq('application_status', 'approved')
              .neq('id', applicationId);

          await supabase
              .from('partner_vehicles')
              .update({
                'owner_is_driver': false,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('partner_id', partnerId)
              .neq('id', partnerVehicleId);

          var vehicleQuery = supabase
              .from('vehicles')
              .update({'owner_is_driver': false})
              .eq('owner_id', partnerId);
          if (vehicleId != null && vehicleId.isNotEmpty) {
            vehicleQuery = vehicleQuery.neq('id', vehicleId);
          }
          await vehicleQuery;
        }
      }

      await supabase
          .from('partner_vehicle_applications')
          .update(updates)
          .eq('id', applicationId);

      await supabase
          .from('partner_vehicles')
          .update({
            'owner_is_driver': ownerIsDriver,
            'is_available': isAvailable,
            'status': isAvailable ? 'available' : 'disabled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', partnerVehicleId);

      if (vehicleId != null && vehicleId.isNotEmpty) {
        await supabase
            .from('vehicles')
            .update({
              'owner_is_driver': ownerIsDriver,
              'is_available': isAvailable,
              'status': isAvailable ? 'available' : 'inactive',
            })
            .eq('id', vehicleId);
      }
    } on PostgrestException catch (e) {
      debugPrint('Database error updating vehicle settings: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating vehicle settings: $e');
      rethrow;
    }
  }

  Future<void> updateApprovedVehicleDetails({
    required String applicationId,
    required String partnerVehicleId,
    String? vehicleId,
    required String brand,
    required String model,
    required int year,
    required String plateNumber,
    required int seats,
    required String fuelType,
    required String transmission,
    List<String>? photoUrls,
  }) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      final updates = {
        'brand': brand,
        'model': model,
        'year': year,
        'plate_number': plateNumber,
        'seats': seats,
        'fuel_type': fuelType,
        'transmission': transmission,
        'application_status': 'pending',
        'status': 'pending',
        'is_available': false,
        if (photoUrls != null)
          'vehicle_photo_url': photoUrls.isEmpty ? null : photoUrls.first,
        'updated_at': nowIso,
      };

      await supabase
          .from('partner_vehicle_applications')
          .update(updates)
          .eq('id', applicationId);

      await supabase
          .from('partner_vehicles')
          .update({
            'brand': brand,
            'model': model,
            'year': year,
            'plate_number': plateNumber,
            'seats': seats,
            'fuel_type': fuelType,
            'transmission': transmission,
            'status': 'pending',
            'is_available': false,
            'updated_at': nowIso,
          })
          .eq('id', partnerVehicleId);

      if (vehicleId != null && vehicleId.isNotEmpty) {
        await supabase
            .from('vehicles')
            .update({
              'brand': brand,
              'model': model,
              'year': year,
              'plate_number': plateNumber,
              'seats': seats,
              'fuel_type': fuelType,
              'transmission': transmission,
              'status': 'inactive',
              'is_available': false,
              'updated_at': nowIso,
            })
            .eq('id', vehicleId);
      }

      if (photoUrls != null) {
        await supabase
            .from('partner_vehicle_documents')
            .delete()
            .eq('partner_vehicle_application_id', applicationId)
            .eq('document_type', 'vehicle_photo');

        final cleanUrls = photoUrls
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .toList();

        if (cleanUrls.isNotEmpty) {
          await supabase
              .from('partner_vehicle_documents')
              .insert(
                List.generate(cleanUrls.length, (index) {
                  return {
                    'partner_vehicle_application_id': applicationId,
                    'document_type': 'vehicle_photo',
                    'file_url': cleanUrls[index],
                    'created_at': nowIso,
                  };
                }),
              );
        }

        await supabase
            .from('vehicle_images')
            .delete()
            .eq('partner_vehicle_id', partnerVehicleId);

        if (vehicleId != null && vehicleId.isNotEmpty) {
          await supabase
              .from('vehicle_images')
              .delete()
              .eq('vehicle_id', vehicleId);
        }

        if (cleanUrls.isNotEmpty) {
          await supabase
              .from('vehicle_images')
              .insert(
                List.generate(cleanUrls.length, (index) {
                  return {
                    'partner_vehicle_id': partnerVehicleId,
                    'image_url': cleanUrls[index],
                    'display_order': index,
                  };
                }),
              );
        }
      }
    } on PostgrestException catch (e) {
      debugPrint('Database error updating vehicle details: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating vehicle details: $e');
      rethrow;
    }
  }

  Future<int> requestVehiclePriceChange({
    required String partnerId,
    required String applicationId,
    required String partnerVehicleId,
    String? vehicleId,
    required String vehicleTitle,
    required double currentPricePerDay,
    required double currentPricePerHour,
    required double requestedPricePerDay,
    required double requestedPricePerHour,
    String? note,
  }) async {
    final admins = await supabase
        .from('users')
        .select('id')
        .eq('role', 'admin');

    final adminIds = List<Map<String, dynamic>>.from(admins)
        .map((row) => row['id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (adminIds.isEmpty) {
      throw Exception('No admin account is available to receive this request');
    }

    for (final adminId in adminIds) {
      await NotificationService().createNotification(
        userId: adminId,
        title: 'Partner Price Change Request',
        message:
            '$vehicleTitle needs admin review before an operator updates the price.',
        type: 'price_change_request',
        data: {
          'event': 'partner_price_change_request',
          'partner_id': partnerId,
          'application_id': applicationId,
          'partner_vehicle_id': partnerVehicleId,
          if (vehicleId != null && vehicleId.isNotEmpty)
            'vehicle_id': vehicleId,
          'vehicle_title': vehicleTitle,
          'current_price_per_day': currentPricePerDay,
          'current_price_per_hour': currentPricePerHour,
          'requested_price_per_day': requestedPricePerDay,
          'requested_price_per_hour': requestedPricePerHour,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          'forwarded_to_operator': false,
        },
      );
    }

    return adminIds.length;
  }

  Future<void> notifyPaymentReleased({
    required String partnerId,
    required double amount,
    String? bookingId,
    String? payoutId,
    String? reference,
  }) async {
    await NotificationService().notifyPartnerPaymentReleased(
      partnerId: partnerId,
      amount: amount,
      bookingId: bookingId,
      payoutId: payoutId,
      reference: reference,
    );
  }

  Future<void> addVehicleApplicationPhotos({
    required String applicationId,
    required List<String> photoUrls,
  }) async {
    final records = photoUrls
        .where((url) => url.trim().isNotEmpty)
        .map(
          (url) => {
            'partner_vehicle_application_id': applicationId,
            'document_type': 'vehicle_photo',
            'file_url': url.trim(),
            'created_at': DateTime.now().toIso8601String(),
          },
        )
        .toList();

    if (records.isEmpty) return;
    await supabase.from('partner_vehicle_documents').insert(records);
  }

  /// Upload partner document file to `partner_documents` bucket.
  Future<String> uploadToPartnerDocumentsBucket({
    required String partnerId,
    required File file,
    required String documentType,
  }) async {
    final bytes = await file.readAsBytes();
    final extension = file.path.contains('.')
        ? file.path.split('.').last.toLowerCase()
        : 'jpg';
    final objectPath =
        '$partnerId/${documentType}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await supabase.storage
        .from('partner_documents')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from('partner_documents').getPublicUrl(objectPath);
  }

  // Check if partner has pending application
  Future<bool> hasPendingApplication(String partnerId) async {
    try {
      debugPrint('Checking pending applications for partner: $partnerId');

      final response = await supabase
          .from('partner_vehicle_applications')
          .select('id')
          .eq('partner_id', partnerId)
          .eq('application_status', 'pending')
          .limit(1);

      final hasPending = response.isNotEmpty;
      debugPrint('Partner has pending application: $hasPending');
      return hasPending;
    } on PostgrestException catch (e) {
      debugPrint('Database error checking pending: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error checking pending: $e');
      rethrow;
    }
  }

  // Get partner verification status
  Future<String?> getVerificationStatus(String userId) async {
    try {
      final profile = await getPartnerProfile(userId);
      return profile?['verification_status'] as String?;
    } catch (e) {
      debugPrint('Error getting verification status: $e');
      return null;
    }
  }

  // Get application counts by status
  Future<Map<String, int>> getApplicationCounts(String partnerId) async {
    try {
      debugPrint('Fetching application counts for partner: $partnerId');

      final applications = await getVehicleApplications(partnerId);

      final counts = {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total': applications.length,
      };

      for (final app in applications) {
        final status = app['application_status'] as String?;
        if (status != null && counts.containsKey(status)) {
          counts[status] = counts[status]! + 1;
        }
      }

      debugPrint('Application counts: $counts');
      return counts;
    } catch (e) {
      debugPrint('Error getting application counts: $e');
      return {'pending': 0, 'approved': 0, 'rejected': 0, 'total': 0};
    }
  }

  // ================== APPLICATION APPROVAL (ADMIN) ==================

  /// Approve vehicle application (called by admin)
  Future<void> approveVehicleApplication(
    String applicationId,
    String notes,
  ) async {
    await AdminService().approveVehicleApplication(applicationId, notes);
  }

  /// Reject vehicle application (called by admin)
  Future<void> rejectVehicleApplication(
    String applicationId,
    String reason,
  ) async {
    await AdminService().rejectVehicleApplication(applicationId, reason);
  }

  // ================== VEHICLE EXPIRY VALIDATION ==================

  /// Validate vehicle documents (check expiry dates)
  Future<Map<String, dynamic>> validateVehicleDocuments(
    String vehicleId,
  ) async {
    try {
      debugPrint('Validating documents for vehicle: $vehicleId');

      final docs = await supabase
          .from('vehicle_documents')
          .select('*')
          .eq('vehicle_id', vehicleId);

      final now = DateTime.now();

      Map<String, dynamic> validation = {
        'valid': true,
        'expiring_soon': [],
        'expired': [],
        'missing_required': [],
      };

      // Check each document
      for (var doc in docs) {
        final expiryDate = doc['expiry_date'] as String?;
        final docType = doc['document_type'] as String?;

        if (expiryDate != null) {
          final expiry = DateTime.parse(expiryDate);
          final daysUntilExpiry = expiry.difference(now).inDays;

          if (daysUntilExpiry < 0) {
            validation['expired'].add({
              'type': docType,
              'expiry_date': expiryDate,
              'days_overdue': daysUntilExpiry.abs(),
            });
            validation['valid'] = false;
          } else if (daysUntilExpiry < 90) {
            validation['expiring_soon'].add({
              'type': docType,
              'expiry_date': expiryDate,
              'days_remaining': daysUntilExpiry,
            });
          }
        }
      }

      // Check for required documents
      final requiredDocs = ['insurance', 'registration'];
      final uploadedTypes = docs.map((d) => d['document_type']).toSet();

      for (var required in requiredDocs) {
        if (!uploadedTypes.contains(required)) {
          validation['missing_required'].add(required);
          validation['valid'] = false;
        }
      }

      return validation;
    } catch (e) {
      debugPrint('Error validating vehicle documents: $e');
      return {'valid': false, 'error': e.toString()};
    }
  }

  /// Get expiring vehicle documents
  Future<List<Map<String, dynamic>>> getExpiringVehicleDocuments(
    String vehicleId, {
    int daysThreshold = 90,
  }) async {
    try {
      final docs = await supabase
          .from('vehicle_documents')
          .select('*')
          .eq('vehicle_id', vehicleId);

      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      final expiringDocs = (docs as List).where((doc) {
        final expiryDate = doc['expiry_date'] as String?;
        if (expiryDate == null) return false;

        final expiry = DateTime.parse(expiryDate);
        return expiry.isBefore(thresholdDate) && expiry.isAfter(now);
      }).toList();

      return List<Map<String, dynamic>>.from(expiringDocs);
    } catch (e) {
      debugPrint('Error getting expiring documents: $e');
      return [];
    }
  }

  // ================== SEARCH & FILTER ==================

  /// Filter vehicle applications by criteria
  Future<List<Map<String, dynamic>>> filterVehicleApplications(
    String partnerId, {
    String? status,
    DateTime? afterDate,
    DateTime? beforeDate,
  }) async {
    try {
      debugPrint('Filtering vehicle applications for partner: $partnerId');

      var query = supabase
          .from('partner_vehicle_applications')
          .select('*')
          .eq('partner_id', partnerId);

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

  /// Search partner bookings with filters
  Future<List<Map<String, dynamic>>> searchPartnerBookings(
    String partnerId, {
    String? status,
    DateTime? afterDate,
    DateTime? beforeDate,
  }) async {
    try {
      debugPrint('Searching bookings for partner: $partnerId');

      // Get partner's vehicles
      final vehicles = await supabase
          .from('vehicles')
          .select('id')
          .eq('owner_id', partnerId);

      if (vehicles.isEmpty) return [];

      final vehicleIds = vehicles.map((v) => v['id']).cast<String>().toList();

      var query = supabase
          .from('bookings')
          .select(
            'id, renter_id, vehicle_id, start_date, end_date, status, total_price, created_at, vehicles(brand, model), users:users!bookings_renter_id_fkey(full_name, email)',
          )
          .inFilter('vehicle_id', vehicleIds);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (afterDate != null) {
        query = query.gte('start_date', afterDate.toIso8601String());
      }

      if (beforeDate != null) {
        query = query.lte('end_date', beforeDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('Database error searching bookings: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error searching bookings: $e');
      return [];
    }
  }

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
