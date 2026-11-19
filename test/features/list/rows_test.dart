// Issue #11: list rows (SPEC §7.2, Figma frames 07 and 11).

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/features/detail/detail_screen.dart';
import 'package:bedridden_pt/features/list/list_tab.dart';
import 'package:bedridden_pt/features/list/patient_row.dart';
import 'package:bedridden_pt/shared/care_style.dart';
import 'package:bedridden_pt/shared/labels.dart';
import 'package:bedridden_pt/shared/patient_avatar.dart';
import 'package:bedridden_pt/theme/tokens.dart';

import '../../data/test_db.dart';
import 'harness.dart';

Finder rowOf(Patient p) => find.byKey(ValueKey(p.id));

Text textIn(WidgetTester tester, Patient p, String text) => tester.widget<Text>(
  find.descendant(of: rowOf(p), matching: find.text(text)),
);

void main() {
  initTestDatabases();

  testWidgets('the 5 seeded patients show with photo, age, subdistrict, '
      'badge and status', (tester) async {
    final h = await pumpListTab(tester);
    final seeded = await h.db(() => h.repo.list());
    expect(seeded, hasLength(5));
    expect(find.byType(PatientRow), findsNWidgets(5));

    final year = DateTime.now().year;
    for (final p in seeded) {
      final row = rowOf(p);
      expect(row, findsOneWidget, reason: p.fullName);
      final avatar = tester.widget<PatientAvatar>(
        find.descendant(of: row, matching: find.byType(PatientAvatar)),
      );
      expect(avatar.patient.id, p.id);
      expect(avatar.patient.photoPath, startsWith('assets/avatars/'));
      expect(
        find.descendant(of: row, matching: find.text(p.fullName)),
        findsOneWidget,
      );
      final sub = p.subdistrict.replaceFirst(' Subdistrict', '');
      expect(
        find.descendant(
          of: row,
          matching: find.text('${year - p.birthYear} yrs · $sub'),
        ),
        findsOneWidget,
        reason: p.fullName,
      );
      final badge = find.descendant(of: row, matching: find.byType(CareBadge));
      expect(tester.widget<CareBadge>(badge).level, p.careLevel);
      expect(
        textIn(tester, p, p.careLevel.label).style!.color,
        CareStyle.of(p.careLevel).badgeText,
      );
      expect(
        find.descendant(of: row, matching: find.text('Active')),
        findsOneWidget,
      );
    }

    // Ordered by name, as the repository returns them.
    final names = [
      for (final r in tester.widgetList<PatientRow>(find.byType(PatientRow)))
        r.patient.fullName,
    ];
    expect(names, [for (final p in seeded) p.fullName]);
  });

  testWidgets('age is current year minus the Gregorian birth year', (
    tester,
  ) async {
    final pool = (await tester.runAsync(loadSamplePool))!;
    final p = pool.first;
    await tester.pumpWidget(
      CupertinoApp(home: PatientRow(patient: p, currentYear: 2026)),
    );
    expect(find.textContaining('${2026 - p.birthYear} yrs · '), findsOneWidget);
  });

  testWidgets('in hospital is indigo; inactive rows are dimmed with a grey '
      'name', (tester) async {
    final h = await pumpListTab(tester);
    final [a, b, ..._] = await h.db(() => h.repo.list());
    await h.db(
      () => h.repo.update(a.copyWith(status: PatientStatus.inHospital)),
    );
    await h.db(() => h.repo.markDeceased(b.id));
    h.showInactive.value = true;
    await h.settle();

    expect(
      textIn(tester, a, 'In hospital').style!.color,
      AppColors.statusInHospital,
    );
    expect(textIn(tester, a, a.fullName).style!.color, AppColors.labelPrimary);
    Opacity photoOpacity(Patient p) => tester.widget<Opacity>(
      find.descendant(of: rowOf(p), matching: find.byType(Opacity)),
    );
    expect(photoOpacity(a).opacity, 1);

    expect(
      textIn(tester, b, 'Deceased').style!.color,
      AppColors.labelSecondary,
    );
    expect(textIn(tester, b, b.fullName).style!.color, AppColors.labelInactive);
    expect(photoOpacity(b).opacity, lessThan(1));
  });

  testWidgets('header counts all patients, hidden or included', (tester) async {
    final h = await pumpListTab(tester);
    final seeded = await h.db(() => h.repo.list());
    await h.db(() => h.repo.markDeceased(seeded.first.id));
    expect(find.text('4 PATIENTS · 1 INACTIVE HIDDEN'), findsOneWidget);
    expect(find.byType(PatientRow), findsNWidgets(4));

    h.showInactive.value = true;
    await h.settle();
    expect(find.text('5 PATIENTS · INCLUDING 1 INACTIVE'), findsOneWidget);
    expect(find.byType(PatientRow), findsNWidgets(5));
  });

  test('listHeader wording (SPEC §7.2)', () async {
    final pool = await loadSamplePool();
    final active = pool.where((p) => !p.status.isInactive).take(8);
    final inactive = pool.firstWhere((p) => p.status.isInactive);
    final all = [...active, inactive];
    expect(
      listHeader(all, showInactive: false),
      '8 PATIENTS · 1 INACTIVE HIDDEN',
    );
    expect(
      listHeader(all, showInactive: true),
      '9 PATIENTS · INCLUDING 1 INACTIVE',
    );
  });

  testWidgets('tapping a row opens Detail for that patient', (tester) async {
    final h = await pumpListTab(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await tester.tap(rowOf(p));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DetailScreen>(find.byType(DetailScreen)).patientId,
      p.id,
    );
  });
}
