// Issue #10: ⋮ → Reset sample data on the PIN screen (SPEC §6, §7.1,
// Figma 05/06).

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bedridden_pt/app/app.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';
import 'package:bedridden_pt/features/launch/pin_screen.dart';

import '../../data/test_db.dart';

void main() {
  initTestDatabases();

  late PatientRepository repo;
  late VolunteerStore volunteer;

  /// Seeds 5 patients, adds a 6th as the volunteer, and opens the PIN screen.
  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852); // Figma frame 05
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'volunteer_name': 'Malee Chaiyo'});
    (repo, volunteer) = (await tester.runAsync(() async {
      final repo = await openTestRepository();
      await repo.seedSampleData();
      final volunteer = await VolunteerStore.open();
      await repo.insert(
        (await repo.nextUnusedPoolRecord())!,
        registeredBy: volunteer.name!,
      );
      return (repo, volunteer);
    }))!;
    addTearDown(() => tester.runAsync(repo.close));
    await tester.pumpWidget(
      BedriddenPtApp(patients: repo, volunteer: volunteer),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PinScreen), findsOneWidget);
  }

  Future<Set<String>> ids(WidgetTester tester) async => {
    for (final p in (await tester.runAsync(
      () => repo.list(showInactive: true),
    ))!)
      p.id,
  };

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openConfirm(WidgetTester tester) async {
    await tap(tester, find.byKey(const ValueKey('pin-more')));
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.text('Sample data'), findsOneWidget);
    expect(
      find.text('Works before you log in. Your name is kept.'),
      findsOneWidget,
    );
    await tap(tester, find.text('Reset sample data'));
    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('Reset sample data?'), findsOneWidget);
    expect(find.textContaining('Your name is kept.'), findsOneWidget);
  }

  testWidgets('Reset leaves 5 fresh patients and the same name', (
    tester,
  ) async {
    await launch(tester);
    final before = await ids(tester);
    expect(before, hasLength(6));

    await openConfirm(tester);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Reset'));
    // The reset runs on the real (ffi) database, outside fake time.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.byType(PinScreen), findsOneWidget, reason: 'still locked');
    final after = await ids(tester);
    expect(after, hasLength(sampleSeedCount));
    expect(after.intersection(before), isEmpty, reason: 'all new records');
    final active = (await tester.runAsync(repo.list))!;
    expect(active, hasLength(5));
    expect(active.map((p) => p.registeredBy), everyElement(sampleRegisteredBy));
    expect(volunteer.name, 'Malee Chaiyo');
    expect((await tester.runAsync(VolunteerStore.open))!.name, 'Malee Chaiyo');
    expect(find.text('Welcome back, Malee'), findsOneWidget);
  });

  testWidgets('Cancel in the alert changes nothing', (tester) async {
    await launch(tester);
    final before = await ids(tester);

    await openConfirm(tester);
    await tap(tester, find.widgetWithText(CupertinoDialogAction, 'Cancel'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(await ids(tester), before);
    expect(volunteer.name, 'Malee Chaiyo');
  });

  testWidgets('Cancel in the action sheet changes nothing', (tester) async {
    await launch(tester);
    final before = await ids(tester);

    await tap(tester, find.byKey(const ValueKey('pin-more')));
    await tap(
      tester,
      find.widgetWithText(CupertinoActionSheetAction, 'Cancel'),
    );

    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(await ids(tester), before);
  });

  testWidgets('the PIN still works after a reset', (tester) async {
    await launch(tester);
    await openConfirm(tester);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Reset'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    for (final d in appPin.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(PinScreen), findsNothing);
  });
}
