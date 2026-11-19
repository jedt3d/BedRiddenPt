// Form (SPEC §7.3, Figma frame 25) #24: a deceased patient's status is
// read-only with a lock; the form can't change it (restore is by swipe).

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/features/form/patient_form_screen.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  testWidgets('Deceased shows read-only with a lock and no status picker', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.db(() => h.repo.markDeceased(p.id));
    await h.openEdit(p.id);

    await h.scrollTo(find.text(deceasedStatusHint));
    expect(find.text('Deceased'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.lock_fill), findsOneWidget);
    expect(
      find.byType(CupertinoSlidingSegmentedControl<PatientStatus>),
      findsNothing,
    );
    expect(find.text('In hospital'), findsNothing);
    expect(find.text('Moved'), findsNothing);
    expect(find.text('Restore to active'), findsNothing);
    expect(find.textContaining('Restore'), findsNothing);
  });

  testWidgets('Saving an edit keeps the patient deceased', (tester) async {
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.db(() => h.repo.markDeceased(p.id));
    await h.openEdit(p.id);

    await h.enter('Full name', 'Renamed After Death');
    await h.save();

    expect(find.byType(PatientFormScreen), findsNothing);
    final saved = (await h.db(() => h.repo.getById(p.id)))!;
    expect(saved.fullName, 'Renamed After Death');
    expect(saved.status, PatientStatus.deceased);
  });

  testWidgets('A moved patient still gets the three-way picker', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.db(() => h.repo.update(p.copyWith(status: PatientStatus.moved)));
    await h.openEdit(p.id);
    await h.scrollTo(find.text('Moved'));
    final control = tester
        .widget<CupertinoSlidingSegmentedControl<PatientStatus>>(
          find.byType(CupertinoSlidingSegmentedControl<PatientStatus>),
        );
    expect(control.groupValue, PatientStatus.moved);
    expect(find.byIcon(CupertinoIcons.lock_fill), findsNothing);
  });
}
