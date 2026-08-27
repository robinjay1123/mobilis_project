import 'package:flutter/material.dart';
import '../../services/partner_service.dart';

class PartnerVehicleMaintenanceModal extends StatefulWidget {
  final String vehicleId;
  final String vehicleName;

  const PartnerVehicleMaintenanceModal({
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
      builder: (context) => PartnerVehicleMaintenanceModal(
        vehicleId: vehicleId,
        vehicleName: vehicleName,
      ),
    );
  }

  @override
  State<PartnerVehicleMaintenanceModal> createState() =>
      _PartnerVehicleMaintenanceModalState();
}

class _PartnerVehicleMaintenanceModalState
    extends State<PartnerVehicleMaintenanceModal> {
  final PartnerService _partnerService = PartnerService();

  final TextEditingController _currentOdometerController =
      TextEditingController();
  final TextEditingController _nextServiceOdometerController =
      TextEditingController();
  final TextEditingController _oilChangeDateController =
      TextEditingController();
  final TextEditingController _ltoRegistrationDateController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _healthStatus = 'good';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings =
          await _partnerService.getVehicleMaintenanceSettings(widget.vehicleId);
      final health = _partnerService.evaluateMaintenanceHealth(settings);

      if (mounted) {
        setState(() {
          final curOdo =
              (settings['current_odometer_km'] as num?)?.toDouble() ?? 0.0;
          final nextOdo =
              (settings['next_service_odometer_km'] as num?)?.toDouble() ??
                  (curOdo + 5000.0);

          _currentOdometerController.text =
              curOdo > 0 ? curOdo.toStringAsFixed(0) : '';
          _nextServiceOdometerController.text =
              nextOdo > 0 ? nextOdo.toStringAsFixed(0) : '';

          _oilChangeDateController.text =
              settings['oil_change_due_date']?.toString() ?? '';
          _ltoRegistrationDateController.text =
              settings['lto_registration_due_date']?.toString() ?? '';
          _notesController.text = settings['notes']?.toString() ?? '';

          _healthStatus = health;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final curOdo =
          double.tryParse(_currentOdometerController.text.trim()) ?? 0.0;
      final nextOdo =
          double.tryParse(_nextServiceOdometerController.text.trim()) ??
              (curOdo + 5000.0);

      await _partnerService.updateVehicleMaintenanceSettings(
        vehicleId: widget.vehicleId,
        currentOdometerKm: curOdo,
        nextServiceOdometerKm: nextOdo,
        oilChangeDueDate: _oilChangeDateController.text.trim().isNotEmpty
            ? _oilChangeDateController.text.trim()
            : null,
        ltoRegistrationDueDate:
            _ltoRegistrationDateController.text.trim().isNotEmpty
                ? _ltoRegistrationDateController.text.trim()
                : null,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Vehicle maintenance updated successfully!'),
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
            content: Text('Failed to update maintenance: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      final formatted =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() => controller.text = formatted);
    }
  }

  @override
  void dispose() {
    _currentOdometerController.dispose();
    _nextServiceOdometerController.dispose();
    _oilChangeDateController.dispose();
    _ltoRegistrationDateController.dispose();
    _notesController.dispose();
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
                  color: _healthStatus == 'overdue'
                      ? const Color(0xFFFEE2E2)
                      : _healthStatus == 'due_soon'
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _healthStatus == 'overdue'
                      ? Icons.warning_rounded
                      : _healthStatus == 'due_soon'
                          ? Icons.build_circle_rounded
                          : Icons.verified_rounded,
                  color: _healthStatus == 'overdue'
                      ? const Color(0xFFDC2626)
                      : _healthStatus == 'due_soon'
                          ? const Color(0xFFD97706)
                          : const Color(0xFF16A34A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehicle Maintenance & Reminders',
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
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // Status Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _healthStatus == 'overdue'
                    ? const Color(0xFFFEF2F2)
                    : _healthStatus == 'due_soon'
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _healthStatus == 'overdue'
                      ? const Color(0xFFFECACA)
                      : _healthStatus == 'due_soon'
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _healthStatus == 'good'
                        ? Icons.check_circle
                        : Icons.info_outline,
                    color: _healthStatus == 'overdue'
                        ? const Color(0xFFDC2626)
                        : _healthStatus == 'due_soon'
                            ? const Color(0xFFD97706)
                            : const Color(0xFF16A34A),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _healthStatus == 'overdue'
                          ? 'SERVICE OVERDUE: Vehicle service or LTO renewal is past due.'
                          : _healthStatus == 'due_soon'
                              ? 'SERVICE DUE SOON: Inspection or renewal date approaching.'
                              : 'HEALTHY: All vehicle maintenance schedules are up to date.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _healthStatus == 'overdue'
                            ? const Color(0xFF991B1B)
                            : _healthStatus == 'due_soon'
                                ? const Color(0xFF92400E)
                                : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Odometer & Next Service Target
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: [
                      const Text('Current Odometer (km)',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _currentOdometerController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. 45000',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: [
                      const Text('Next Service Target (km)',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nextServiceOdometerController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. 50000',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Oil Change & LTO Dates
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: [
                      const Text('Oil Change Due Date',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _oilChangeDateController,
                        readOnly: true,
                        onTap: () => _selectDate(_oilChangeDateController),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'YYYY-MM-DD',
                          suffixIcon: const Icon(Icons.calendar_month,
                              size: 18, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: [
                      const Text('LTO Registration Due',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _ltoRegistrationDateController,
                        readOnly: true,
                        onTap: () =>
                            _selectDate(_ltoRegistrationDateController),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'YYYY-MM-DD',
                          suffixIcon: const Icon(Icons.event,
                              size: 18, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            const Text('Maintenance Log & Remarks',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Synthetic oil changed at 45,000 km. Tires rotated.',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
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
                        'Save Maintenance Log',
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
