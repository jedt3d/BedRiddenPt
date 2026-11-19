import 'package:flutter/cupertino.dart';

import '../../app/placeholder_body.dart';
import '../../app/routes.dart';

/// "Your name", first launch only (SPEC §7.1). Saves the name with
/// `AppScope.of(context).volunteer.setName`, then goes to [Routes.pin].
/// Owner: Launch stream. Placeholder until built.
class NameScreen extends StatelessWidget {
  const NameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Your name')),
      child: PlaceholderBody(
        'Your name (placeholder)',
        actions: {'Continue': () => Routes.replaceAllWith(context, Routes.pin)},
      ),
    );
  }
}
