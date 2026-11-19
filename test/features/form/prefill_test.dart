// Form (SPEC §6 Startup 2–3, §7.3) #22: Add prefills from a random pool
// record not yet in the database; with all 50 registered it opens empty
// with a banner.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/features/form/patient_form_screen.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  String textOf(WidgetTester tester, FormHarness h, String label) =>
      tester.widget<CupertinoTextField>(h.field(label)).controller!.text;

  testWidgets('Add is prefilled from an unused pool record, with a banner', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final registered = {
      for (final p in await h.db(() => h.repo.list(showInactive: true))) p.id,
    };
    await h.openAdd();

    expect(find.text('New patient'), findsOneWidget);
    expect(find.text(prefilledBanner), findsOneWidget);
    final name = textOf(tester, h, 'Full name');
    final match = h.repo.pool.where((p) => p.fullName == name).toList();
    expect(match, hasLength(1));
    expect(registered, isNot(contains(match.single.id)));
    // Status is forced to active.
    await h.scrollTo(find.text('Active'));
    final status = tester
        .widget<CupertinoSlidingSegmentedControl<PatientStatus>>(
          find.byType(CupertinoSlidingSegmentedControl<PatientStatus>),
        )
        .groupValue;
    expect(status, PatientStatus.active);
    // Add has no Registration section.
    expect(find.text('REGISTRATION'), findsNothing);
  });

  testWidgets('Saving inserts it; the next Add shows a different one', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    await h.openAdd();
    final first = textOf(tester, h, 'Full name');
    await h.save();

    expect(find.byType(PatientFormScreen), findsNothing);
    final all = await h.db(() => h.repo.list(showInactive: true));
    expect(all, hasLength(6));
    final saved = all.singleWhere((p) => p.fullName == first);
    expect(saved.registeredBy, 'Nok');
    expect(saved.status, PatientStatus.active);
    expect(find.text(first), findsOneWidget); // in the list

    await h.openAdd();
    final second = textOf(tester, h, 'Full name');
    expect(second, isNot(first));
    expect(all.map((p) => p.fullName), isNot(contains(second)));
  });

  testWidgets('With all 50 registered, Add opens empty with the banner', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester, seedData: false);
    await h.db(() async {
      for (final p in h.repo.pool) {
        await h.repo.insert(p, registeredBy: 'Sample data');
      }
    });
    await h.openAdd();

    expect(find.text(poolUsedUpBanner), findsOneWidget);
    expect(find.text(prefilledBanner), findsNothing);
    for (final label in ['National ID', 'Full name', 'Born (B.E.)']) {
      expect(textOf(tester, h, label), isEmpty, reason: label);
    }
    expect(find.text('Required: tap Use my location'), findsOneWidget);
    expect(find.text('Set by ADL score'), findsOneWidget);
  });
}
