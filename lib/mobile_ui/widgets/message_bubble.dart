import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final String timestamp;
  final bool isSender;

  const MessageBubble({
    super.key,
    required this.message,
    required this.timestamp,
    required this.isSender,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBg = isSender
        ? AppColors.primary
        : (isDark ? AppColors.darkCard : const Color(0xFFE2E8F0));
    final bubbleBorder = isSender
        ? AppColors.primary
        : (isDark ? AppColors.borderColor : const Color(0xFFCBD5E1));
    final textColor = isSender
        ? Colors.black
        : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary);
    final timestampColor = isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: isSender
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: bubbleBorder,
                  width: 1.2,
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timestamp,
              style: TextStyle(
                fontSize: 10,
                color: timestampColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
