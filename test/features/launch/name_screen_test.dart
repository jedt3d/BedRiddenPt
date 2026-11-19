// Issue #8: the one-time "Your name" screen (SPEC §7.1, Figma frame 01).

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bedridden_pt/app/app.dart';
import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';
import 'package:bedridden_pt/features/launch/name_screen.dart';
import 'package:bedridden_pt/features/launch/pin_screen.dart';

import '../../data/test_db.dart';

void main() {
  initTestDatabases();

  /// One app launch on [repo] with whatever is in SharedPreferences now.
  Future<VolunteerStore> launch(
    WidgetTester tester,
    PatientRepository repo,
  ) async {
    final volunteer = (await tester.runAsync(VolunteerStore.open))!;
    // A new key so a second launch builds a fresh app, as a restart would.
    await tester.pumpWidget(
      BedriddenPtApp(key: UniqueKey(), patients: repo, volunteer: volunteer),
    );
    await tester.pumpAndSettle();
    return volunteer;
  }

  Future<PatientRepository> seededRepo(WidgetTester tester) async {
    final repo = (await tester.runAsync(() async {
      final repo = await openTestRepository();
      await repo.seedSampleData();
      return repo;
    }))!;
    addTearDown(() => tester.runAsync(repo.close));
    return repo;
  }

  Finder continueButton() => find.widgetWithText(CupertinoButton, 'Continue');

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<CupertinoButton>(button).onPressed != null;

  testWidgets('first launch asks for the name; Continue needs one', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await seededRepo(tester);
    final volunteer = await launch(tester, repo);

    expect(find.byType(NameScreen), findsOneWidget);
    expect(find.text('Welcome, volunteer'), findsOneWidget);
    expect(enabled(tester, continueButton()), isFalse);

    await tester.enterText(find.byType(CupertinoTextField), '   ');
    await tester.pump();
    expect(enabled(tester, continueButton()), isFalse, reason: 'blank');

    await tester.enterText(find.byType(CupertinoTextField), '  Malee Chaiyo ');
    await tester.pump();
    expect(enabled(tester, continueButton()), isTrue);

    await tester.tap(continueButton());
    await tester.pumpAndSettle();
    expect(find.byType(PinScreen), findsOneWidget);
    expect(find.byType(NameScreen), findsNothing);
    expect(volunteer.name, 'Malee Chaiyo');
  });

  testWidgets('the keyboard Done key also continues', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await seededRepo(tester);
    await launch(tester, repo);

    await tester.enterText(find.byType(CupertinoTextField), 'Nok');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(PinScreen), findsOneWidget);
  });

  testWidgets('a later launch skips straight to the PIN screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await seededRepo(tester);
    await launch(tester, repo);
    await tester.enterText(find.byType(CupertinoTextField), 'Malee Chaiyo');
    await tester.pump();
    await tester.tap(continueButton());
    await tester.pumpAndSettle();

    // Relaunch: same SharedPreferences, a new VolunteerStore and app.
    final again = await launch(tester, repo);
    expect(find.byType(NameScreen), findsNothing);
    expect(find.byType(PinScreen), findsOneWidget);
    expect(again.name, 'Malee Chaiyo');
  });

  testWidgets("a new patient's registered_by is the saved name", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await seededRepo(tester);
    final volunteer = await launch(tester, repo);
    await tester.enterText(find.byType(CupertinoTextField), 'Malee Chaiyo');
    await tester.pump();
    await tester.tap(continueButton());
    await tester.pumpAndSettle();

    // What the Add form does on Save (see lib/features/form/patient_form_screen.dart):
    // insert(patient, registeredBy: volunteer.name!).
    final saved = (await tester.runAsync(() async {
      final Patient draft = (await repo.nextUnusedPoolRecord())!;
      return repo.insert(draft, registeredBy: volunteer.name!);
    }))!;
    expect(saved.registeredBy, 'Malee Chaiyo');
  });
}
