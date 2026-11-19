// The tinted care-level badge, shared by Detail and the form (moved from
// lib/features/detail/detail_screen.dart).

import 'package:flutter/cupertino.dart';

import '../data/patient.dart';
import '../theme/tokens.dart';
import 'care_style.dart';
import 'labels.dart';

/// The tinted care-level badge with a dot, e.g. "● Bedridden".
class CareLevelBadge extends StatelessWidget {
  const CareLevelBadge({super.key, required this.level});

  final CareLevel level;

  @override
  Widget build(BuildContext context) {
    final style = CareStyle.of(level);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.badgeBackground,
        borderRadius: BorderRadius.circular(AppRadius.full),
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
              child: const SizedBox(width: AppSpace.s6, height: AppSpace.s6),
            ),
            const SizedBox(width: AppSpace.s4),
            // Shrinks with an ellipsis when its row is tight (large text).
            Flexible(
              child: Text(
                level.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.footnoteEmphasized.copyWith(
                  color: style.badgeText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
