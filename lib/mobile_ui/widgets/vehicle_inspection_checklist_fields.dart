import 'package:flutter/material.dart';

import '../../services/booking_inspection_service.dart';

class VehicleInspectionChecklistFields extends StatelessWidget {
  final Map<String, bool> values;
  final ValueChanged<MapEntry<String, bool>> onChanged;
  final bool isDark;

  const VehicleInspectionChecklistFields({
    super.key,
    required this.values,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final completed = BookingInspectionService.requiredChecklistKeys
        .where((key) => values[key] == true)
        .length;
    final total = BookingInspectionService.requiredChecklistKeys.length;
    final textColor = isDark ? Colors.white : const Color(0xFF10233B);
    final mutedColor = isDark ? Colors.white60 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Unit condition checklist',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$completed / $total checked',
              style: TextStyle(
                color: completed == total
                    ? const Color(0xFF18C78C)
                    : mutedColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Confirm every item and document the vehicle with at least one photo or video.',
          style: TextStyle(color: mutedColor, fontSize: 12),
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
                        onChanged: (checked) =>
                            onChanged(MapEntry(item.key, checked == true)),
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
