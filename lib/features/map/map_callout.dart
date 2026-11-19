import 'package:flutter/cupertino.dart';

import '../../data/patient.dart';
import '../../shared/labels.dart';
import '../../theme/tokens.dart';

/// The name callout above a tapped pin (SPEC §7.2, Figma frame 15): the name
/// in accent with a chevron, then "Bedridden · 73 yrs · Active". Tapping it
/// calls [onTap] (open Detail).
class MapCallout extends StatelessWidget {
  const MapCallout({super.key, required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  /// "Bedridden · 73 yrs · Active".
  static String summary(Patient p, int year) =>
      '${p.careLevel.label} · ${p.ageIn(year)} yrs · ${p.status.label}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              color: AppColors.overlayDim.withValues(
                alpha: AppColors.overlayDimOpacity,
              ),
              offset: const Offset(0, AppSpace.s2),
              blurRadius: AppSpace.s10,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpace.s12,
            right: AppSpace.s10,
            top: AppSpace.s8,
            bottom: AppSpace.s8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      patient.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.subheadlineEmphasized.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s6),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: AppSpace.s12,
                    color: AppColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s2),
              Text(
                summary(patient, DateTime.now().year),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption1.copyWith(
                  color: AppColors.labelSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
