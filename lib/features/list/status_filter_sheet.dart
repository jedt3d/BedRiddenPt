// The Status filter action sheet (SPEC §7.2, Figma frame 08).

import 'package:flutter/cupertino.dart';

import '../../data/patient.dart';
import '../../shared/labels.dart';
import '../../theme/tokens.dart';

/// The statuses the sheet offers while Show inactive is off.
bool statusSelectable(PatientStatus status, {required bool showInactive}) =>
    showInactive || !status.isInactive;

/// Shows "All statuses / Active / In hospital / Moved / Deceased". Moved and
/// Deceased can be picked only while [showInactive]; otherwise they are
/// greyed out and do nothing. Calls [onSelected] with the choice (null =
/// all statuses); Cancel calls nothing.
Future<void> showStatusFilterSheet(
  BuildContext context, {
  required PatientStatus? selected,
  required bool showInactive,
  required ValueChanged<PatientStatus?> onSelected,
}) {
  Widget label(String text, {required bool isSelected, bool enabled = true}) {
    final style = enabled
        ? null
        : const TextStyle(color: AppColors.labelInactive);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: style),
        if (isSelected) ...[
          const SizedBox(width: AppSpace.s6),
          const Icon(CupertinoIcons.checkmark_alt, semanticLabel: 'Selected'),
        ],
      ],
    );
  }

  return showCupertinoModalPopup<void>(
    context: context,
    builder: (sheet) => CupertinoActionSheet(
      title: const Text('Filter by status'),
      message: const Text(
        'Moved and Deceased appear only while Show inactive is on.',
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(sheet);
            onSelected(null);
          },
          child: label('All statuses', isSelected: selected == null),
        ),
        for (final status in PatientStatus.values)
          if (statusSelectable(status, showInactive: showInactive))
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheet);
                onSelected(status);
              },
              child: label(status.label, isSelected: selected == status),
            )
          else
            CupertinoActionSheetAction(
              onPressed: () {}, // greyed out: needs Show inactive
              child: label(status.label, isSelected: false, enabled: false),
            ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(sheet),
        child: const Text('Cancel'),
      ),
    ),
  );
}
