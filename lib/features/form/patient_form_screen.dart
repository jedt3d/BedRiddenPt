import 'package:flutter/cupertino.dart';

import '../../app/placeholder_body.dart';

/// Add / Edit form (SPEC §7.3), pushed on the root navigator (no tab bar).
/// [patientId] null = Add, prefilled from
/// `AppScope.of(context).patients.nextUnusedPoolRecord()` (empty with a
/// banner when it returns null); otherwise Edit that patient. Save with
/// `insert(patient, registeredBy: AppScope.of(context).volunteer.name!)` or
/// `update(patient)`; both throw `DuplicateNationalIdException`.
/// Owner: Form stream. Placeholder until built.
class PatientFormScreen extends StatelessWidget {
  const PatientFormScreen({super.key, this.patientId});

  final String? patientId;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(patientId == null ? 'New patient' : 'Edit patient'),
      ),
      child: PlaceholderBody(
        patientId == null
            ? 'Add form (placeholder)'
            : 'Edit form for $patientId (placeholder)',
      ),
    );
  }
}
