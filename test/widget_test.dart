import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bedridden_pt/app/app.dart';
import 'package:bedridden_pt/app/app_scope.dart';
import 'package:bedridden_pt/app/routes.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';

import 'data/test_db.dart';

void main() {
  initTestDatabases();

  Future<PatientRepository> pumpApp(WidgetTester tester, {String? name}) async {
    SharedPreferences.setMockInitialValues({'volunteer_name': ?name});
    final (repo, volunteer) = (await tester.runAsync(
      () async => (await openTestRepository(), await VolunteerStore.open()),
    ))!;
    addTearDown(() => tester.runAsync(repo.close));
    await tester.pumpWidget(
      BedriddenPtApp(patients: repo, volunteer: volunteer),
    );
    return repo;
  }

  testWidgets('first launch opens Your name, then PIN, then Home', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsOneWidget);

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
  });

  testWidgets('a later launch opens the PIN screen', (tester) async {
    await pumpApp(tester, name: 'Nok');
    expect(find.text('Enter PIN'), findsOneWidget);
  });

  testWidgets('Home switches tabs; Add and Detail cover the tab bar', (
    tester,
  ) async {
    await pumpApp(tester, name: 'Nok');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('Map (placeholder)'), findsOneWidget);

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add patient'));
    await tester.pumpAndSettle();
    expect(find.text('New patient'), findsOneWidget);
    expect(find.byType(CupertinoTabBar).hitTestable(), findsNothing);

    final context = tester.element(find.text('New patient'));
    expect(AppScope.of(context).showInactive.value, isFalse);
    Routes.openDetail(context, 'abc');
    await tester.pumpAndSettle();
    expect(find.text('Detail of abc (placeholder)'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit patient'), findsOneWidget);
  });

  test('every route name builds a page; unknown names do not', () {
    for (final (name, args) in [
      (Routes.name, null),
      (Routes.pin, null),
      (Routes.home, null),
      (Routes.detail, 'id'),
      (Routes.add, null),
      (Routes.edit, 'id'),
    ]) {
      expect(
        Routes.onGenerateRoute(RouteSettings(name: name, arguments: args)),
        isNotNull,
        reason: name,
      );
    }
    expect(Routes.onGenerateRoute(const RouteSettings(name: '/nope')), isNull);
  });
}
