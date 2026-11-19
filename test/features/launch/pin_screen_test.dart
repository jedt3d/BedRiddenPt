// Issue #9: PIN entry with the fixed PIN 000000 (SPEC §7.1, Figma 02/04).

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bedridden_pt/app/app.dart';
import 'package:bedridden_pt/app/home_screen.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';
import 'package:bedridden_pt/features/launch/pin_screen.dart';
import 'package:bedridden_pt/theme/tokens.dart';

import '../../data/test_db.dart';

void main() {
  initTestDatabases();

  Future<PatientRepository> seededRepo(WidgetTester tester) async {
    final repo = (await tester.runAsync(() async {
      final repo = await openTestRepository();
      await repo.seedSampleData();
      return repo;
    }))!;
    addTearDown(() => tester.runAsync(repo.close));
    return repo;
  }

  /// One app launch with the volunteer name already saved.
  Future<void> launch(WidgetTester tester, PatientRepository repo) async {
    tester.view.physicalSize = const Size(393, 852); // Figma frame 04
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final volunteer = (await tester.runAsync(VolunteerStore.open))!;
    await tester.pumpWidget(
      BedriddenPtApp(key: UniqueKey(), patients: repo, volunteer: volunteer),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  int filledDots(WidgetTester tester) {
    var n = 0;
    for (var i = 0; i < appPin.length; i++) {
      final box = tester.widget<Container>(find.byKey(ValueKey('pin-dot-$i')));
      final deco = box.decoration! as BoxDecoration;
      if (deco.color != AppColors.transparent) n++;
    }
    return n;
  }

  setUp(
    () => SharedPreferences.setMockInitialValues({
      'volunteer_name': 'Malee Chaiyo',
    }),
  );

  testWidgets('shows the greeting, initials and an empty 6-dot PIN', (
    tester,
  ) async {
    await launch(tester, await seededRepo(tester));
    expect(find.byType(PinScreen), findsOneWidget);
    expect(find.text('Welcome back, Malee'), findsOneWidget);
    expect(find.text('MC'), findsOneWidget);
    expect(find.text('Enter your 6-digit PIN'), findsOneWidget);
    expect(filledDots(tester), 0);
    for (final d in '0123456789'.split('')) {
      expect(find.text(d), findsOneWidget, reason: 'key $d');
    }
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('000000 opens Home', (tester) async {
    await launch(tester, await seededRepo(tester));
    await type(tester, appPin);
    expect(appPin, '000000');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(PinScreen), findsNothing);
  });

  testWidgets('a wrong PIN shakes, clears, and never locks out', (
    tester,
  ) async {
    await launch(tester, await seededRepo(tester));
    for (var attempt = 0; attempt < 6; attempt++) {
      await type(tester, '123456');
      expect(find.byType(HomeScreen), findsNothing, reason: 'try $attempt');
      expect(find.byType(PinScreen), findsOneWidget);
      expect(filledDots(tester), 0, reason: 'cleared after try $attempt');
    }
    await type(tester, appPin);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Delete removes the last digit', (tester) async {
    await launch(tester, await seededRepo(tester));
    await type(tester, '12');
    expect(filledDots(tester), 2);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(filledDots(tester), 1);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await type(tester, appPin);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('every launch asks for the PIN', (tester) async {
    final repo = await seededRepo(tester);
    for (var i = 0; i < 2; i++) {
      await launch(tester, repo);
      expect(find.byType(PinScreen), findsOneWidget, reason: 'launch $i');
      await type(tester, '999999');
      expect(find.byType(HomeScreen), findsNothing);
      await type(tester, appPin);
      expect(find.byType(HomeScreen), findsOneWidget);
    }
  });
}
