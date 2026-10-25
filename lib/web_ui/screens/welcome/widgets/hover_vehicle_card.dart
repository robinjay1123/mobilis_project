import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';

class HoverVehicleCard extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final VoidCallback onBook;

  const HoverVehicleCard({
    super.key,
    required this.vehicle,
    required this.onBook,
  });

  @override
  State<HoverVehicleCard> createState() => _HoverVehicleCardState();
}

class _HoverVehicleCardState extends State<HoverVehicleCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final brand = vehicle['brand']?.toString() ?? 'Toyota';
    final model = vehicle['model']?.toString() ?? 'Model';
    final year = vehicle['year']?.toString() ?? '2024';
    final seats = vehicle['seats']?.toString() ?? '5';
    final transmission = vehicle['transmission']?.toString() ?? 'Automatic';
    final fuel = vehicle['fuel_type']?.toString() ?? 'Gasoline';
    final priceDay = (vehicle['price_per_day'] as num?)?.toDouble() ?? 1800.0;
    final priceHour = (vehicle['price_per_hour'] as num?)?.toDouble() ?? (priceDay / 10).roundToDouble();
    final tag = vehicle['tag']?.toString() ?? 'PSDC Fleet • Urdaneta';
    final plate = vehicle['plate_number']?.toString().trim() ?? '';
    
    String? imageUrl = vehicle['image_url']?.toString();
    if (imageUrl == null && vehicle['vehicle_images'] is List && (vehicle['vehicle_images'] as List).isNotEmpty) {
      imageUrl = vehicle['vehicle_images'][0]['image_url']?.toString();
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onBook,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFF0D2048) : const Color(0xFF091636),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? AppColors.primary : const Color(0x22FFFFFF),
              width: _isHovered ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: _isHovered ? 24 : 14,
                offset: Offset(0, _isHovered ? 10 : 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Image Container with Zoom Effect on Hover
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                    child: Container(
                      height: 165,
                      width: double.infinity,
                      color: const Color(0xFF061026),
                      child: AnimatedScale(
                        scale: _isHovered ? 1.06 : 1.0,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 640,
                                errorBuilder: (context, error, stackTrace) => _buildFallbackCarGraphic(brand, model),
                              )
                            : _buildFallbackCarGraphic(brand, model),
                      ),
                    ),
                  ),
                  // Gradient overlay at bottom of image for sleek transition
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // PSDC Fleet Tag
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFD740), Color(0xFFFFB300)]),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFF030A18),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  // GPS Monitored Indicator Badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xDD000000),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isHovered ? AppColors.primary : const Color(0x33FFFFFF),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isHovered ? AppColors.primary : const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 4.5),
                          const Text(
                            'GPS LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Compact Details Section
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$brand $model',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (plate.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x22FFFFFF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              plate,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$year Model  •  Exclusively in Pangasinan',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Specs Chips
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _buildSpecBadge(Icons.people_alt_outlined, '$seats Seats'),
                        _buildSpecBadge(Icons.settings_outlined, transmission),
                        _buildSpecBadge(Icons.local_gas_station_outlined, fuel),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Divider(color: Color(0x1AFFFFFF), height: 1),
                    const SizedBox(height: 10),

                    // Pricing & Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₱${priceDay.toStringAsFixed(0)} / day',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '₱${priceHour.toStringAsFixed(0)}/hr (12h min)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: widget.onBook,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isHovered ? AppColors.primary : const Color(0xFFFFD740),
                            foregroundColor: const Color(0xFF030A18),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                            elevation: _isHovered ? 5 : 2,
                            shadowColor: AppColors.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Book Now', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
                              if (_isHovered) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 13),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCarGraphic(String brand, String model) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_rounded, size: 48, color: AppColors.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          Text(
            '$brand $model',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          const Text('Mobilis Verified Vehicle', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSpecBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF061229),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: AppColors.primary),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
