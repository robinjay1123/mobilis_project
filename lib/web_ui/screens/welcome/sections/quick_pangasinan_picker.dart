import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';

class QuickPangasinanPicker extends StatelessWidget {
  final bool isDesktop;
  final double width;
  final VoidCallback onCheckAvailability;

  const QuickPangasinanPicker({
    super.key,
    required this.isDesktop,
    required this.width,
    required this.onCheckAvailability,
  });

  Widget _buildQuickPickerItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = width < 768;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0C1D40), Color(0xFF07142D)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _buildQuickPickerItem(
                  icon: Icons.location_on_rounded,
                  label: 'Pick-up Location',
                  value: 'Urdaneta City / Pangasinan Hub',
                ),
                _buildQuickPickerItem(
                  icon: Icons.schedule_rounded,
                  label: 'Rental Duration',
                  value: 'Hourly (12h Min) or Daily',
                ),
                _buildQuickPickerItem(
                  icon: Icons.person_pin_circle_rounded,
                  label: 'Driver Option',
                  value: 'Self-Drive or with Driver',
                ),
                SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: ElevatedButton.icon(
                    onPressed: onCheckAvailability,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Check Availability', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF030A18),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
