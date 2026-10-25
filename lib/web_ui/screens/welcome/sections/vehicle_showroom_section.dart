import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';
import '../widgets/hover_vehicle_card.dart';

class VehicleShowroomSection extends StatelessWidget {
  final Key? sectionKey;
  final bool isDesktop;
  final bool isTablet;
  final double width;
  final List<Map<String, dynamic>> vehicles;
  final bool isLoading;
  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;
  final void Function(Map<String, dynamic> vehicle) onBookVehicle;

  const VehicleShowroomSection({
    super.key,
    this.sectionKey,
    required this.isDesktop,
    required this.isTablet,
    required this.width,
    required this.vehicles,
    required this.isLoading,
    required this.selectedCategory,
    required this.onSelectCategory,
    required this.onBookVehicle,
  });

  Widget _buildCategoryFilterTab(String key, String label, IconData icon) {
    final isSelected = selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: InkWell(
        onTap: () => onSelectCategory(key),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFF0A1733),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0x22FFFFFF),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF030A18) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF030A18) : const Color(0xFFCBD5E1),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = width < 768;

    return Container(
      key: sectionKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Section Header
              const Text(
                'EXPLORE OUR PANGASINAN FLEET',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Available Vehicles Ready For Your Journey',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 36 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'All vehicles undergo 100% digital safety inspections and include real-time satellite GPS tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 28),

              // 4 Category Filter Tabs + All
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: isMobile ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    _buildCategoryFilterTab('all', 'All Vehicles', Icons.directions_car_filled_rounded),
                    _buildCategoryFilterTab('sedan', 'Sedans', Icons.directions_car_rounded),
                    _buildCategoryFilterTab('suv', 'SUVs', Icons.car_rental_rounded),
                    _buildCategoryFilterTab('pickup', 'Pickups', Icons.local_shipping_rounded),
                    _buildCategoryFilterTab('van', 'Vans', Icons.airport_shuttle_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Vehicle Grid
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (vehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.directions_car_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text(
                        'No vehicles available in this category.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final int crossAxisCount;
                    if (availableWidth < 680) {
                      crossAxisCount = 1;
                    } else if (availableWidth < 1050) {
                      crossAxisCount = 2;
                    } else {
                      crossAxisCount = 3;
                    }

                    const double spacing = 18;
                    final double cardWidth = crossAxisCount == 1
                        ? availableWidth
                        : (availableWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

                    return Center(
                      child: Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        alignment: WrapAlignment.start,
                        children: vehicles.map((v) {
                          return SizedBox(
                            width: cardWidth,
                            child: HoverVehicleCard(
                              vehicle: v,
                              onBook: () => onBookVehicle(v),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
