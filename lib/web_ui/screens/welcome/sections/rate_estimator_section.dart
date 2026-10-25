import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';
import '../../../../utils/pricing_policy.dart';

class RateEstimatorSection extends StatefulWidget {
  final Key? sectionKey;
  final bool isDesktop;
  final bool isTablet;
  final double width;
  final VoidCallback onProceedToBook;

  const RateEstimatorSection({
    super.key,
    this.sectionKey,
    required this.isDesktop,
    required this.isTablet,
    required this.width,
    required this.onProceedToBook,
  });

  @override
  State<RateEstimatorSection> createState() => _RateEstimatorSectionState();
}

class _RateEstimatorSectionState extends State<RateEstimatorSection> {
  String _estimatorMode = 'daily'; // 'hourly' or 'daily'
  int _estimatorDays = 1;
  int _estimatorHours = 12;
  String _estimatorVehicleType = 'Sedan';
  bool _estimatorWithDriver = false;
  bool _estimatorDoorstepDelivery = false;
  final double _estimatorDeliveryKm = 10.0;

  double get _calculatedEstimate {
    double baseRate = 0;
    switch (_estimatorVehicleType) {
      case 'Compact':
        baseRate = _estimatorMode == 'hourly' ? 160.0 * _estimatorHours : 1500.0 * _estimatorDays;
        break;
      case 'Sedan':
        baseRate = _estimatorMode == 'hourly' ? 180.0 * _estimatorHours : 1800.0 * _estimatorDays;
        break;
      case 'MPV':
        baseRate = _estimatorMode == 'hourly' ? 280.0 * _estimatorHours : 2600.0 * _estimatorDays;
        break;
      case 'SUV':
        baseRate = _estimatorMode == 'hourly' ? 380.0 * _estimatorHours : 3500.0 * _estimatorDays;
        break;
      case 'Pickup':
        baseRate = _estimatorMode == 'hourly' ? 340.0 * _estimatorHours : 3200.0 * _estimatorDays;
        break;
      case 'Van':
        baseRate = _estimatorMode == 'hourly' ? 420.0 * _estimatorHours : 3800.0 * _estimatorDays;
        break;
      default:
        baseRate = 1800.0 * _estimatorDays;
    }

    double driverCost = 0.0;
    if (_estimatorWithDriver) {
      final days = _estimatorMode == 'hourly' ? 1 : _estimatorDays;
      driverCost = days * PricingPolicy.driverDailyRate;
    }

    double deliveryCost = 0.0;
    if (_estimatorDoorstepDelivery && !_estimatorWithDriver) {
      deliveryCost = _estimatorDeliveryKm * PricingPolicy.deliveryRatePerKm;
    }

    return baseRate + driverCost + deliveryCost;
  }

  Widget _buildEstimatorPill({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFF06142E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : const Color(0x22FFFFFF)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF030A18) : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.width < 768;

    return Container(
      key: widget.sectionKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: widget.isDesktop ? 80 : 48,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF061229),
        border: Border.symmetric(horizontal: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              const Text(
                'TRANSPARENT RENTAL COST ESTIMATOR',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Instant Cost Breakdown Calculator',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.isDesktop ? 36 : (widget.isTablet ? 28 : 24),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Calculate transparent estimated rental costs according to PSDC Pangasinan pricing rules.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Interactive Estimator Card
              Container(
                padding: EdgeInsets.all(isMobile ? 18 : 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1838),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 24,
                  children: [
                    // Left Column: Controls
                    SizedBox(
                      width: widget.isDesktop ? 540 : double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rental Mode
                          const Text('Rental Type', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildEstimatorPill(
                                selected: _estimatorMode == 'daily',
                                label: '📅 Daily Rental',
                                onTap: () => setState(() => _estimatorMode = 'daily'),
                              ),
                              const SizedBox(width: 10),
                              _buildEstimatorPill(
                                selected: _estimatorMode == 'hourly',
                                label: '⏱️ Hourly (12h Min)',
                                onTap: () => setState(() => _estimatorMode = 'hourly'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Vehicle Type
                          const Text('Vehicle Class', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['Sedan', 'SUV', 'Pickup', 'Van'].map((type) {
                              final isSel = _estimatorVehicleType == type;
                              return InkWell(
                                onTap: () => setState(() => _estimatorVehicleType = type),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSel ? AppColors.primary : const Color(0xFF06142E),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isSel ? AppColors.primary : const Color(0x22FFFFFF)),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      color: isSel ? const Color(0xFF030A18) : Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Duration Slider
                          Text(
                            _estimatorMode == 'daily'
                                ? 'Duration: $_estimatorDays Day${_estimatorDays == 1 ? '' : 's'}'
                                : 'Duration: $_estimatorHours Hours (Half-day+)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Slider(
                            value: _estimatorMode == 'daily' ? _estimatorDays.toDouble() : _estimatorHours.toDouble(),
                            min: _estimatorMode == 'daily' ? 1 : 12,
                            max: _estimatorMode == 'daily' ? 14 : 24,
                            divisions: _estimatorMode == 'daily' ? 13 : 12,
                            activeColor: AppColors.primary,
                            inactiveColor: const Color(0x22FFFFFF),
                            onChanged: (val) {
                              setState(() {
                                if (_estimatorMode == 'daily') {
                                  _estimatorDays = val.toInt();
                                } else {
                                  _estimatorHours = val.toInt();
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          // Driver Toggle
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Hire a Professional Driver', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                            subtitle: const Text('PHP 1,500.00 / day. (Doorstep delivery included free with driver)', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            value: _estimatorWithDriver,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) => setState(() => _estimatorWithDriver = val),
                          ),

                          // Doorstep Delivery Toggle (Self-Drive only)
                          if (!_estimatorWithDriver) ...[
                            const SizedBox(height: 6),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Doorstep Delivery (Self-Drive)', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                              subtitle: const Text('PHP 75.00 / km anywhere in Pangasinan', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              value: _estimatorDoorstepDelivery,
                              activeThumbColor: AppColors.primary,
                              onChanged: (val) => setState(() => _estimatorDoorstepDelivery = val),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Right Column: Live Price Breakdown
                    SizedBox(
                      width: widget.isDesktop ? 380 : double.infinity,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06142E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ESTIMATED SUMMARY', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const SizedBox(height: 16),
                            _buildBreakdownRow('Rental Class', _estimatorVehicleType),
                            _buildBreakdownRow('Mode', _estimatorMode == 'daily' ? '$_estimatorDays Day(s)' : '$_estimatorHours Hours'),
                            if (_estimatorWithDriver)
                              _buildBreakdownRow('Driver Fee', '₱${(PricingPolicy.driverDailyRate * (_estimatorMode == 'daily' ? _estimatorDays : 1)).toStringAsFixed(2)}'),
                            if (_estimatorDoorstepDelivery && !_estimatorWithDriver)
                              _buildBreakdownRow('Delivery Fee (~10km)', '₱${(10 * PricingPolicy.deliveryRatePerKm).toStringAsFixed(2)}'),
                            const Divider(color: Color(0x22FFFFFF), height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total Estimated Rental Cost',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₱${_calculatedEstimate.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: widget.onProceedToBook,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: const Color(0xFF030A18),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Proceed to Book in Mobile App', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
