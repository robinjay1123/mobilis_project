import 'package:flutter/material.dart';

import '../mobile_ui/theme/app_colors.dart';

enum BookingStatusGroup { pending, approved, ongoing, completed, cancelled }

const bookingStatusOrder = <BookingStatusGroup>[
  BookingStatusGroup.pending,
  BookingStatusGroup.approved,
  BookingStatusGroup.ongoing,
  BookingStatusGroup.completed,
  BookingStatusGroup.cancelled,
];

BookingStatusGroup bookingStatusGroup(dynamic value) {
  final status = value?.toString().trim().toLowerCase() ?? '';
  if ({'approved', 'confirmed', 'assigned'}.contains(status)) {
    return BookingStatusGroup.approved;
  }
  if ({'active', 'ongoing', 'picked_up', 'in_progress'}.contains(status)) {
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
};

Color bookingStatusColor(BookingStatusGroup status) => switch (status) {
  BookingStatusGroup.pending => AppColors.warning,
  BookingStatusGroup.approved => AppColors.primary,
  BookingStatusGroup.ongoing => AppColors.success,
  BookingStatusGroup.completed => const Color(0xFF4EA5FF),
  BookingStatusGroup.cancelled => AppColors.error,
};
