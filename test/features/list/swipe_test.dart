// Issue #14: swipe to mark deceased / swipe to restore (SPEC §7.2,
// Figma frames 09, 10, 12, 13).

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/features/list/patient_row.dart';
import 'package:bedridden_pt/theme/tokens.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  Finder rowOf(Patient p) => find.byKey(ValueKey(p.id));

  Future<void> swipeLeft(WidgetTester tester, Patient p) async {
    await tester.drag(rowOf(p), const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  Future<PatientStatus> statusOf(ListHarness h, Patient p) async =>
      (await h.db(() => h.repo.getById(p.id)))!.status;

  Finder inAlert(String text) => find.descendant(
    of: find.byType(CupertinoAlertDialog),
    matching: find.text(text),
  );

  testWidgets('swipe left on an active row shows a full-width red Deceased '
      'background and asks first; Cancel changes nothing', (tester) async {
    final h = await pumpListTab(tester);
    final p = (await h.db(() => h.repo.list())).first;

    final gesture = await tester.startGesture(tester.getCenter(rowOf(p)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
    }
    final bg = find.ancestor(
      of: find.text('Deceased'),
      matching: find.byType(ColoredBox),
    );
    expect(bg, findsWidgets);
    expect(
      tester.widget<ColoredBox>(bg.first).color,
      AppColors.actionDestructive,
    );
    expect(
      tester.getSize(bg.first).width,
      tester.getSize(rowOf(p)).width,
    ); // full width
    await gesture.moveBy(const Offset(-400, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(inAlert('Mark ${p.fullName} as deceased?'), findsOneWidget);
    expect(inAlert('Their pin will be hidden from the map.'), findsOneWidget);
    await tester.tap(inAlert('Cancel'));
    await h.settle();
    expect(await statusOf(h, p), PatientStatus.active);
    expect(rowOf(p), findsOneWidget);
  });

  testWidgets('Mark deceased changes the status and notifies the map', (
    tester,
  ) async {
    final h = await pumpListTab(tester);
    h.showInactive.value = true; // keep the deceased row visible
    await h.settle();
    final p = (await h.db(() => h.repo.list())).first;
    var notified = 0;
    void listener() => notified++;
    h.repo.addListener(listener);
    addTearDown(() => h.repo.removeListener(listener));

    await swipeLeft(tester, p);
    await tester.tap(inAlert('Mark deceased'));
    await h.settle();

    expect(await statusOf(h, p), PatientStatus.deceased);
    expect(notified, 1);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    // The row stayed (not dismissed) and now reads Deceased, dimmed.
    expect(rowOf(p), findsOneWidget);
    expect(
      find.descendant(of: rowOf(p), matching: find.text('Deceased')),
      findsOneWidget,
    );
  });

  testWidgets('in-hospital and moved rows can be marked deceased too', (
    tester,
  ) async {
    final h = await pumpListTab(tester);
    h.showInactive.value = true;
    await h.settle();
    final [a, b, ..._] = await h.db(() => h.repo.list());
    await h.db(
      () => h.repo.update(a.copyWith(status: PatientStatus.inHospital)),
    );
    await h.db(() => h.repo.update(b.copyWith(status: PatientStatus.moved)));

    for (final p in [a, b]) {
      await swipeLeft(tester, p);
      expect(inAlert('Mark ${p.fullName} as deceased?'), findsOneWidget);
      await tester.tap(inAlert('Mark deceased'));
      await h.settle();
      expect(await statusOf(h, p), PatientStatus.deceased);
    }
  });

  testWidgets('with Show inactive on, swipe left on a deceased row shows a '
      'green Restore and restores to active at once', (tester) async {
    final h = await pumpListTab(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.db(() => h.repo.markDeceased(p.id));
    h.showInactive.value = true;
    await h.settle();
    var notified = 0;
    void listener() => notified++;
    h.repo.addListener(listener);
    addTearDown(() => h.repo.removeListener(listener));

    final gesture = await tester.startGesture(tester.getCenter(rowOf(p)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
    }
    final bg = find.ancestor(
      of: find.text('Restore'),
      matching: find.byType(ColoredBox),
    );
    expect(tester.widget<ColoredBox>(bg.first).color, AppColors.actionPositive);
    await gesture.moveBy(const Offset(-400, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(inAlert('Restore ${p.fullName} to active?'), findsOneWidget);
    expect(inAlert('Their pin will show on the map again.'), findsOneWidget);
    await tester.tap(inAlert('Restore'));
    await h.settle();

    expect(await statusOf(h, p), PatientStatus.active);
    expect(notified, 1);
    expect(rowOf(p), findsOneWidget);
    final row = tester.widget<PatientRow>(rowOf(p));
    expect(row.patient.status, PatientStatus.active);
  });

  testWidgets('Cancel on Restore leaves the patient deceased', (tester) async {
    final h = await pumpListTab(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.db(() => h.repo.markDeceased(p.id));
    h.showInactive.value = true;
    await h.settle();
    await swipeLeft(tester, p);
    await tester.tap(inAlert('Cancel'));
    await h.settle();
    expect(await statusOf(h, p), PatientStatus.deceased);
    expect(rowOf(p), findsOneWidget);
  });

  testWidgets('swiping right does nothing', (tester) async {
    final h = await pumpListTab(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await tester.drag(rowOf(p), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(rowOf(p), findsOneWidget);
  });
}
