import 'package:flutter/cupertino.dart';

import '../../app/placeholder_body.dart';
import '../../app/routes.dart';

/// PIN entry, every launch (SPEC §7.1). The PIN is `appPin`
/// (lib/data/volunteer_store.dart). The top-right ⋮ menu holds Reset sample
/// data (`AppScope.of(context).patients.resetSampleData()`).
/// On success: [Routes.replaceAllWith] [Routes.home].
/// Owner: Launch stream. Placeholder until built.
class PinScreen extends StatelessWidget {
  const PinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Enter PIN')),
      child: PlaceholderBody(
        'PIN entry (placeholder)',
        actions: {'Unlock': () => Routes.replaceAllWith(context, Routes.home)},
      ),
    );
  }
}
