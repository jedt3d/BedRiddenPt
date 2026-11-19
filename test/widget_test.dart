// Shell tests: they assert widget types and routes only, never placeholder
// text, so the feature streams can replace the screens without breaking them.
// Feature tests go in test/features/<stream>/.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bedridden_pt/app/app.dart';
import 'package:bedridden_pt/app/app_scope.dart';
import 'package:bedridden_pt/app/home_screen.dart';
import 'package:bedridden_pt/app/routes.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';
import 'package:bedridden_pt/features/detail/detail_screen.dart';
import 'package:bedridden_pt/features/form/patient_form_screen.dart';
import 'package:bedridden_pt/features/launch/name_screen.dart';
import 'package:bedridden_pt/features/launch/pin_screen.dart';
import 'package:bedridden_pt/features/list/list_tab.dart';
import 'package:bedridden_pt/features/map/map_tab.dart';

import 'data/test_db.dart';

void main() {
  initTestDatabases();

  /// Pumps the app on a seeded in-memory database; returns a seeded id.
  Future<String> pumpApp(WidgetTester tester, {String? name}) async {
    SharedPreferences.setMockInitialValues({'volunteer_name': ?name});
    final (repo, volunteer, id) = (await tester.runAsync(() async {
      final repo = await openTestRepository();
      await repo.seedSampleData();
      final id = (await repo.list()).first.id;
      return (repo, await VolunteerStore.open(), id);
    }))!;
    addTearDown(() => tester.runAsync(repo.close));
    await tester.pumpWidget(
      BedriddenPtApp(patients: repo, volunteer: volunteer),
    );
    return id;
  }

  BuildContext contextOf<T extends Widget>(WidgetTester tester) =>
      tester.element(find.byType(T));

  Future<void> go(WidgetTester tester, Future<void> Function() navigate) async {
    navigate();
    await tester.pumpAndSettle();
  }

  testWidgets('first launch starts at NameScreen; then PIN, then Home', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.byType(NameScreen), findsOneWidget);

    await go(
      tester,
      () => Routes.replaceAllWith(contextOf<NameScreen>(tester), Routes.pin),
    );
    expect(find.byType(PinScreen), findsOneWidget);
    expect(find.byType(NameScreen), findsNothing);

    await go(
      tester,
      () => Routes.replaceAllWith(contextOf<PinScreen>(tester), Routes.home),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.byType(ListTab), findsOneWidget);
  });

  testWidgets('a later launch starts at PinScreen', (tester) async {
    await pumpApp(tester, name: 'Nok');
    expect(find.byType(PinScreen), findsOneWidget);
  });

  testWidgets('Home has List and Map tabs; Detail, Add and Edit cover them', (
    tester,
  ) async {
    final id = await pumpApp(tester, name: 'Nok');
    await go(
      tester,
      () => Routes.replaceAllWith(contextOf<PinScreen>(tester), Routes.home),
    );

    // Second tab: Map.
    final tabBar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
    tabBar.onTap!(1);
    await tester.pumpAndSettle();
    expect(find.byType(MapTab), findsOneWidget);
    tabBar.onTap!(0);
    await tester.pumpAndSettle();

    final fromList = contextOf<ListTab>(tester);
    expect(AppScope.of(fromList).showInactive.value, isFalse);
    expect(AppScope.read(fromList).patients, isA<PatientRepository>());

    await go(tester, () => Routes.openAdd(fromList));
    final add = tester.widget<PatientFormScreen>(
      find.byType(PatientFormScreen),
    );
    expect(add.patientId, isNull);
    expect(find.byType(CupertinoTabBar).hitTestable(), findsNothing);
    Navigator.of(contextOf<PatientFormScreen>(tester)).pop();
    await tester.pumpAndSettle();

    await go(tester, () => Routes.openDetail(fromList, id));
    expect(
      tester.widget<DetailScreen>(find.byType(DetailScreen)).patientId,
      id,
    );
    expect(find.byType(CupertinoTabBar).hitTestable(), findsNothing);

    await go(
      tester,
      () => Routes.openEdit(contextOf<DetailScreen>(tester), id),
    );
    expect(
      tester
          .widget<PatientFormScreen>(find.byType(PatientFormScreen))
          .patientId,
      id,
    );
  });

  test('Home and Detail routes carry the back-button titles', () {
    String? titleOf(String name, [Object? args]) =>
        (Routes.onGenerateRoute(RouteSettings(name: name, arguments: args))!
                as CupertinoPageRoute<void>)
            .title;
    expect(titleOf(Routes.home), 'Patients'); // Detail/Add: "< Patients"
    expect(titleOf(Routes.detail, 'x'), 'Patient'); // Edit: "< Patient"
    expect(titleOf(Routes.pin), isNull);
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
