import 'package:flutter/cupertino.dart';

import '../../app/placeholder_body.dart';

/// The Map tab of Home (SPEC §7.2): district outline, pins coloured by care
/// level, colour legend. Uses `AppScope.of(context).showInactive` (shared
/// with the List). Tapping a pin's name opens `Routes.openDetail`.
/// Owner: Map stream. Placeholder until built.
class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Map')),
      child: PlaceholderBody('Map (placeholder)'),
    );
  }
}
