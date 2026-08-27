import 'package:flutter/material.dart';
import '../../services/partner_service.dart';

class PartnerDynamicPricingModal extends StatefulWidget {
  final String vehicleId;
  final String vehicleName;

  const PartnerDynamicPricingModal({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
  });

  static Future<void> show(
    BuildContext context, {
    required String vehicleId,
    required String vehicleName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PartnerDynamicPricingModal(
        vehicleId: vehicleId,
        vehicleName: vehicleName,
      ),
    );
  }

  @override
  State<PartnerDynamicPricingModal> createState() =>
      _PartnerDynamicPricingModalState();
}

class _PartnerDynamicPricingModalState
    extends State<PartnerDynamicPricingModal> {
  final PartnerService _partnerService = PartnerService();
  final TextEditingController _surchargeController = TextEditingController();

  double _weekendMultiplier = 1.0;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<double> _multiplierOptions = [1.0, 1.10, 1.15, 1.20, 1.25];

  @override
  void initState() {
    super.initState();
    _loadPricingSettings();
  }

  Future<void> _loadPricingSettings() async {
    try {
      final settings =
          await _partnerService.getVehicleDynamicPricing(widget.vehicleId);
      if (mounted) {
        setState(() {
          _weekendMultiplier =
              (settings['weekend_multiplier'] as num?)?.toDouble() ?? 1.0;
          final surcharge =
              (settings['peak_surcharge_per_day'] as num?)?.toDouble() ?? 0.0;
          _surchargeController.text =
              surcharge > 0 ? surcharge.toStringAsFixed(0) : '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePricingSettings() async {
    setState(() => _isSaving = true);
    try {
      final surcharge = double.tryParse(_surchargeController.text.trim()) ?? 0.0;
      await _partnerService.updateVehicleDynamicPricing(
        vehicleId: widget.vehicleId,
        weekendMultiplier: _weekendMultiplier,
        peakSurchargePerDay: surcharge,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Dynamic pricing updated successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update pricing: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _surchargeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seasonal & Dynamic Pricing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      widget.vehicleName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // Weekend Rate Multiplier Selection
            const Text(
              'Weekend Surge Multiplier (Saturday & Sunday)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Automatically adjust daily rate for weekend rental dates.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _multiplierOptions.map((mult) {
                final isSelected = _weekendMultiplier == mult;
                final percentage = ((mult - 1.0) * 100).toStringAsFixed(0);
                final label = mult == 1.0 ? 'Standard (0%)' : '+$percentage%';

                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _weekendMultiplier = mult);
                    }
                  },
                  selectedColor: const Color(0xFFD97706),
                  backgroundColor: const Color(0xFFF1F5F9),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFD97706)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Peak Season Daily Surcharge
            const Text(
              'Holiday / Peak Season Daily Surcharge (₱)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Optional fixed extra fee added per day during high-demand periods.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _surchargeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                prefixText: '₱ ',
                prefixStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
                hintText: 'e.g. 500',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFD97706), width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePricingSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Save Pricing Rules',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
