// Care-level colours (SPEC §7.2; design/tokens.json "care/*" and "pin/*").

import 'package:flutter/widgets.dart';

import '../data/patient.dart';
import '../theme/tokens.dart';

class CareStyle {
  const CareStyle._({
    required this.dot,
    required this.badgeText,
    required this.badgeBackground,
    required this.pin,
  });

  /// Full-strength colour: the badge dot and legend swatch.
  final Color dot;

  /// Badge label colour.
  final Color badgeText;

  /// Badge fill: [dot] at the tint opacity.
  final Color badgeBackground;

  /// Map pin colour for an active patient of this care level.
  final Color pin;

  static final _styles = {
    CareLevel.bedridden: CareStyle._(
      dot: AppColors.careBedridden,
      badgeText: AppColors.careBedriddenText,
      badgeBackground: AppColors.careBedridden.withValues(
        alpha: AppColors.careBedriddenOpacityTintBg,
      ),
      pin: AppColors.pinBedridden,
    ),
    CareLevel.homebound: CareStyle._(
      dot: AppColors.careHomebound,
      badgeText: AppColors.careHomeboundText,
      badgeBackground: AppColors.careHomebound.withValues(
        alpha: AppColors.careHomeboundOpacityTintBg,
      ),
      pin: AppColors.pinHomebound,
    ),
    CareLevel.social: CareStyle._(
      dot: AppColors.careSocial,
      badgeText: AppColors.careSocialText,
      badgeBackground: AppColors.careSocial.withValues(
        alpha: AppColors.careSocialOpacityTintBg,
      ),
      pin: AppColors.pinSocial,
    ),
  };

  static CareStyle of(CareLevel level) => _styles[level]!;

  /// Pin colour by care level, not age; grey for moved or deceased.
  static Color pinColorFor(Patient p) =>
      p.status.isInactive ? AppColors.pinInactive : of(p.careLevel).pin;
}
