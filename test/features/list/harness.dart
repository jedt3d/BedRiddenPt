// Pumps ListTab in an AppScope on a seeded in-memory database.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bedridden_pt/app/app_scope.dart';
import 'package:bedridden_pt/app/routes.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';
import 'package:bedridden_pt/features/list/list_tab.dart';

import '../../data/test_db.dart';

class ListHarness {
  ListHarness(this.tester, this.repo, this.showInactive);

  final WidgetTester tester;
  final PatientRepository repo;
  final ValueNotifier<bool> showInactive;

  /// Runs [action] on the real database, then lets the list reload.
  Future<T> db<T>(Future<T> Function() action) async {
    final result = (await tester.runAsync(action)) as T;
    await settle();
    return result;
  }

  /// Lets pending database reads finish and the UI rebuild.
  Future<void> settle() async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }
}

/// Seeds the 5 sample patients (random seed [seed]) and shows ListTab.
Future<ListHarness> pumpListTab(WidgetTester tester, {int seed = 1}) async {
  // A tall iPhone-width screen, so every row is on screen.
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(393 * 3, 1600 * 3);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'volunteer_name': 'Nok'});
  final (repo, volunteer) = (await tester.runAsync(() async {
    final repo = await openTestRepository(seed: seed);
    await repo.seedSampleData();
    return (repo, await VolunteerStore.open());
  }))!;
  addTearDown(() => tester.runAsync(repo.close));
  final showInactive = ValueNotifier(false);
  addTearDown(showInactive.dispose);
  await tester.pumpWidget(
    AppScope(
      patients: repo,
      volunteer: volunteer,
      showInactive: showInactive,
      child: const CupertinoApp(
        home: ListTab(),
        onGenerateRoute: Routes.onGenerateRoute,
      ),
    ),
  );
  final h = ListHarness(tester, repo, showInactive);
  await h.settle();
  return h;
}
