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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSender ? AppColors.primary : AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSender ? AppColors.primary : AppColors.borderColor,
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: isSender ? Colors.black : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timestamp,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
