import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/pricing_policy.dart';

class BookingReturnCountdown extends StatefulWidget {
  const BookingReturnCountdown({
    super.key,
    required this.booking,
    this.compact = false,
    this.lightBackground = false,
  });

  final Map<String, dynamic> booking;
  final bool compact;
  final bool lightBackground;

  static DateTime? scheduledReturn(Map<String, dynamic> booking) {
    for (final key in const ['end_at', 'end_date']) {
      final parsed = DateTime.tryParse(booking[key]?.toString() ?? '');
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  @override
  State<BookingReturnCountdown> createState() => _BookingReturnCountdownState();
}

class _BookingReturnCountdownState extends State<BookingReturnCountdown> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _durationLabel(Duration duration) {
    final seconds = duration.inSeconds.abs();
    final days = seconds ~/ Duration.secondsPerDay;
    final hours = (seconds ~/ Duration.secondsPerHour) % 24;
    final minutes = (seconds ~/ Duration.secondsPerMinute) % 60;
    final remainingSeconds = seconds % 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    parts.add('${hours.toString().padLeft(2, '0')}h');
    parts.add('${minutes.toString().padLeft(2, '0')}m');
    if (!widget.compact) {
      parts.add('${remainingSeconds.toString().padLeft(2, '0')}s');
    }
    return parts.join(' ');
  }

  String _money(double value) {
    final digits = value.round().toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  @override
  Widget build(BuildContext context) {
    final returnedAtRaw = widget.booking['returned_at']?.toString() ??
        widget.booking['returnedAt']?.toString();
    final statusRaw = (widget.booking['status'] ?? widget.booking['rawStatus'] ?? '').toString().toLowerCase();

    final isReturned = returnedAtRaw != null ||
        const {'return_pending_inspection', 'awaiting_completion', 'completed'}.contains(statusRaw);

    if (isReturned) {
      return Container(
        width: widget.compact ? null : double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 9 : 12,
          vertical: widget.compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withOpacity(0.55)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                'Vehicle Returned — Inspection & Verification Pending',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final scheduledReturn = BookingReturnCountdown.scheduledReturn(
      widget.booking,
    );
    if (scheduledReturn == null) return const SizedBox.shrink();

    final remaining = scheduledReturn.difference(_now);
    final overdue = remaining.isNegative;
    final lateHours = overdue
        ? math.max(1, (-remaining.inSeconds / Duration.secondsPerHour).ceil())
        : 0;
    final vehicle = widget.booking['vehicles'] as Map<String, dynamic>?;
    final seats = (vehicle?['seats'] as num?)?.toInt() ??
        (widget.booking['seats'] as num?)?.toInt() ??
        4;
    final dailyRate =
        (vehicle?['daily_rate'] as num?)?.toDouble() ??
        (vehicle?['price_per_day'] as num?)?.toDouble() ??
        0.0;
    final estimatedPenalty = PricingPolicy.calculateLateReturnFee(
      seats: seats,
      lateHours: lateHours,
      dailyRate: dailyRate,
    );
    final accent = overdue ? const Color(0xFFFF5C5C) : const Color(0xFFFFD600);
    final foreground = widget.lightBackground
        ? const Color(0xFF08233D)
        : Colors.white;

    return Container(
      width: widget.compact ? null : double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 9 : 12,
        vertical: widget.compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: accent.withOpacity(widget.lightBackground ? 0.12 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Icon(
            overdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
            color: accent,
            size: widget.compact ? 15 : 18,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              overdue
                  ? 'Late by ${_durationLabel(remaining)}${widget.compact ? '' : '  |  Estimated penalty: PHP ${_money(estimatedPenalty)}'}'
                  : 'Return in ${_durationLabel(remaining)}',
              maxLines: widget.compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: widget.compact ? 10 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
