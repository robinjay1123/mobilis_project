import 'package:flutter/material.dart';

import '../mobile_ui/theme/app_colors.dart';

enum BookingStatusGroup { pending, approved, ongoing, completed, cancelled, frozen }

enum BookingPaymentState {
  paymentPending,
  paymentReview,
  pendingConfirmation,
  paid,
  refundRequired,
  refunded,
}

const bookingStatusOrder = <BookingStatusGroup>[
  BookingStatusGroup.pending,
  BookingStatusGroup.approved,
  BookingStatusGroup.ongoing,
  BookingStatusGroup.completed,
  BookingStatusGroup.cancelled,
  BookingStatusGroup.frozen,
];

BookingStatusGroup bookingStatusGroup(dynamic value) {
  final status = value?.toString().trim().toLowerCase() ?? '';
  if ({'frozen', 'safety_freeze', 'locked'}.contains(status)) {
    return BookingStatusGroup.frozen;
  }
  if ({'approved', 'confirmed', 'assigned'}.contains(status)) {
    return BookingStatusGroup.approved;
  }
  if ({
    'active',
    'ongoing',
    'picked_up',
    'in_progress',
    'return_pending_inspection',
    'awaiting_completion',
    'awaiting_ratings',
  }.contains(status)) {
    return BookingStatusGroup.ongoing;
  }
  if ({'completed', 'returned', 'successful', 'success'}.contains(status)) {
    return BookingStatusGroup.completed;
  }
  if ({'cancelled', 'canceled', 'rejected', 'declined'}.contains(status)) {
    return BookingStatusGroup.cancelled;
  }
  return BookingStatusGroup.pending;
}

String bookingStatusLabel(BookingStatusGroup status) => switch (status) {
  BookingStatusGroup.pending => 'Pending',
  BookingStatusGroup.approved => 'Approved',
  BookingStatusGroup.ongoing => 'Ongoing',
  BookingStatusGroup.completed => 'Completed',
  BookingStatusGroup.cancelled => 'Cancelled',
  BookingStatusGroup.frozen => 'Frozen',
};

Color bookingStatusColor(BookingStatusGroup status) => switch (status) {
  BookingStatusGroup.pending => AppColors.warning,
  BookingStatusGroup.approved => AppColors.primary,
  BookingStatusGroup.ongoing => AppColors.success,
  BookingStatusGroup.completed => const Color(0xFF4EA5FF),
  BookingStatusGroup.cancelled => AppColors.error,
  BookingStatusGroup.frozen => const Color(0xFF00E5FF),
};

BookingPaymentState resolveBookingPaymentState(Map<String, dynamic> booking) {
  final refundStatus = (booking['refund_status'] ?? '').toString().trim().toLowerCase();
  final refundComplete = booking['refund_completed'] == true ||
      booking['refunded_at'] != null ||
      refundStatus == 'refunded' ||
      refundStatus == 'completed';
  if (refundComplete) return BookingPaymentState.refunded;

  final refundNeeded = refundStatus == 'refund_needed' ||
      refundStatus == 'refund_pending' ||
      refundStatus == 'refund_required' ||
      refundStatus == 'refund_initiated' ||
      booking['refund_required'] == true;
  if (refundNeeded) return BookingPaymentState.refundRequired;

  final finalPaymentStatus = (booking['final_payment_status'] ?? '').toString().trim().toLowerCase();
  final paymentStatus = (booking['payment_status'] ?? '').toString().trim().toLowerCase();
  final resPaymentStatus = (booking['reservation_payment_status'] ?? '').toString().trim().toLowerCase();
  final isPaid = finalPaymentStatus == 'paid' ||
      finalPaymentStatus == 'completed' ||
      paymentStatus == 'paid' ||
      paymentStatus == 'fully_paid' ||
      paymentStatus == 'full_paid';

  final bookingGroup = bookingStatusGroup(booking['status']);

  // If approved/ongoing/completed and paid
  if (isPaid && (bookingGroup == BookingStatusGroup.approved ||
      bookingGroup == BookingStatusGroup.ongoing ||
      bookingGroup == BookingStatusGroup.completed)) {
    return BookingPaymentState.paid;
  }

  // If payment is verified or accepted before final operator approval
  final isVerified = resPaymentStatus == 'verified' ||
      resPaymentStatus == 'confirmed' ||
      finalPaymentStatus == 'verified' ||
      booking['payment_verified'] == true ||
      (isPaid && bookingGroup == BookingStatusGroup.pending);

  if (isVerified) {
    return BookingPaymentState.pendingConfirmation;
  }

  // If payment proof is submitted and under review
  final hasProof = (booking['final_payment_receipt_url']?.toString().trim().isNotEmpty == true) ||
      (booking['reservation_payment_receipt_url']?.toString().trim().isNotEmpty == true) ||
      (booking['payment_receipt_url']?.toString().trim().isNotEmpty == true) ||
      (booking['reservation_payment_reference']?.toString().trim().isNotEmpty == true) ||
      (booking['final_payment_reference']?.toString().trim().isNotEmpty == true) ||
      booking['renter_return_payment_submitted'] == true;

  final isUnderReview = resPaymentStatus == 'pending_review' ||
      resPaymentStatus == 'under_review' ||
      resPaymentStatus == 'submitted' ||
      finalPaymentStatus == 'submitted' ||
      finalPaymentStatus == 'pending_review' ||
      paymentStatus == 'submitted' ||
      hasProof;

  if (isUnderReview) {
    return BookingPaymentState.paymentReview;
  }

  if (isPaid) return BookingPaymentState.paid;

  return BookingPaymentState.paymentPending;
}

String bookingPaymentStateLabel(BookingPaymentState state) => switch (state) {
  BookingPaymentState.paymentPending => 'Payment Pending',
  BookingPaymentState.paymentReview => 'Payment Review',
  BookingPaymentState.pendingConfirmation => 'Pending Confirmation',
  BookingPaymentState.paid => 'Paid',
  BookingPaymentState.refundRequired => 'Refund Required',
  BookingPaymentState.refunded => 'Refunded',
};

Color bookingPaymentStateColor(BookingPaymentState state) => switch (state) {
  BookingPaymentState.paymentPending => const Color(0xFFF59E0B),
  BookingPaymentState.paymentReview => const Color(0xFF38BDF8),
  BookingPaymentState.pendingConfirmation => const Color(0xFF14B8A6),
  BookingPaymentState.paid => const Color(0xFF10B981),
  BookingPaymentState.refundRequired => const Color(0xFFEF4444),
  BookingPaymentState.refunded => const Color(0xFFA855F7),
};
