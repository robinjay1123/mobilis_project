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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: amountColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
