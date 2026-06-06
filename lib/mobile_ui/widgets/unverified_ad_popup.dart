// import 'package:flutter/material.dart';
// import '../../theme/app_colors.dart';
// import '../../widgets/custom_button.dart';

// class UnverifiedAdPopup {
//   /// Show popup when unverified user tries to post ad/list vehicle
//   static Future<void> show({
//     required BuildContext context,
//     String title = 'Verification Required',
//     String message =
//         'You need to complete identity verification before you can add a vehicle.',
//     String userRole = 'partner',
//   }) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final bgColor = isDark ? AppColors.darkBgSecondary : Colors.white;
//     final textColor = isDark
//         ? AppColors.textPrimary
//         : AppColors.lightTextPrimary;

//     return showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: bgColor,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Warning icon
//                 Container(
//                   width: 64,
//                   height: 64,
//                   decoration: BoxDecoration(
//                     color: AppColors.warning.withValues(
//                       alpha: 0.2,
//                     ), // ✅ fixed deprecated withOpacity
//                     shape: BoxShape.circle,
//                   ),
//                   child: const Icon(
//                     Icons.lock_outline,
//                     color: AppColors.warning,
//                     size: 32,
//                   ),
//                 ),
//                 const SizedBox(height: 20),

//                 // Title
//                 Text(
//                   title,
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w700,
//                     color: textColor,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 12),

//                 // Message
//                 Text(
//                   message,
//                   style: TextStyle(
//                     fontSize: 14,
//                     color: isDark
//                         ? AppColors.textSecondary
//                         : AppColors.lightTextSecondary,
//                     height: 1.5,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 12),

//                 // Requirements list
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: isDark ? AppColors.darkBg : Colors.grey[50],
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(
//                       color: isDark ? AppColors.borderColor : Colors.grey[300]!,
//                     ),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "What's needed:",
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                           color: textColor,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       _buildRequirement(isDark, '✓ National ID (front & back)'),
//                       const SizedBox(height: 6),
//                       _buildRequirement(isDark, '✓ Admin approval'),
//                       const SizedBox(height: 6),
//                       _buildRequirement(isDark, '≈ Takes 1-2 business days'),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 24),

//                 // Buttons
//                 SizedBox(
//                   width: double.infinity,
//                   child: CustomButton(
//                     label: 'Verify Now',
//                     onPressed: () {
//                       Navigator.pop(context);
//                       Navigator.pushNamed(
//                         context,
//                         '/partner-document-verification',
//                       );
//                     },
//                     backgroundColor: AppColors.primary,
//                     textColor: Colors.black,
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 SizedBox(
//                   width: double.infinity,
//                   child: OutlinedButton(
//                     onPressed: () => Navigator.pop(context),
//                     style: OutlinedButton.styleFrom(
//                       side: BorderSide(
//                         color: isDark
//                             ? AppColors.borderColor
//                             : Colors.grey[300]!,
//                       ),
//                     ),
//                     child: Text(
//                       'Cancel',
//                       style: TextStyle(
//                         color: isDark
//                             ? AppColors.textPrimary
//                             : AppColors.lightTextPrimary,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   static Widget _buildRequirement(bool isDark, String text) {
//     return Text(
//       text,
//       style: TextStyle(
//         fontSize: 12,
//         color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
//       ),
//     );
//   }
// }
