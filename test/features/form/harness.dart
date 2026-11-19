// Pumps the List tab on a seeded in-memory database, so the form can be
// opened on top of it with Routes.openAdd / openEdit.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bedridden_pt/app/app_scope.dart';
import 'package:bedridden_pt/app/routes.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';
import 'package:bedridden_pt/features/form/form_draft.dart';
import 'package:bedridden_pt/features/form/form_widgets.dart';
import 'package:bedridden_pt/features/form/patient_form_screen.dart';
import 'package:bedridden_pt/features/list/list_tab.dart';

import '../../data/test_db.dart';

class FormHarness {
  FormHarness(this.tester, this.repo, this._app);

  final WidgetTester tester;
  final PatientRepository repo;
  final Widget _app;

  /// Pumps a fresh app on the same database, like an app restart.
  Future<void> rebuildApp() async {
    await tester.pumpWidget(KeyedSubtree(key: UniqueKey(), child: _app));
    await settle();
  }

  BuildContext get _context => tester.element(find.byType(ListTab));

  /// Runs [action] on the real database, then lets the UI catch up.
  Future<T> db<T>(Future<T> Function() action) async {
    final result = (await tester.runAsync(action)) as T;
    await settle();
    return result;
  }

  /// Lets pending database work finish and the UI rebuild.
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> openAdd() async {
    Routes.openAdd(_context);
    await settle();
  }

  Future<void> openEdit(String id) async {
    Routes.openEdit(_context, id);
    await settle();
  }

  /// Taps Save and waits for the write.
  Future<void> save() async {
    await tester.tap(find.widgetWithText(CupertinoButton, 'Save'));
    await settle();
  }

  /// The text field in the row labelled [label].
  Finder field(String label) => find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(FieldRow))
        .first,
    matching: find.byType(CupertinoTextField),
  );

  /// Scrolls the form until [finder] is built and on screen. The form's
  /// ListView builds lazily, so rows far down don't exist until scrolled to.
  Future<void> scrollTo(Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byType(PatientFormScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  Future<void> enter(String label, String text) async {
    await scrollTo(find.text(label));
    await tester.enterText(field(label), text);
    await tester.pump();
  }

  /// Scrolls [finder] into view and taps it.
  Future<void> tapVisible(Finder finder) async {
    await scrollTo(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

/// Seeds the 5 sample patients and shows the List tab.
Future<FormHarness> pumpFormHarness(
  WidgetTester tester, {
  int seed = 1,
  bool seedData = true,
}) async {
  // iPhone 16 size, so overflows at phone width fail the tests.
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  addTearDown(tester.view.reset);
  formClock = () => DateTime(2026, 11, 20);
  addTearDown(() => formClock = DateTime.now);
  SharedPreferences.setMockInitialValues({'volunteer_name': 'Nok'});
  final (repo, volunteer) = (await tester.runAsync(() async {
    final repo = await openTestRepository(seed: seed);
    if (seedData) await repo.seedSampleData();
    return (repo, await VolunteerStore.open());
  }))!;
  addTearDown(() => tester.runAsync(repo.close));
  final showInactive = ValueNotifier(false);
  addTearDown(showInactive.dispose);
  final app = AppScope(
    patients: repo,
    volunteer: volunteer,
    showInactive: showInactive,
    child: const CupertinoApp(
      home: ListTab(),
      onGenerateRoute: Routes.onGenerateRoute,
    ),
  );
  await tester.pumpWidget(app);
  final h = FormHarness(tester, repo, app);
  await h.settle();
  return h;
}
