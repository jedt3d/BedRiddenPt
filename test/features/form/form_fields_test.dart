// Form (SPEC §7.3) #21: fields and pickers; saving an edit updates the
// patient and the list; pickers offer only the allowed values.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/features/form/form_draft.dart';
import 'package:bedridden_pt/features/form/patient_form_screen.dart';
import 'package:bedridden_pt/shared/labels.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  /// Every option of the open wheel picker (it builds only visible rows).
  List<String?> pickerLabels(WidgetTester tester) {
    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    final delegate = picker.childDelegate as ListWheelChildListDelegate;
    return [
      for (final c in delegate.children) ((c as Center).child! as Text).data,
    ];
  }

  Future<Patient> firstPatient(FormHarness h) async =>
      (await h.db(() => h.repo.list())).first;

  testWidgets('Edit shows the stored values in B.E. and 3-XXXX format', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final p = await firstPatient(h);
    await h.openEdit(p.id);

    expect(find.text('Edit patient'), findsOneWidget);
    expect(find.byType(PatientFormScreen), findsOneWidget);
    String textOf(String label) =>
        tester.widget<CupertinoTextField>(h.field(label)).controller!.text;
    expect(
      textOf('National ID'),
      matches(RegExp(r'^\d-\d{4}-\d{5}-\d{2}-\d$')),
    );
    expect(textOf('Full name'), p.fullName);
    expect(textOf('Born (B.E.)'), '${p.birthYear + 543}');
    expect(find.text('(age ${2026 - p.birthYear})'), findsOneWidget);
    expect(find.text(p.contactRelation.label), findsOneWidget);
    expect(find.text(p.mainCondition.label), findsOneWidget);
    expect(find.text('${p.adlScore}'), findsOneWidget);
    await h.scrollTo(find.text('Registered by'));
    expect(find.text('Registered by'), findsOneWidget);
  });

  testWidgets('Saving an edit updates the patient and the list', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final p = await firstPatient(h);
    await h.openEdit(p.id);

    await h.enter('Full name', 'Aaaa Edited Name');
    await h.enter('Born (B.E.)', '2490');
    await h.tapVisible(find.text('In hospital'));
    await h.save();

    expect(find.byType(PatientFormScreen), findsNothing);
    final saved = (await h.db(() => h.repo.getById(p.id)))!;
    expect(saved.fullName, 'Aaaa Edited Name');
    expect(saved.birthYear, 2490 - 543);
    expect(saved.status, PatientStatus.inHospital);
    expect(saved.registeredBy, p.registeredBy);
    // The list reloaded with the new name.
    expect(find.text('Aaaa Edited Name'), findsOneWidget);
    expect(find.text(p.fullName), findsNothing);
  });

  testWidgets('ADL stepper sets the score and the derived care level', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final p = await firstPatient(h);
    await h.openEdit(p.id);

    final plus = find.widgetWithText(CupertinoButton, '+');
    final minus = find.widgetWithText(CupertinoButton, '−');
    // Down to 0: bedridden.
    for (var i = 0; i < 20; i++) {
      await h.tapVisible(minus);
    }
    expect(find.text('Bedridden'), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await h.tapVisible(plus);
    }
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Social'), findsOneWidget);
    await h.save();
    final saved = (await h.db(() => h.repo.getById(p.id)))!;
    expect(saved.adlScore, 12);
    expect(saved.careLevel, CareLevel.social);
  });

  testWidgets('Phones: + Add phone, digits stored, Phone 1 first', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final p = await firstPatient(h);
    await h.openEdit(p.id);

    await h.enter('Phone 1', '0812345678');
    expect(
      tester.widget<CupertinoTextField>(h.field('Phone 1')).controller!.text,
      '081-234-5678',
    );
    expect(find.text('Phone 2'), findsNothing);
    await h.tapVisible(find.text('+ Add phone'));
    await h.enter('Phone 2', '0898765432');
    await h.save();
    final saved = (await h.db(() => h.repo.getById(p.id)))!;
    expect(saved.phones, ['0812345678', '0898765432']);
  });

  testWidgets('Care needs chips toggle', (tester) async {
    final h = await pumpFormHarness(tester);
    final p = await firstPatient(h);
    await h.openEdit(p.id);
    final had = p.careNeeds.contains(CareNeed.oxygen);
    await h.tapVisible(find.text('Oxygen'));
    await h.save();
    final saved = (await h.db(() => h.repo.getById(p.id)))!;
    expect(saved.careNeeds.contains(CareNeed.oxygen), !had);
  });

  testWidgets('Status picker offers only Active / In hospital / Moved', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final p = await firstPatient(h);
    await h.openEdit(p.id);

    await h.scrollTo(find.text('In hospital'));
    final control = find.byType(
      CupertinoSlidingSegmentedControl<PatientStatus>,
    );
    expect(control, findsOneWidget);
    final options = tester
        .widget<CupertinoSlidingSegmentedControl<PatientStatus>>(control)
        .children
        .keys;
    expect(options, [
      PatientStatus.active,
      PatientStatus.inHospital,
      PatientStatus.moved,
    ]);
    expect(find.text('Deceased'), findsNothing);
  });

  testWidgets('Relationship picker lists the eight relationships', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final p = await firstPatient(h);
    await h.openEdit(p.id);

    await h.tapVisible(find.text(p.contactRelation.label));
    final picker = find.byType(CupertinoPicker);
    expect(picker, findsOneWidget);
    final labels = pickerLabels(tester);
    expect(labels, [for (final r in ContactRelation.values) r.label]);

    // Move the wheel one row down and confirm.
    final from = ContactRelation.values.indexOf(p.contactRelation);
    final to = from == ContactRelation.values.length - 1 ? from - 1 : from + 1;
    await tester.drag(picker, Offset(0, (from - to) * 50.0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNothing);
    await h.save();
    final saved = (await h.db(() => h.repo.getById(p.id)))!;
    expect(saved.contactRelation, ContactRelation.values[to]);
  });

  testWidgets('Subdistrict picker lists the four subdistricts', (tester) async {
    final h = await pumpFormHarness(tester);
    final p = await firstPatient(h);
    await h.openEdit(p.id);

    await h.tapVisible(find.text(subdistrictLabel(p.subdistrict)));
    final labels = pickerLabels(tester);
    expect(labels, [
      'Somdet Chao Phraya',
      'Khlong San',
      'Khlong Ton Sai',
      'Bang Lamphu Lang',
    ]);
  });

  testWidgets('Cancel closes without saving', (tester) async {
    final h = await pumpFormHarness(tester);
    final p = await firstPatient(h);
    await h.openEdit(p.id);
    await h.enter('Full name', 'Not Saved');
    await tester.tap(find.widgetWithText(CupertinoButton, 'Cancel'));
    await h.settle();
    expect(find.byType(PatientFormScreen), findsNothing);
    expect((await h.db(() => h.repo.getById(p.id)))!.fullName, p.fullName);
  });
}
