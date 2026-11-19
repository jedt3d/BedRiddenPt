import 'package:flutter/cupertino.dart';

import '../theme/tokens.dart';

/// Stand-in content for a screen that a feature stream hasn't built yet.
/// Delete its use when the real screen lands.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody(this.label, {super.key, this.actions = const {}});

  final String label;

  /// Button label → what it does.
  final Map<String, VoidCallback> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.body.copyWith(color: AppColors.labelSecondary),
            ),
            const SizedBox(height: AppSpace.s16),
            for (final MapEntry(:key, :value) in actions.entries)
              CupertinoButton(onPressed: value, child: Text(key)),
          ],
        ),
      ),
    );
  }
}
