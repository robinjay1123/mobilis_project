import 'package:flutter/material.dart';
import '../../services/booking_inspection_service.dart';

class InspectionDamageComparisonDialog extends StatefulWidget {
  final String bookingId;
  final String? vehicleName;

  const InspectionDamageComparisonDialog({
    super.key,
    required this.bookingId,
    this.vehicleName,
  });

  static Future<void> show(
    BuildContext context, {
    required String bookingId,
    String? vehicleName,
  }) {
    return showDialog(
      context: context,
      builder: (context) => InspectionDamageComparisonDialog(
        bookingId: bookingId,
        vehicleName: vehicleName,
      ),
    );
  }

  @override
  State<InspectionDamageComparisonDialog> createState() =>
      _InspectionDamageComparisonDialogState();
}

class _InspectionDamageComparisonDialogState
    extends State<InspectionDamageComparisonDialog> {
  final BookingInspectionService _inspectionService =
      BookingInspectionService();

  Map<String, dynamic>? _beforeInspection;
  Map<String, dynamic>? _afterInspection;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  Future<void> _loadInspections() async {
    try {
      final list = await _inspectionService.getBookingInspections(widget.bookingId);
      Map<String, dynamic>? before;
      Map<String, dynamic>? after;

      for (final item in list) {
        final type = item['inspection_type']?.toString().toLowerCase().trim();
        if (type == 'before') before = item;
        if (type == 'after') after = item;
      }

      if (mounted) {
        setState(() {
          _beforeInspection = before;
          _afterInspection = after;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<String> _extractEvidenceUrls(dynamic evidence) {
    if (evidence is List) {
      return evidence.map((e) => e.toString()).where((u) => u.isNotEmpty).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final beforeEvidences = _extractEvidenceUrls(_beforeInspection?['evidence_urls']);
    final afterEvidences = _extractEvidenceUrls(_afterInspection?['evidence_urls']);

    final beforeMileage = (_beforeInspection?['mileage'] as num?)?.toDouble();
    final afterMileage = (_afterInspection?['mileage'] as num?)?.toDouble();
    final distanceDriven = (beforeMileage != null && afterMileage != null && afterMileage >= beforeMileage)
        ? (afterMileage - beforeMileage).toStringAsFixed(1)
        : null;

    final beforeFuel = _beforeInspection?['fuel_level']?.toString() ?? 'N/A';
    final afterFuel = _afterInspection?['fuel_level']?.toString() ?? 'N/A';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.compare_rounded,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inspection Damage Comparison',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        widget.vehicleName ?? 'Booking Inspection Record',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
              )
            else if (_beforeInspection == null && _afterInspection == null)
              const Expanded(
                child: Center(
                  child: Text(
                    'No inspection records found for this booking.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fuel & Mileage Variance Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TRIP METRICS & FUEL COMPARISON',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    label: 'Pre-Trip Fuel',
                                    value: beforeFuel,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Color(0xFF94A3B8), size: 18),
                                Expanded(
                                  child: _buildMetricTile(
                                    label: 'Post-Trip Fuel',
                                    value: afterFuel,
                                    color: (beforeFuel != afterFuel &&
                                            afterFuel != 'N/A')
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                            if (distanceDriven != null) ...[
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Distance Driven:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  Text(
                                    '$distanceDriven km',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Remarks & Scratches Comparison
                      _buildComparisonSection(
                        title: 'Scratches, Dents & Damages',
                        beforeText: _beforeInspection?['damages'] ??
                            _beforeInspection?['scratches'] ??
                            _beforeInspection?['dents'] ??
                            'None recorded',
                        afterText: _afterInspection?['damages'] ??
                            _afterInspection?['scratches'] ??
                            _afterInspection?['dents'] ??
                            'None recorded',
                      ),
                      const SizedBox(height: 16),

                      // Side-by-Side Photo Evidence
                      const Text(
                        'PHOTO EVIDENCE COMPARISON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildPhotoColumn(
                              title: 'Pre-Trip Photos (${beforeEvidences.length})',
                              urls: beforeEvidences,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPhotoColumn(
                              title: 'Post-Trip Photos (${afterEvidences.length})',
                              urls: afterEvidences,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Close Comparison',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonSection({
    required String title,
    required String beforeText,
    required String afterText,
  }) {
    final isDiscrepancy = beforeText != afterText;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDiscrepancy ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDiscrepancy ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDiscrepancy ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                size: 18,
                color: isDiscrepancy ? const Color(0xFFD97706) : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDiscrepancy ? const Color(0xFF92400E) : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pre-Trip:',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(beforeText,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Post-Trip:',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(afterText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isDiscrepancy ? FontWeight.bold : FontWeight.normal,
                          color: isDiscrepancy ? const Color(0xFFB45309) : const Color(0xFF334155),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoColumn({required String title, required List<String> urls}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        if (urls.isEmpty)
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No photos',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          Column(
            children: urls.map((url) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(url),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
