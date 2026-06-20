import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

void showPolicyDetailsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.darkBgSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Policy Details',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Keep conversations, payments, and coordination inside the app. Sharing phone numbers, third-party app handles, emails, bank details, or asking users to move off-platform can trigger safety restrictions.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          SizedBox(height: 14),
          Text(
            'Common violations',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• Sending phone numbers or email addresses\n• Asking users to continue on WhatsApp, Telegram, Messenger, or similar apps\n• Arranging direct payment outside Mobilis\n• Sharing bank account or e-wallet details inside chat',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    ),
  );
}

class RestrictionCountdownRow extends StatelessWidget {
  final DateTime? until;
  final bool includeSeconds;

  const RestrictionCountdownRow({
    super.key,
    required this.until,
    this.includeSeconds = false,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining(until);
    final values = <Map<String, String>>[
      {
        'value': remaining.inHours.remainder(100).toString().padLeft(2, '0'),
        'label': 'HOURS',
      },
      {
        'value': remaining.inMinutes.remainder(60).toString().padLeft(2, '0'),
        'label': 'MINUTES',
      },
      if (includeSeconds)
        {
          'value': remaining.inSeconds.remainder(60).toString().padLeft(2, '0'),
          'label': 'SECONDS',
        },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: values
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF132A42),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF315A80)),
                    ),
                    child: Text(
                      item['value']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['label']!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Duration _remaining(DateTime? until) {
    if (until == null) return Duration.zero;
    final diff = until.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}
