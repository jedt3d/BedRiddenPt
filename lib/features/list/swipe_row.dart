// Swipe left on a row (SPEC §7.2, Figma frames 09, 10, 12, 13): Deceased for
// an active, in-hospital or moved patient; Restore for a deceased one. Built
// with Dismissible + confirmDismiss returning false, so the row stays put.

import 'package:flutter/cupertino.dart';

import '../../data/patient.dart';
import '../../data/patient_repository.dart';
import '../../theme/tokens.dart';

class SwipeRow extends StatelessWidget {
  const SwipeRow({
    super.key,
    required this.patient,
    required this.repository,
    required this.child,
  });

  final Patient patient;
  final PatientRepository repository;
  final Widget child;

  bool get _restore => patient.status == PatientStatus.deceased;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('swipe-${patient.id}'),
      direction: DismissDirection.endToStart,
      background: _background(),
      confirmDismiss: (_) async {
        await (_restore ? _confirmRestore(context) : _confirmDeceased(context));
        return false; // the row stays; the repository change reloads the list
      },
      child: child,
    );
  }

  /// Full-width colour with the action at the trailing edge.
  Widget _background() {
    final color = _restore
        ? AppColors.actionPositive
        : AppColors.actionDestructive;
    return ColoredBox(
      color: color,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _restore
                    ? CupertinoIcons.arrow_counterclockwise
                    : CupertinoIcons.person_crop_circle_badge_xmark,
                size: AppSpace.s22,
                color: AppColors.labelInverse,
              ),
              const SizedBox(height: AppSpace.s3),
              Text(
                _restore ? 'Restore' : 'Deceased',
                style: AppText.subheadlineEmphasized.copyWith(
                  color: AppColors.labelInverse,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeceased(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: 'Mark ${patient.fullName} as deceased?',
      message: 'Their pin will be hidden from the map.',
      action: 'Mark deceased',
      destructive: true,
    );
    if (ok) await repository.markDeceased(patient.id);
  }

  Future<void> _confirmRestore(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: 'Restore ${patient.fullName} to active?',
      message: 'Their pin will show on the map again.',
      action: 'Restore',
      destructive: false,
    );
    if (ok) await repository.restoreToActive(patient.id);
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    required bool destructive,
  }) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            isDefaultAction: !destructive,
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
