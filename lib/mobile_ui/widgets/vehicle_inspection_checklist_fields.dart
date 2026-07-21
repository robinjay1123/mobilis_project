import 'package:flutter/material.dart';

import '../../services/booking_inspection_service.dart';

class VehicleInspectionChecklistFields extends StatelessWidget {
  final Map<String, bool> values;
  final ValueChanged<MapEntry<String, bool>>? onChanged;
  final ValueChanged<bool>? onSelectAll;
  final bool isDark;
  final bool readOnly;

  const VehicleInspectionChecklistFields({
    super.key,
    required this.values,
    this.onChanged,
    this.onSelectAll,
    required this.isDark,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final completed = BookingInspectionService.requiredChecklistKeys
        .where((key) => values[key] == true)
        .length;
    final total = BookingInspectionService.requiredChecklistKeys.length;
    final allChecked = completed == total;
    final textColor = isDark ? Colors.white : const Color(0xFF10233B);
    final mutedColor = isDark ? Colors.white60 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1E32) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: allChecked
                  ? const Color(0xFF18C78C)
                  : const Color(0xFFFFD400).withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD400).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: Color(0xFFFFD400),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit Releasing Checklist',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$completed of $total inspection points confirmed',
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (!readOnly && onSelectAll != null)
                    TextButton.icon(
                      onPressed: () => onSelectAll!(!allChecked),
                      icon: Icon(
                        allChecked
                            ? Icons.remove_done_outlined
                            : Icons.done_all_rounded,
                        size: 18,
                      ),
                      label: Text(allChecked ? 'Clear All' : 'Select All'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFFD400),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: total == 0 ? 0 : completed / total,
                  color: allChecked
                      ? const Color(0xFF18C78C)
                      : const Color(0xFFFFD400),
                  backgroundColor: isDark
                      ? Colors.white10
                      : const Color(0xFFE4E9F0),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          readOnly
              ? 'This is the submitted inspection record. Saved checklist items cannot be changed.'
              : 'Confirm every item below and attach at least one clear photo or video as inspection evidence.',
          style: TextStyle(color: mutedColor, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        ...BookingInspectionService.checklistSections.entries.map(
          (section) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172337) : const Color(0xFFF6F8FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFDCE3EC),
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                iconColor: const Color(0xFFFFD400),
                collapsedIconColor: mutedColor,
                title: Text(
                  section.key,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                children: section.value.entries
                    .map(
                      (item) => CheckboxListTile(
                        value: values[item.key] == true,
                        onChanged: readOnly || onChanged == null
                            ? null
                            : (checked) => onChanged!(
                                MapEntry(item.key, checked == true),
                              ),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: const Color(0xFFFFD400),
                        checkColor: Colors.black,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: Text(
                          item.value,
                          style: TextStyle(color: textColor, fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class VehicleInspectionSupplementalFields extends StatelessWidget {
  const VehicleInspectionSupplementalFields({
    super.key,
    required this.isDark,
    required this.fuelLevelController,
    required this.tiresController,
    required this.magsController,
    required this.exteriorRemarksController,
    required this.interiorRemarksController,
    required this.autosweepBalanceController,
    required this.easytripBalanceController,
    required this.toolsRemarksController,
    required this.cleanlinessRemarksController,
    required this.otherItemsController,
    required this.othersRemarksController,
    required this.releasedByController,
    required this.receivedByController,
  });

  final bool isDark;
  final TextEditingController fuelLevelController;
  final TextEditingController tiresController;
  final TextEditingController magsController;
  final TextEditingController exteriorRemarksController;
  final TextEditingController interiorRemarksController;
  final TextEditingController autosweepBalanceController;
  final TextEditingController easytripBalanceController;
  final TextEditingController toolsRemarksController;
  final TextEditingController cleanlinessRemarksController;
  final TextEditingController otherItemsController;
  final TextEditingController othersRemarksController;
  final TextEditingController releasedByController;
  final TextEditingController receivedByController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _section('Exterior details', [
          _field(tiresController, 'Tires *', 'Condition, pressure, or notes'),
          _field(magsController, 'Mags *', 'Condition or identifying notes'),
          _field(
            exteriorRemarksController,
            'Exterior remarks',
            'Describe scratches, dents, engine bay, or other findings',
            maxLines: 2,
          ),
        ]),
        _section('Interior', [
          _field(
            interiorRemarksController,
            'Interior remarks',
            'Add interior findings or write Good',
            maxLines: 2,
          ),
        ]),
        _section('Tools & Accessories', [
          _field(
            autosweepBalanceController,
            'Autosweep balance',
            'Enter balance or N/A',
          ),
          _field(
            easytripBalanceController,
            'Easytrip balance',
            'Enter balance or N/A',
          ),
          _field(
            toolsRemarksController,
            'Tools & accessories remarks',
            'Add findings or write Good',
            maxLines: 2,
          ),
        ]),
        _section('Cleanliness', [
          _field(
            cleanlinessRemarksController,
            'Cleanliness remarks',
            'Add findings or write Good',
            maxLines: 2,
          ),
        ]),
        _section('Others', [
          _field(
            fuelLevelController,
            'Fuel level *',
            'For example: Full or 75%',
          ),
          _field(otherItemsController, 'Other item', 'Specify item or N/A'),
          _field(
            othersRemarksController,
            'Other remarks',
            'Add findings or write Good',
            maxLines: 2,
          ),
        ]),
        _section('Handover', [
          _field(releasedByController, 'Released By *', 'Full name'),
          _field(receivedByController, 'Received By (Client) *', 'Full name'),
        ]),
      ],
    );
  }

  Widget _section(String title, List<Widget> fields) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172337) : const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFDCE3EC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF10233B),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...fields,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF10233B),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: isDark ? const Color(0xFF0D1E32) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
