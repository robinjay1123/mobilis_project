import 'dart:async';

import 'package:flutter/material.dart';

/// Parses chat timestamps while remaining compatible with legacy messages that
/// were saved as local wall-clock values but interpreted by Postgres as UTC.
DateTime? parseMessageTimestamp(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;

  final now = DateTime.now();
  final local = parsed.toLocal();
  const clockSkewTolerance = Duration(minutes: 2);

  if (parsed.isUtc && local.isAfter(now.add(clockSkewTolerance))) {
    final legacyLocal = DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
    if (!legacyLocal.isAfter(now.add(clockSkewTolerance))) {
      return legacyLocal;
    }
  }

  return local;
}

class RelativeTimeText extends StatefulWidget {
  const RelativeTimeText({super.key, required this.value, required this.style});

  final dynamic value;
  final TextStyle style;

  @override
  State<RelativeTimeText> createState() => _RelativeTimeTextState();
}

class _RelativeTimeTextState extends State<RelativeTimeText> {
  Timer? _timer;

  DateTime? get _date => parseMessageTimestamp(widget.value);

  @override
  void initState() {
    super.initState();
    _scheduleUpdate();
  }

  @override
  void didUpdateWidget(covariant RelativeTimeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _scheduleUpdate();
  }

  void _scheduleUpdate() {
    _timer?.cancel();
    final date = _date;
    if (date == null) return;
    final age = DateTime.now().difference(date);
    final delay = age.inMinutes < 1
        ? const Duration(seconds: 1)
        : age.inHours < 1
        ? const Duration(minutes: 1)
        : const Duration(hours: 1);
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleUpdate();
    });
  }

  String _label() {
    final date = _date;
    if (date == null) return '';
    final difference = DateTime.now().difference(date);
    if (difference.isNegative || difference.inSeconds < 4) return 'now';
    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(_label(), style: widget.style);
}
