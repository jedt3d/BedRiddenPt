import 'package:flutter/cupertino.dart';

import '../../app/placeholder_body.dart';
import '../../app/routes.dart';

/// The List tab of Home (SPEC §7.2): search, filters, Show inactive
/// (`AppScope.of(context).showInactive`, shared with the Map), swipe to
/// Deceased / Restore. A row opens [Routes.openDetail]; + opens
/// [Routes.openAdd].
/// Owner: List stream. Placeholder until built.
class ListTab extends StatelessWidget {
  const ListTab({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Patients')),
      child: PlaceholderBody(
        'Patient list (placeholder)',
        actions: {'Add patient': () => Routes.openAdd(context)},
      ),
    );
  }
}
