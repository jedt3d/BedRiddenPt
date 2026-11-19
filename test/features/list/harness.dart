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
/// [home] replaces ListTab (e.g. HomeScreen); [height] is the screen height
/// in points (default tall enough for every row).
Future<ListHarness> pumpListTab(
  WidgetTester tester, {
  int seed = 1,
  Widget home = const ListTab(),
  double height = 1600,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(393 * 3, height * 3);
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
      child: CupertinoApp(home: home, onGenerateRoute: _routes),
    ),
  );
  final h = ListHarness(tester, repo, showInactive);
  await h.settle();
  return h;
}

/// The app's routes, except Detail is a stub, so these tests don't depend on
/// the Detail stream's layout.
Route<void>? _routes(RouteSettings settings) => settings.name == Routes.detail
    ? CupertinoPageRoute<void>(
        settings: settings,
        builder: (_) => DetailStub(settings.arguments! as String),
      )
    : Routes.onGenerateRoute(settings);

/// Stands in for DetailScreen; records the patient id it was opened with.
class DetailStub extends StatelessWidget {
  const DetailStub(this.patientId, {super.key});

  final String patientId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
