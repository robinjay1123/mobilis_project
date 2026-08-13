import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small, reusable visual status treatment for dialogs that show requirements.
///
/// This widget intentionally only presents the state supplied by the caller;
/// it does not validate, submit, or change any data.
class DialogStatusIndicator extends StatelessWidget {
  final bool isComplete;
  final String completeLabel;
  final String incompleteLabel;
  final String? completeDetail;
  final String? incompleteDetail;
  final bool compact;

  const DialogStatusIndicator({
    super.key,
    required this.isComplete,
    required this.completeLabel,
    required this.incompleteLabel,
    this.completeDetail,
    this.incompleteDetail,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isComplete ? AppColors.success : AppColors.error;
    final label = isComplete ? completeLabel : incompleteLabel;
    final detail = isComplete ? completeDetail : incompleteDetail;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 28 : 32,
            height: compact ? 28 : 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isComplete
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: color,
              size: compact ? 17 : 19,
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail != null && detail.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: compact ? 11 : 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
