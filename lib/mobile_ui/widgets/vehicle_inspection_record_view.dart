import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'vehicle_inspection_checklist_fields.dart';

Future<void> showVehicleInspectionRecordDialog(
  BuildContext context, {
  required Map<String, dynamic> record,
  required String title,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF18C78C),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                child: VehicleInspectionRecordView(
                  record: record,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class VehicleInspectionRecordView extends StatelessWidget {
  const VehicleInspectionRecordView({
    super.key,
    required this.record,
    required this.isDark,
  });

  final Map<String, dynamic> record;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final rawItems = record['checklist_items'];
    final checklist = rawItems is Map
        ? rawItems.map((key, value) => MapEntry(key.toString(), value == true))
        : <String, bool>{};
    final evidence = (record['evidence_urls'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    final rawRemarks = record['section_remarks'];
    final sectionRemarks = rawRemarks is Map
        ? Map<String, dynamic>.from(rawRemarks)
        : <String, dynamic>{};
    final textColor = isDark ? Colors.white : const Color(0xFF10233B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VehicleInspectionChecklistFields(
            values: checklist,
            isDark: isDark,
            readOnly: true,
          ),
          const SizedBox(height: 4),
          _sectionTitle('Recorded release details', textColor),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _recordTile('Fuel level', record['fuel_level']),
              _recordTile('Tires', record['tires_details']),
              _recordTile('Mags', record['mags_details']),
              _recordTile('Autosweep balance', record['autosweep_balance']),
              _recordTile('Easytrip balance', record['easytrip_balance']),
              _recordTile('Other items', record['other_items']),
              _recordTile('Released by', record['released_by']),
              _recordTile('Received by', record['received_by']),
            ],
          ),
          const SizedBox(height: 14),
          _sectionTitle('Section remarks', textColor),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _recordTile('Exterior', sectionRemarks['exterior']),
              _recordTile('Interior', sectionRemarks['interior']),
              _recordTile(
                'Tools & accessories',
                sectionRemarks['tools_accessories'],
              ),
              _recordTile('Cleanliness', sectionRemarks['cleanliness']),
              _recordTile('Others', sectionRemarks['others']),
            ],
          ),
          if (record['remarks']?.toString().trim().isNotEmpty == true) ...[
            const SizedBox(height: 14),
            _recordTile('Remarks', record['remarks'], wide: true),
          ],
          const SizedBox(height: 18),
          _sectionTitle('Evidence (${evidence.length})', textColor),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: evidence
                .asMap()
                .entries
                .map(
                  (entry) => Chip(
                    avatar: const Icon(
                      Icons.attach_file_rounded,
                      size: 17,
                      color: AppColors.primary,
                    ),
                    label: Text('Evidence ${entry.key + 1}'),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String label, Color color) => Text(
    label,
    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800),
  );

  Widget _recordTile(String label, Object? value, {bool wide = false}) {
    final display = value?.toString().trim();
    return Container(
      width: wide ? double.infinity : 210,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172337) : const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            display == null || display.isEmpty ? 'Not provided' : display,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF10233B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
