import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supported payment types in Mobilis
enum PaymentType {
  reservation,
  fullPayment,
  balance,
  deskPayment,
  tripExtension,
  securityDeposit,
  returnSettlement,
  lateFee,
  damageFee,
  refund,
  other;

  static PaymentType fromString(String? val) {
    if (val == null) return PaymentType.other;
    switch (val.toLowerCase().trim()) {
      case 'reservation':
        return PaymentType.reservation;
      case 'full_payment':
      case 'fullpayment':
        return PaymentType.fullPayment;
      case 'balance':
        return PaymentType.balance;
      case 'desk_payment':
      case 'deskpayment':
        return PaymentType.deskPayment;
      case 'trip_extension':
      case 'extension':
        return PaymentType.tripExtension;
      case 'security_deposit':
        return PaymentType.securityDeposit;
      case 'return_settlement':
        return PaymentType.returnSettlement;
      case 'late_fee':
        return PaymentType.lateFee;
      case 'damage_fee':
        return PaymentType.damageFee;
      case 'refund':
        return PaymentType.refund;
      default:
        return PaymentType.other;
    }
  }

  String toDbString() {
    switch (this) {
      case PaymentType.reservation:
        return 'reservation';
      case PaymentType.fullPayment:
        return 'full_payment';
      case PaymentType.balance:
        return 'balance';
      case PaymentType.deskPayment:
        return 'desk_payment';
      case PaymentType.tripExtension:
        return 'trip_extension';
      case PaymentType.securityDeposit:
        return 'security_deposit';
      case PaymentType.returnSettlement:
        return 'return_settlement';
      case PaymentType.lateFee:
        return 'late_fee';
      case PaymentType.damageFee:
        return 'damage_fee';
      case PaymentType.refund:
        return 'refund';
      case PaymentType.other:
        return 'other';
    }
  }
}

/// Supported payment statuses
enum PaymentRecordStatus {
  pending,
  pendingReview,
  verified,
  approved,
  paid,
  rejected,
  refunded,
  voided,
  failed;

  static PaymentRecordStatus fromString(String? val) {
    if (val == null) return PaymentRecordStatus.pending;
    switch (val.toLowerCase().trim()) {
      case 'pending':
        return PaymentRecordStatus.pending;
      case 'pending_review':
      case 'pendingreview':
      case 'submitted':
        return PaymentRecordStatus.pendingReview;
      case 'verified':
        return PaymentRecordStatus.verified;
      case 'approved':
        return PaymentRecordStatus.approved;
      case 'paid':
        return PaymentRecordStatus.paid;
      case 'rejected':
      case 'forfeited':
        return PaymentRecordStatus.rejected;
      case 'refunded':
        return PaymentRecordStatus.refunded;
      case 'voided':
        return PaymentRecordStatus.voided;
      case 'failed':
        return PaymentRecordStatus.failed;
      default:
        return PaymentRecordStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case PaymentRecordStatus.pending:
        return 'pending';
      case PaymentRecordStatus.pendingReview:
        return 'pending_review';
      case PaymentRecordStatus.verified:
        return 'verified';
      case PaymentRecordStatus.approved:
        return 'approved';
      case PaymentRecordStatus.paid:
        return 'paid';
      case PaymentRecordStatus.rejected:
        return 'rejected';
      case PaymentRecordStatus.refunded:
        return 'refunded';
      case PaymentRecordStatus.voided:
        return 'voided';
      case PaymentRecordStatus.failed:
        return 'failed';
    }
  }

  bool get isSettled =>
      this == PaymentRecordStatus.verified ||
      this == PaymentRecordStatus.approved ||
      this == PaymentRecordStatus.paid;
}

/// Represents an individual payment transaction
class PaymentRecord {
  final String id;
  final String bookingId;
  final String? payerUserId;
  final PaymentType paymentType;
  final double amount;
  final String paymentMethod;
  final String? referenceNumber;
  final String? senderPhone;
  final String? proofUrl;
  final String? proofStoragePath;
  final PaymentRecordStatus status;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final String? rejectionReason;
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentRecord({
    required this.id,
    required this.bookingId,
    this.payerUserId,
    required this.paymentType,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    this.senderPhone,
    this.proofUrl,
    this.proofStoragePath,
    required this.status,
    this.verifiedAt,
    this.verifiedBy,
    this.rejectionReason,
    this.notes,
    this.metadata = const {},
    required this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
      payerUserId: json['payer_user_id']?.toString(),
      paymentType: PaymentType.fromString(json['payment_type']?.toString()),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'gcash',
      referenceNumber: json['reference_number']?.toString(),
      senderPhone: json['sender_phone']?.toString(),
      proofUrl: json['proof_url']?.toString(),
      proofStoragePath: json['proof_storage_path']?.toString(),
      status: PaymentRecordStatus.fromString(json['status']?.toString()),
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'].toString())?.toLocal()
          : null,
      verifiedBy: json['verified_by']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      notes: json['notes']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'])
          : {},
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      if (payerUserId != null) 'payer_user_id': payerUserId,
      'payment_type': paymentType.toDbString(),
      'amount': amount,
      'payment_method': paymentMethod,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (senderPhone != null) 'sender_phone': senderPhone,
      if (proofUrl != null) 'proof_url': proofUrl,
      if (proofStoragePath != null) 'proof_storage_path': proofStoragePath,
      'status': status.toDbString(),
      if (verifiedAt != null) 'verified_at': verifiedAt!.toIso8601String(),
      if (verifiedBy != null) 'verified_by': verifiedBy,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (notes != null) 'notes': notes,
      'metadata': metadata,
      'submitted_at': submittedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Rollup financial summary for a booking
class BookingPaymentSummary {
  final double totalPaidAmount;
  final double totalPendingAmount;
  final double totalRefundedAmount;
  final int totalTransactions;
  final bool isFullyPaid;
  final double remainingBalance;

  const BookingPaymentSummary({
    required this.totalPaidAmount,
    required this.totalPendingAmount,
    required this.totalRefundedAmount,
    required this.totalTransactions,
    required this.isFullyPaid,
    required this.remainingBalance,
  });

  factory BookingPaymentSummary.fromPayments({
    required List<PaymentRecord> payments,
    required double bookingTotalPrice,
  }) {
    double paid = 0.0;
    double pending = 0.0;
    double refunded = 0.0;

    for (final p in payments) {
      if (p.paymentType == PaymentType.refund) {
        refunded += p.amount;
      } else if (p.status.isSettled) {
        paid += p.amount;
      } else if (p.status == PaymentRecordStatus.pending ||
          p.status == PaymentRecordStatus.pendingReview) {
        pending += p.amount;
      }
    }

    final balance = (bookingTotalPrice - paid) > 0 ? (bookingTotalPrice - paid) : 0.0;
    final fullyPaid = bookingTotalPrice > 0 && paid >= bookingTotalPrice;

    return BookingPaymentSummary(
      totalPaidAmount: paid,
      totalPendingAmount: pending,
      totalRefundedAmount: refunded,
      totalTransactions: payments.length,
      isFullyPaid: fullyPaid,
      remainingBalance: balance,
    );
  }
}

/// Unified PaymentService providing centralized payment recording, retrieval, and audit
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();

  factory PaymentService({SupabaseClient? client}) {
    if (client != null) {
      return PaymentService._withClient(client);
    }
    return _instance;
  }

  PaymentService._internal() : _supabase = Supabase.instance.client;
  PaymentService._withClient(this._supabase);

  final SupabaseClient _supabase;

  /// Fetches all payments associated with a booking, ordered chronologically
  Future<List<PaymentRecord>> getPaymentsForBooking(String bookingId) async {
    final cleanId = bookingId.trim();
    if (cleanId.isEmpty) return [];

    try {
      final data = await _supabase
          .from('payments')
          .select('*')
          .eq('booking_id', cleanId)
          .order('created_at', ascending: true);

      return (data as List)
          .map((row) => PaymentRecord.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Error fetching payments for booking $cleanId: $e');
      return [];
    }
  }

  /// Streams realtime payments for a given booking
  Stream<List<PaymentRecord>> streamPaymentsForBooking(String bookingId) {
    final cleanId = bookingId.trim();
    if (cleanId.isEmpty) {
      return Stream.value(<PaymentRecord>[]);
    }

    return _supabase
        .from('payments')
        .stream(primaryKey: ['id'])
        .eq('booking_id', cleanId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((r) => PaymentRecord.fromJson(r)).toList());
  }

  /// Records a new payment in public.payments table
  Future<PaymentRecord?> recordPayment({
    required String bookingId,
    String? payerUserId,
    required PaymentType paymentType,
    required double amount,
    String paymentMethod = 'gcash',
    String? referenceNumber,
    String? senderPhone,
    String? proofUrl,
    String? proofStoragePath,
    PaymentRecordStatus status = PaymentRecordStatus.pending,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = <String, dynamic>{
      'booking_id': bookingId.trim(),
      if (payerUserId != null && payerUserId.trim().isNotEmpty)
        'payer_user_id': payerUserId.trim(),
      'payment_type': paymentType.toDbString(),
      'amount': amount,
      'payment_method': paymentMethod.trim().toLowerCase(),
      if (referenceNumber != null && referenceNumber.trim().isNotEmpty)
        'reference_number': referenceNumber.trim(),
      if (senderPhone != null && senderPhone.trim().isNotEmpty)
        'sender_phone': senderPhone.trim(),
      if (proofUrl != null && proofUrl.trim().isNotEmpty)
        'proof_url': proofUrl.trim(),
      if (proofStoragePath != null && proofStoragePath.trim().isNotEmpty)
        'proof_storage_path': proofStoragePath.trim(),
      'status': status.toDbString(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'metadata': ?metadata,
      'submitted_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('payments').insert(payload).select().single();
      return PaymentRecord.fromJson(res);
    } catch (e) {
      debugPrint('⚠️ Error recording payment in public.payments: $e');
      rethrow;
    }
  }

  /// Updates or verifies a payment record (Operator/Admin audit)
  Future<void> updatePaymentStatus({
    required String paymentId,
    required PaymentRecordStatus newStatus,
    String? verifiedByUserId,
    String? rejectionReason,
    String? auditNotes,
  }) async {
    final cleanId = paymentId.trim();
    if (cleanId.isEmpty) return;

    final updates = <String, dynamic>{
      'status': newStatus.toDbString(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (newStatus.isSettled) {
      updates['verified_at'] = DateTime.now().toIso8601String();
      if (verifiedByUserId != null) {
        updates['verified_by'] = verifiedByUserId;
      }
    } else if (newStatus == PaymentRecordStatus.rejected) {
      if (rejectionReason != null) {
        updates['rejection_reason'] = rejectionReason;
      }
    }

    if (auditNotes != null) {
      updates['notes'] = auditNotes;
    }

    await _supabase.from('payments').update(updates).eq('id', cleanId);
  }

  /// Computes the financial summary for a booking
  Future<BookingPaymentSummary> getSummaryForBooking(
    String bookingId, {
    required double totalPrice,
  }) async {
    final payments = await getPaymentsForBooking(bookingId);
    return BookingPaymentSummary.fromPayments(
      payments: payments,
      bookingTotalPrice: totalPrice,
    );
  }
}
