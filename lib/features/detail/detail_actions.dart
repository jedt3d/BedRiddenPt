// Call, Navigate and Edit on Detail (SPEC §7.4, Figma frame 17 "Actions").
// There is no Edit in the top bar; this Edit is the only one.

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../data/patient.dart';
import '../../theme/tokens.dart';

/// Opens a URL outside the app. Replaceable in tests.
Future<bool> Function(Uri uri, LaunchMode mode) detailLaunchUrl = (uri, mode) =>
    launchUrl(uri, mode: mode);

/// `tel:` for the contact person's Phone 1, or null with no phone.
Uri? callUri(Patient p) =>
    p.phones.isEmpty ? null : Uri(scheme: 'tel', path: p.phones.first);

/// Apple Maps directions to the patient's home.
Uri navigateUri(Patient p) =>
    Uri.https('maps.apple.com', '/', {'daddr': '${p.lat},${p.lng}'});

class DetailActions extends StatelessWidget {
  const DetailActions({super.key, required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final call = callUri(patient);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s20,
        vertical: AppSpace.s10,
      ),
      child: Row(
        children: [
          _ActionButton(
            icon: CupertinoIcons.phone_fill,
            label: 'Call',
            // Calls go straight to launchUrl: canLaunchUrl('tel:') would need
            // LSApplicationQueriesSchemes in Info.plist.
            onPressed: call == null
                ? null
                : () => _open(
                    context,
                    call,
                    LaunchMode.platformDefault,
                    "Can't place a call on this device.",
                  ),
          ),
          const SizedBox(width: AppSpace.s8),
          _ActionButton(
            icon: CupertinoIcons.location_fill,
            label: 'Navigate',
            // External, or iOS opens the https URL in an in-app browser.
            onPressed: () => _open(
              context,
              navigateUri(patient),
              LaunchMode.externalApplication,
              "Can't open Maps on this device.",
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          _ActionButton(
            icon: CupertinoIcons.pencil,
            label: 'Edit',
            onPressed: () => Routes.openEdit(context, patient.id),
          ),
        ],
      ),
    );
  }

  static Future<void> _open(
    BuildContext context,
    Uri uri,
    LaunchMode mode,
    String failure,
  ) async {
    bool ok;
    try {
      ok = await detailLaunchUrl(uri, mode);
    } on Exception {
      ok = false;
    }
    if (ok || !context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(failure),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// A white tile with an icon above a label; greyed out when [onPressed] is null.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? AppColors.labelQuaternary
        : AppColors.accent;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        excludeSemantics: true,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s10),
              child: Column(
                children: [
                  Icon(icon, size: AppSpace.s24, color: color),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    label,
                    style: AppText.actionLabel.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
