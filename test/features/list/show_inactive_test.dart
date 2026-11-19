// Issue #13: the Show inactive switch (SPEC §7.2, Figma frames 07 and 11).

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/features/list/patient_row.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  Set<String> shownIds(WidgetTester tester) => {
    for (final r in tester.widgetList<PatientRow>(find.byType(PatientRow)))
      r.patient.id,
  };

  /// 5 seeded patients; then one is moved and one deceased.
  Future<(ListHarness, Patient, Patient)> pumpWithInactive(
    WidgetTester tester,
  ) async {
    final h = await pumpListTab(tester);
    final [moved, deceased, ..._] = await h.db(() => h.repo.list());
    await h.db(
      () => h.repo.update(moved.copyWith(status: PatientStatus.moved)),
    );
    await h.db(() => h.repo.markDeceased(deceased.id));
    return (h, moved, deceased);
  }

  CupertinoSwitch theSwitch(WidgetTester tester) =>
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));

  testWidgets('off by default; toggling shows and hides moved and deceased '
      'patients, through the notifier the Map tab shares', (tester) async {
    final (h, moved, deceased) = await pumpWithInactive(tester);
    expect(find.text('Show inactive'), findsOneWidget);
    expect(theSwitch(tester).value, isFalse);
    expect(h.showInactive.value, isFalse);
    expect(shownIds(tester), hasLength(3));
    expect(shownIds(tester), isNot(contains(moved.id)));
    expect(shownIds(tester), isNot(contains(deceased.id)));
    expect(find.text('3 PATIENTS · 2 INACTIVE HIDDEN'), findsOneWidget);

    await tester.tap(find.byType(CupertinoSwitch));
    await h.settle();
    expect(h.showInactive.value, isTrue); // AppScope.showInactive → Map
    expect(theSwitch(tester).value, isTrue);
    expect(shownIds(tester), hasLength(5));
    expect(shownIds(tester), containsAll([moved.id, deceased.id]));
    expect(find.text('5 PATIENTS · INCLUDING 2 INACTIVE'), findsOneWidget);

    await tester.tap(find.byType(CupertinoSwitch));
    await h.settle();
    expect(h.showInactive.value, isFalse);
    expect(shownIds(tester), hasLength(3));
  });

  testWidgets('follows the shared notifier when it changes elsewhere', (
    tester,
  ) async {
    final (h, moved, _) = await pumpWithInactive(tester);
    h.showInactive.value = true; // e.g. set while on the Map tab
    await h.settle();
    expect(theSwitch(tester).value, isTrue);
    expect(shownIds(tester), contains(moved.id));
  });

  testWidgets('turning it off clears a Moved or Deceased status filter', (
    tester,
  ) async {
    final (h, moved, _) = await pumpWithInactive(tester);
    await tester.tap(find.byType(CupertinoSwitch));
    await h.settle();

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoActionSheet),
        matching: find.text('Moved'),
      ),
    );
    await h.settle();
    expect(shownIds(tester), {moved.id});

    await tester.tap(find.byType(CupertinoSwitch));
    await h.settle();
    expect(shownIds(tester), hasLength(3)); // all active ones, not nothing
    final statusValue = find.descendant(
      of: find.ancestor(of: find.text('Status'), matching: find.byType(Row)),
      matching: find.text('All'),
    );
    expect(statusValue, findsOneWidget);
  });

  testWidgets('turning it off keeps an Active or In hospital filter', (
    tester,
  ) async {
    final (h, _, _) = await pumpWithInactive(tester);
    await tester.tap(find.byType(CupertinoSwitch));
    await h.settle();
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoActionSheet),
        matching: find.text('Active'),
      ),
    );
    await h.settle();
    await tester.tap(find.byType(CupertinoSwitch));
    await h.settle();
    expect(shownIds(tester), hasLength(3));
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('Status'), matching: find.byType(Row)),
        matching: find.text('Active'),
      ),
      findsOneWidget,
    );
  });
}
