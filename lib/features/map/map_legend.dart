import 'package:flutter/cupertino.dart';

import '../../data/patient.dart';
import '../../shared/care_style.dart';
import '../../theme/tokens.dart';
import 'map_pin.dart';

/// "COLOR LEGEND" below the map (SPEC §7.2, Figma frame 16): one row per pin
/// colour with its meaning and how many patients have that colour. While
/// Show inactive is off the grey row reads "N hidden".
class MapLegend extends StatelessWidget {
  const MapLegend({
    super.key,
    required this.patients,
    required this.showInactive,
  });

  /// Every patient, inactive included.
  final List<Patient> patients;
  final bool showInactive;

  static const _meanings = {
    CareLevel.bedridden: (
      'Red: bedridden',
      'ADL 0–4. Needs help with almost everything.',
    ),
    CareLevel.homebound: (
      'Orange: homebound',
      'ADL 5–11. Needs help with some daily tasks; rarely leaves home.',
    ),
    CareLevel.social: (
      'Green: social',
      'ADL 12–20. Independent; registered because care levels change.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final active = patients.where((p) => !p.status.isInactive);
    final inactive = patients.length - active.length;
    final rows = [
      for (final MapEntry(key: level, value: (title, meaning))
          in _meanings.entries)
        _LegendRow(
          color: CareStyle.of(level).pin,
          title: title,
          meaning: meaning,
          count: '${active.where((p) => p.careLevel == level).length}',
        ),
      _LegendRow(
        color: AppColors.pinInactive,
        title: 'Grey: inactive',
        meaning: 'Moved or deceased. Hidden while Show inactive is off.',
        count: showInactive ? '$inactive' : '$inactive hidden',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s20,
        AppSpace.s16,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpace.s16,
              bottom: AppSpace.s8,
            ),
            child: Text(
              'COLOR LEGEND',
              style: AppText.footnote.copyWith(color: AppColors.labelSecondary),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(
                              top: BorderSide(
                                color: AppColors.separatorDefault.withValues(
                                  alpha: AppColors.separatorDefaultOpacity,
                                ),
                                width: 0, // hairline
                              ),
                            ),
                    ),
                    child: rows[i],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.title,
    required this.meaning,
    required this.count,
  });

  final Color color;
  final String title;
  final String meaning;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s10,
      ),
      child: Row(
        children: [
          MapPin(color: color),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.headline.copyWith(
                    color: AppColors.labelPrimary,
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  meaning,
                  style: AppText.footnote.copyWith(
                    color: AppColors.labelSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Text(
            count,
            style: AppText.body.copyWith(color: AppColors.labelSecondary),
          ),
        ],
      ),
    );
  }
}
