import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CostBreakdownRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool isBold;
  final Color? amountColor;

  const CostBreakdownRow({
    super.key,
    required this.label,
    required this.amount,
    this.isBold = false,
    this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? primaryText : secondaryText,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: amountColor ?? primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
