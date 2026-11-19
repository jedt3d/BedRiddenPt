// Found on the Simulator: the last row sat under the translucent tab bar and
// the list could not scroll it out.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/app/home_screen.dart';
import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/features/list/patient_row.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  testWidgets('the last row scrolls fully above the tab bar', (tester) async {
    // iPhone 16 Pro: 874 pt tall, 34 pt home-indicator inset.
    tester.view.padding = const FakeViewPadding(bottom: 34 * 3);
    addTearDown(tester.view.resetPadding);
    final h = await pumpListTab(tester, home: const HomeScreen(), height: 874);
    // More rows than fit, so the list must scroll.
    await h.db(() async {
      final have = {for (final p in await h.repo.list()) p.id};
      final extra = h.repo.pool
          .where(
            (p) => p.status == PatientStatus.active && !have.contains(p.id),
          )
          .take(10);
      for (final p in extra) {
        await h.repo.insert(p, registeredBy: sampleRegisteredBy);
      }
    });
    expect(find.byType(PatientRow), findsNWidgets(15));

    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }

    final tabBarTop = tester.getTopLeft(find.byType(CupertinoTabBar)).dy;
    final lastRow = find.byType(PatientRow).last;
    expect(tester.getBottomLeft(lastRow).dy, lessThanOrEqualTo(tabBarTop));
  });
}
