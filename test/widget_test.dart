import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/main.dart';

import 'data/test_db.dart';

void main() {
  initTestDatabases();

  testWidgets('app starts as a CupertinoApp showing the patient count', (
    tester,
  ) async {
    final repo = (await tester.runAsync(() async {
      final r = await openTestRepository();
      await r.seedSampleData();
      return r;
    }))!;
    addTearDown(() => tester.runAsync(repo.close));

    await tester.pumpWidget(BedriddenPtApp(patients: repo));
    expect(find.byType(CupertinoApp), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('5 patients'), findsOneWidget);
  });
}
