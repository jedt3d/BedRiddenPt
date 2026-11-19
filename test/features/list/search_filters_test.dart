// Issue #12: search and filters (SPEC §7.2, Figma frames 07 and 08).

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/features/list/patient_row.dart';
import 'package:bedridden_pt/shared/labels.dart';
import 'package:bedridden_pt/shared/national_id.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  Set<String> shownIds(WidgetTester tester) => {
    for (final r in tester.widgetList<PatientRow>(find.byType(PatientRow)))
      r.patient.id,
  };

  /// All 50 pool patients in the database (inactive ones included).
  Future<(ListHarness, List<Patient>)> pumpWholePool(
    WidgetTester tester,
  ) async {
    final h = await pumpListTab(tester);
    await h.db(() async {
      final have = {
        for (final p in await h.repo.list(showInactive: true)) p.id,
      };
      for (final p in h.repo.pool) {
        if (!have.contains(p.id)) {
          await h.repo.insert(p, registeredBy: sampleRegisteredBy);
        }
      }
    });
    final all = await h.db(() => h.repo.list(showInactive: true));
    expect(all, hasLength(50));
    return (h, all);
  }

  Future<void> search(WidgetTester tester, ListHarness h, String text) async {
    await tester.enterText(find.byType(CupertinoSearchTextField), text);
    await h.settle();
  }

  Future<void> pickCareLevel(
    WidgetTester tester,
    ListHarness h,
    String label,
  ) async {
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoSlidingSegmentedControl<int>),
        matching: find.text(label),
      ),
    );
    await h.settle();
  }

  Future<void> pickStatus(
    WidgetTester tester,
    ListHarness h,
    String label,
  ) async {
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoActionSheet),
        matching: find.text(label),
      ),
    );
    await h.settle();
  }

  testWidgets('typing part of a name narrows the list', (tester) async {
    final (h, all) = await pumpWholePool(tester);
    final visible = all.where((p) => !p.status.isInactive).toList();
    final first = visible.first.fullName.split(' ').first;
    final part = first.substring(1, first.length - 1).toLowerCase();
    await search(tester, h, part);
    final expected = {
      for (final p in visible)
        if (p.fullName.toLowerCase().contains(part)) p.id,
    };
    expect(expected, isNotEmpty);
    expect(expected.length, lessThan(visible.length));
    expect(shownIds(tester), expected);

    await search(tester, h, '');
    expect(shownIds(tester), {for (final p in visible) p.id});
  });

  testWidgets('typing part of a national ID, with or without dashes, '
      'narrows the list', (tester) async {
    final (h, all) = await pumpWholePool(tester);
    final p = all.firstWhere((p) => !p.status.isInactive);
    // The first 6 digits as shown: "3-1234-5".
    final dashed = formatNationalId(p.nationalId.substring(0, 6));
    expect(dashed, contains('-'));
    for (final text in [p.nationalId, dashed, p.nationalId.substring(4, 10)]) {
      await search(tester, h, text);
      final digits = text.replaceAll('-', '');
      expect(shownIds(tester), {
        for (final q in all)
          if (!q.status.isInactive && q.nationalId.contains(digits)) q.id,
      }, reason: text);
      expect(shownIds(tester), contains(p.id));
    }
    await search(tester, h, p.nationalId);
    expect(shownIds(tester), {p.id});
  });

  testWidgets('each care level × status combination shows only matching '
      'rows', (tester) async {
    final (h, all) = await pumpWholePool(tester);
    h.showInactive.value = true; // so Moved and Deceased can be picked
    await h.settle();
    for (final level in [null, ...CareLevel.values]) {
      await pickCareLevel(tester, h, level?.label ?? 'All');
      for (final status in [null, ...PatientStatus.values]) {
        await pickStatus(tester, h, status?.label ?? 'All statuses');
        final expected = {
          for (final p in all)
            if ((level == null || p.careLevel == level) &&
                (status == null || p.status == status))
              p.id,
        };
        expect(shownIds(tester), expected, reason: '$level × $status');
      }
    }
  });

  testWidgets('filters combine with the search', (tester) async {
    final (h, all) = await pumpWholePool(tester);
    await pickCareLevel(tester, h, 'Homebound');
    await search(tester, h, 'a');
    expect(shownIds(tester), {
      for (final p in all)
        if (!p.status.isInactive &&
            p.careLevel == CareLevel.homebound &&
            p.fullName.toLowerCase().contains('a'))
          p.id,
    });
  });

  testWidgets('status sheet: Moved and Deceased are greyed out and do '
      'nothing while Show inactive is off', (tester) async {
    final (h, all) = await pumpWholePool(tester);
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    final sheet = find.byType(CupertinoActionSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Filter by status')),
      findsOneWidget,
    );
    for (final label in [
      'All statuses',
      'Active',
      'In hospital',
      'Moved',
      'Deceased',
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
      );
    }
    await tester.tap(find.descendant(of: sheet, matching: find.text('Moved')));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget); // still open, nothing picked
    await tester.tap(find.text('Cancel'));
    await h.settle();
    expect(sheet, findsNothing);
    expect(shownIds(tester), {
      for (final p in all)
        if (!p.status.isInactive) p.id,
    });

    await pickStatus(tester, h, 'In hospital');
    expect(
      find.descendant(
        of: find.byType(CupertinoPageScaffold),
        matching: find.text(PatientStatus.inHospital.label),
      ),
      findsWidgets,
    );
  });
}
