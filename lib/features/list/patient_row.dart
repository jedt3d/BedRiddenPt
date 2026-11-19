// One row of the patient list (SPEC §7.2, Figma frames 07 and 11):
// photo, name, sex + age + subdistrict, care-level badge, status.

import 'package:flutter/cupertino.dart';

import '../../data/patient.dart';
import '../../shared/care_style.dart';
import '../../shared/labels.dart';
import '../../shared/patient_avatar.dart';
import '../../theme/tokens.dart';

/// Photo diameter (Figma "Photo", 52 × 52).
const _photoSize = 52.0;

/// Opacity of an inactive patient's photo (Figma "Photo", opacity 50%).
const _inactivePhotoOpacity = 0.5;

/// The care-level badge dot (Figma "dot", 7 × 7).
const _dotSize = AppSpace.s7;

/// Chevron height (Figma "Chevron", 8 × 14).
const _chevronSize = AppSpace.s14;

/// "Somdet Chao Phraya Subdistrict" → "Somdet Chao Phraya" (Figma meta line).
String shortSubdistrict(String subdistrict) =>
    subdistrict.replaceFirst(RegExp(r' Subdistrict$'), '');

class PatientRow extends StatelessWidget {
  const PatientRow({
    super.key,
    required this.patient,
    required this.currentYear,
    this.onTap,
  });

  final Patient patient;

  /// Age = [currentYear] − birth year (Gregorian).
  final int currentYear;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = patient.status.isInactive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          border: Border(
            bottom: BorderSide(
              width: 0,
              color: AppColors.separatorDefault.withValues(
                alpha: AppColors.separatorDefaultOpacity,
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s10,
            AppSpace.s14,
            AppSpace.s10,
          ),
          child: Row(
            children: [
              Opacity(
                opacity: inactive ? _inactivePhotoOpacity : 1,
                child: PatientAvatar(patient: patient, size: _photoSize),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(child: _text(inactive)),
              const SizedBox(width: AppSpace.s12),
              const Icon(
                CupertinoIcons.chevron_forward,
                size: _chevronSize,
                color: AppColors.labelQuaternary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _text(bool inactive) {
    final male = patient.sex == Sex.male;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          patient.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.headline.copyWith(
            color: inactive ? AppColors.labelInactive : AppColors.labelPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        Row(
          children: [
            // No ♀/♂ in CupertinoIcons; the symbol is text in the sex colour.
            Semantics(
              label: patient.sex.label,
              child: ExcludeSemantics(
                child: Text(
                  male ? '♂' : '♀',
                  style: AppText.rowMeta.copyWith(
                    color: male ? AppColors.sexMale : AppColors.sexFemale,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s4),
            Expanded(
              child: Text(
                '${patient.ageIn(currentYear)} yrs · '
                '${shortSubdistrict(patient.subdistrict)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowMeta.copyWith(
                  color: AppColors.labelSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        Row(
          children: [
            CareBadge(level: patient.careLevel),
            const SizedBox(width: AppSpace.s8),
            Flexible(
              child: Text(
                patient.status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.footnote.copyWith(
                  color: patient.status == PatientStatus.inHospital
                      ? AppColors.statusInHospital
                      : AppColors.labelSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The care-level pill: a dot and the label on a tint (Figma "Care level badge").
class CareBadge extends StatelessWidget {
  const CareBadge({super.key, required this.level});

  final CareLevel level;

  @override
  Widget build(BuildContext context) {
    final style = CareStyle.of(level);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.badgeBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: style.dot,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: _dotSize),
            ),
            const SizedBox(width: AppSpace.s5),
            Text(
              level.label,
              style: AppText.footnoteEmphasized.copyWith(
                color: style.badgeText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
