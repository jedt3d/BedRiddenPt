import 'package:flutter/cupertino.dart';

import '../../app/placeholder_body.dart';
import '../../app/routes.dart';

/// Patient detail (SPEC §7.4), pushed on the root navigator (no tab bar):
/// all fields, a small map, Call, Navigate and one Edit button
/// ([Routes.openEdit]). Load with `AppScope.of(context).patients.getById`.
/// Owner: Detail stream. Placeholder until built.
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Patient')),
      child: PlaceholderBody(
        'Detail of $patientId (placeholder)',
        actions: {'Edit': () => Routes.openEdit(context, patientId)},
      ),
    );
  }
}
