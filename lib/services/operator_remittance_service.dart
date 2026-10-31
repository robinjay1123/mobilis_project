import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audit_service.dart';

class OperatorRemittanceModel {
  final String id;
  final String bookingId;
  final String bookingReference;
  final String operatorId;
  final String operatorName;
  final String vehicleName;
  final double rentalGrossAmount;
  final double commissionRate;
  final double commissionAmount;
  final String remittanceType; // 'cash' or 'digital'
  final String proofImageUrl;
  final String referenceNumber;
  final String operatorNotes;
  final String status; // 'pending_review', 'remitted', 'rejected'
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OperatorRemittanceModel({
    required this.id,
    required this.bookingId,
    required this.bookingReference,
    required this.operatorId,
    this.operatorName = '',
    this.vehicleName = '',
    this.rentalGrossAmount = 0.0,
    this.commissionRate = 5.0,
    required this.commissionAmount,
    this.remittanceType = 'digital',
    required this.proofImageUrl,
    this.referenceNumber = '',
    this.operatorNotes = '',
    this.status = 'pending_review',
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPendingReview => status == 'pending_review';
  bool get isRemitted => status == 'remitted';
  bool get isRejected => status == 'rejected';

  String get formattedType =>
      remittanceType == 'cash' ? 'Cash Handover' : 'Digital Transfer';

  String get formattedStatus {
    switch (status) {
      case 'remitted':
        return 'Remitted & Confirmed';
      case 'pending_review':
        return 'Under Admin Review';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending Remittance';
    }
  }

  factory OperatorRemittanceModel.fromJson(Map<String, dynamic> json) {
    return OperatorRemittanceModel(
      id: json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
      bookingReference: json['booking_reference']?.toString() ?? '',
      operatorId: json['operator_id']?.toString() ?? '',
      operatorName: json['operator_name']?.toString() ?? '',
      vehicleName: json['vehicle_name']?.toString() ?? '',
      rentalGrossAmount: (json['rental_gross_amount'] as num?)?.toDouble() ?? 0.0,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 5.0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0.0,
      remittanceType: json['remittance_type']?.toString() ?? 'digital',
      proofImageUrl: json['proof_image_url']?.toString() ?? '',
      referenceNumber: json['reference_number']?.toString() ?? '',
      operatorNotes: json['operator_notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending_review',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? '') ?? DateTime.now(),
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
      reviewedBy: json['reviewed_by']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'booking_id': bookingId,
      'booking_reference': bookingReference,
      'operator_id': operatorId,
      'operator_name': operatorName,
      'vehicle_name': vehicleName,
      'rental_gross_amount': rentalGrossAmount,
      'commission_rate': commissionRate,
      'commission_amount': commissionAmount,
      'remittance_type': remittanceType,
      'proof_image_url': proofImageUrl,
      'reference_number': referenceNumber,
      'operator_notes': operatorNotes,
      'status': status,
      'submitted_at': submittedAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (includeId && id.isNotEmpty) map['id'] = id;
    if (reviewedAt != null) map['reviewed_at'] = reviewedAt!.toUtc().toIso8601String();
    if (reviewedBy != null) map['reviewed_by'] = reviewedBy;
    if (rejectionReason != null) map['rejection_reason'] = rejectionReason;
    if (adminNotes != null) map['admin_notes'] = adminNotes;
    return map;
  }

  OperatorRemittanceModel copyWith({
    String? id,
    String? bookingId,
    String? bookingReference,
    String? operatorId,
    String? operatorName,
    String? vehicleName,
    double? rentalGrossAmount,
    double? commissionRate,
    double? commissionAmount,
    String? remittanceType,
    String? proofImageUrl,
    String? referenceNumber,
    String? operatorNotes,
    String? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OperatorRemittanceModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      bookingReference: bookingReference ?? this.bookingReference,
      operatorId: operatorId ?? this.operatorId,
      operatorName: operatorName ?? this.operatorName,
      vehicleName: vehicleName ?? this.vehicleName,
      rentalGrossAmount: rentalGrossAmount ?? this.rentalGrossAmount,
      commissionRate: commissionRate ?? this.commissionRate,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      remittanceType: remittanceType ?? this.remittanceType,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      operatorNotes: operatorNotes ?? this.operatorNotes,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class OperatorRemittanceService {
  OperatorRemittanceService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetch remittances with optional operatorId and status filters
  Future<List<OperatorRemittanceModel>> getRemittances({
    String? operatorId,
    String? status,
  }) async {
    try {
      var query = _client.from('operator_remittances').select();

      if (operatorId != null && operatorId.isNotEmpty) {
        query = query.eq('operator_id', operatorId);
      }
      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final rows = await query.order('submitted_at', ascending: false);
      return (rows as List)
          .map((r) => OperatorRemittanceModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('OperatorRemittanceService: Error loading remittances: $e');
      return [];
    }
  }

  /// Get remittance record for a specific booking
  Future<OperatorRemittanceModel?> getRemittanceForBooking(String bookingId) async {
    try {
      final row = await _client
          .from('operator_remittances')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (row == null) return null;
      return OperatorRemittanceModel.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('OperatorRemittanceService: Error getting remittance for booking $bookingId: $e');
      return null;
    }
  }

  /// Upload proof photo (cash money photo or digital transfer receipt)
  Future<String> uploadRemittanceProof({
    required Uint8List bytes,
    required String fileName,
    required String bookingId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanExtension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final path = 'remittances/booking_${bookingId}_$timestamp.$cleanExtension';

    await _client.storage.from('booking_evidence').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: cleanExtension == 'png' ? 'image/png' : 'image/jpeg',
        upsert: true,
      ),
    );

    return _client.storage.from('booking_evidence').getPublicUrl(path);
  }

  /// Operator submits remittance request with proof
  Future<OperatorRemittanceModel> submitRemittance({
    required String bookingId,
    required String bookingReference,
    required String operatorId,
    required String operatorName,
    required String vehicleName,
    required double rentalGrossAmount,
    double commissionRate = 5.0,
    required double commissionAmount,
    required String remittanceType, // 'cash' or 'digital'
    required String proofImageUrl,
    String referenceNumber = '',
    String operatorNotes = '',
  }) async {
    final now = DateTime.now();
    final data = {
      'booking_id': bookingId,
      'booking_reference': bookingReference,
      'operator_id': operatorId,
      'operator_name': operatorName,
      'vehicle_name': vehicleName,
      'rental_gross_amount': rentalGrossAmount,
      'commission_rate': commissionRate,
      'commission_amount': commissionAmount,
      'remittance_type': remittanceType,
      'proof_image_url': proofImageUrl,
      'reference_number': referenceNumber,
      'operator_notes': operatorNotes,
      'status': 'pending_review',
      'submitted_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
    };

    final response = await _client
        .from('operator_remittances')
        .upsert(data, onConflict: 'booking_id')
        .select()
        .single();

    // Also update booking status
    try {
      await _client.from('bookings').update({
        'operator_remittance_status': 'pending_review',
      }).eq('id', bookingId);
    } catch (e) {
      debugPrint('OperatorRemittanceService: Could not update bookings column: $e');
    }

    final remittance = OperatorRemittanceModel.fromJson(Map<String, dynamic>.from(response));

    await AuditService().logAudit(
      action: 'operator_remittance_submitted',
      category: 'remittances',
      entityId: bookingId,
      entityType: 'remittance',
      notes: 'Operator $operatorName submitted remittance of ₱$commissionAmount for Booking #$bookingReference ($remittanceType)',
    );

    return remittance;
  }

  /// Admin approves remittance
  Future<OperatorRemittanceModel> approveRemittance({
    required String remittanceId,
    required String bookingId,
    String? adminId,
    String? adminNotes,
  }) async {
    final now = DateTime.now();
    final data = {
      'status': 'remitted',
      'reviewed_at': now.toUtc().toIso8601String(),
      'reviewed_by': adminId,
      'admin_notes': adminNotes ?? '',
      'updated_at': now.toUtc().toIso8601String(),
    };

    final response = await _client
        .from('operator_remittances')
        .update(data)
        .eq('id', remittanceId)
        .select()
        .single();

    try {
      await _client.from('bookings').update({
        'operator_remittance_status': 'remitted',
        'operator_remitted_at': now.toUtc().toIso8601String(),
      }).eq('id', bookingId);
    } catch (e) {
      debugPrint('OperatorRemittanceService: Could not update booking remittance status: $e');
    }

    final model = OperatorRemittanceModel.fromJson(Map<String, dynamic>.from(response));

    // Send in-app notification to operator
    try {
      await _client.from('notifications').insert({
        'user_id': model.operatorId,
        'title': 'Platform Remittance Confirmed',
        'message': 'Your platform commission remittance for Booking #${model.bookingReference} (₱${model.commissionAmount.toStringAsFixed(2)}) has been approved and confirmed by Admin.',
        'type': 'remittance_confirmed',
        'created_at': now.toUtc().toIso8601String(),
        'read': false,
      });
    } catch (e) {
      debugPrint('OperatorRemittanceService: Notice: Could not send operator notification: $e');
    }

    await AuditService().logAudit(
      action: 'operator_remittance_approved',
      category: 'remittances',
      entityId: remittanceId,
      entityType: 'remittance',
      notes: 'Admin approved remittance of ₱${model.commissionAmount} for Booking #${model.bookingReference}',
    );

    return model;
  }

  /// Admin rejects remittance proof
  Future<OperatorRemittanceModel> rejectRemittance({
    required String remittanceId,
    required String bookingId,
    required String reason,
    String? adminId,
  }) async {
    final now = DateTime.now();
    final data = {
      'status': 'rejected',
      'rejection_reason': reason,
      'reviewed_at': now.toUtc().toIso8601String(),
      'reviewed_by': adminId,
      'updated_at': now.toUtc().toIso8601String(),
    };

    final response = await _client
        .from('operator_remittances')
        .update(data)
        .eq('id', remittanceId)
        .select()
        .single();

    try {
      await _client.from('bookings').update({
        'operator_remittance_status': 'rejected',
      }).eq('id', bookingId);
    } catch (e) {
      debugPrint('OperatorRemittanceService: Could not update booking remittance status: $e');
    }

    final model = OperatorRemittanceModel.fromJson(Map<String, dynamic>.from(response));

    // Send in-app notification to operator
    try {
      await _client.from('notifications').insert({
        'user_id': model.operatorId,
        'title': 'Remittance Proof Rejected',
        'message': 'Remittance proof for Booking #${model.bookingReference} was rejected by Admin. Reason: $reason. Please re-upload valid proof.',
        'type': 'remittance_rejected',
        'created_at': now.toUtc().toIso8601String(),
        'read': false,
      });
    } catch (e) {
      debugPrint('OperatorRemittanceService: Notice: Could not send operator notification: $e');
    }

    await AuditService().logAudit(
      action: 'operator_remittance_rejected',
      category: 'remittances',
      entityId: remittanceId,
      entityType: 'remittance',
      notes: 'Admin rejected remittance for Booking #${model.bookingReference}. Reason: $reason',
    );

    return model;
  }

  /// Admin manually marks cash remittance as remitted (in-office handover)
  Future<OperatorRemittanceModel> manualMarkRemitted({
    required String bookingId,
    required String bookingReference,
    required String operatorId,
    required String operatorName,
    required String vehicleName,
    required double rentalGrossAmount,
    required double commissionAmount,
    required String adminId,
    String notes = 'Cash received directly by Admin in office.',
  }) async {
    final now = DateTime.now();
    final data = {
      'booking_id': bookingId,
      'booking_reference': bookingReference,
      'operator_id': operatorId,
      'operator_name': operatorName,
      'vehicle_name': vehicleName,
      'rental_gross_amount': rentalGrossAmount,
      'commission_rate': 5.0,
      'commission_amount': commissionAmount,
      'remittance_type': 'cash',
      'proof_image_url': 'in_office_manual',
      'reference_number': 'OFFICE-CASH',
      'operator_notes': notes,
      'status': 'remitted',
      'submitted_at': now.toUtc().toIso8601String(),
      'reviewed_at': now.toUtc().toIso8601String(),
      'reviewed_by': adminId,
      'admin_notes': notes,
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
    };

    final response = await _client
        .from('operator_remittances')
        .upsert(data, onConflict: 'booking_id')
        .select()
        .single();

    try {
      await _client.from('bookings').update({
        'operator_remittance_status': 'remitted',
        'operator_remitted_at': now.toUtc().toIso8601String(),
      }).eq('id', bookingId);
    } catch (e) {
      debugPrint('OperatorRemittanceService: Could not update booking status: $e');
    }

    return OperatorRemittanceModel.fromJson(Map<String, dynamic>.from(response));
  }
}

