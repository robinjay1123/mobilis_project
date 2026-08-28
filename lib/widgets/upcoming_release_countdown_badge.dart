import 'dart:async';
import 'package:flutter/material.dart';

/// Attention badge and live 24-hour countdown for upcoming booking releases.
class UpcomingReleaseCountdownBadge extends StatefulWidget {
  final Map<String, dynamic> booking;
  final bool compact;
  final bool isDark;

  const UpcomingReleaseCountdownBadge({
    super.key,
    required this.booking,
    this.compact = false,
    this.isDark = true,
  });

  /// Static helper to check if an approved/upcoming booking is within 24 hours of release
  static bool isWithin24Hours(Map<String, dynamic> booking) {
    final status = (booking['status']?.toString() ?? '').toLowerCase().trim();
    // Show for approved, confirmed, paid, or reserved upcoming bookings
    if (status != 'approved' &&
        status != 'confirmed' &&
        status != 'paid' &&
        status != 'reserved') {
      return false;
    }

    final rawStart = booking['start_at'] ?? booking['start_date'];
    if (rawStart == null) return false;
    final startAt = DateTime.tryParse(rawStart.toString())?.toLocal();
    if (startAt == null) return false;

    final now = DateTime.now();
    final diff = startAt.difference(now);
    // Return true if within 24 hours before trip start or up to 4 hours overdue before pickup
    return diff.inHours < 24 && diff.inHours >= -4;
  }

  @override
  State<UpcomingReleaseCountdownBadge> createState() =>
      _UpcomingReleaseCountdownBadgeState();
}

class _UpcomingReleaseCountdownBadgeState
    extends State<UpcomingReleaseCountdownBadge> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawStart =
        widget.booking['start_at'] ?? widget.booking['start_date'];
    if (rawStart == null) return const SizedBox.shrink();
    final startAt = DateTime.tryParse(rawStart.toString())?.toLocal();
    if (startAt == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final diff = startAt.difference(now);

    if (diff.inHours >= 24 || diff.inHours < -4) {
      return const SizedBox.shrink();
    }

    final bool isDue = diff.isNegative;
    final absDiff = diff.abs();
    final hours = absDiff.inHours;
    final minutes = absDiff.inMinutes.remainder(60);
    final seconds = absDiff.inSeconds.remainder(60);

    final String timeStr = isDue
        ? 'RELEASE DUE NOW'
        : 'Release in ${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';

    final Color badgeBg = isDue
        ? Colors.red.shade900.withValues(alpha: 0.95)
        : (hours < 3
            ? Colors.deepOrange.shade900.withValues(alpha: 0.92)
            : const Color(0xFFE65100).withValues(alpha: 0.88));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 8 : 10,
        vertical: widget.compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDue ? Colors.redAccent : Colors.orangeAccent,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDue ? Colors.red : Colors.orange).withValues(alpha: 0.35),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDue ? Icons.warning_amber_rounded : Icons.access_time_filled,
            size: widget.compact ? 12 : 14,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            widget.compact ? timeStr.replaceAll('Release in ', '') : timeStr,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
