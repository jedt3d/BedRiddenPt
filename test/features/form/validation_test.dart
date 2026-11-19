// Form (SPEC §6 Startup 4, §7.3) #23: required fields; a duplicate
// national ID blocks Save with the exact message under the field and inserts
// nothing; a bad checksum shows its message.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/features/form/patient_form_screen.dart';
import 'package:bedridden_pt/shared/national_id.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  /// The message's FieldError text sits inside the row with [label].
  Finder messageUnder(String label, String message) => find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.text(message),
  );

  testWidgets('Saving a duplicate national ID shows the message and inserts '
      'nothing', (tester) async {
    final h = await pumpFormHarness(tester);
    final existing = (await h.db(() => h.repo.list())).first;
    await h.openAdd();

    await h.enter('National ID', existing.nationalId);
    expect(find.text(DuplicateNationalIdException.message), findsNothing);
    await h.save();

    expect(find.byType(PatientFormScreen), findsOneWidget);
    expect(
      messageUnder('National ID', DuplicateNationalIdException.message),
      findsOneWidget,
    );
    expect(
      find.text('A patient with this national ID already exists.'),
      findsOneWidget,
    );
    expect(await h.db(() => h.repo.list(showInactive: true)), hasLength(5));

    // Changing the ID clears the message.
    await h.enter('National ID', existing.nationalId.substring(0, 12));
    expect(find.text(DuplicateNationalIdException.message), findsNothing);
  });

  testWidgets('Editing a patient into another patient’s ID is blocked too', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final [a, b, ...] = await h.db(() => h.repo.list());
    await h.openEdit(a.id);
    await h.enter('National ID', b.nationalId);
    await h.save();
    expect(find.text(DuplicateNationalIdException.message), findsOneWidget);
    expect((await h.db(() => h.repo.getById(a.id)))!.nationalId, a.nationalId);
  });

  testWidgets('A bad checksum shows the invalid-ID message', (tester) async {
    final h = await pumpFormHarness(tester);
    await h.openAdd();
    final good = nationalIdDigits(
      tester
          .widget<CupertinoTextField>(h.field('National ID'))
          .controller!
          .text,
    );
    final last = (int.parse(good[12]) + 1) % 10;
    await h.enter('National ID', '${good.substring(0, 12)}$last');
    await h.save();

    expect(
      messageUnder('National ID', invalidNationalIdMessage),
      findsOneWidget,
    );
    expect(
      find.text("This national ID isn't valid. Check the 13 digits."),
      findsOneWidget,
    );
    expect(await h.db(() => h.repo.list(showInactive: true)), hasLength(5));
  });

  testWidgets('An empty form shows the required-field messages', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester, seedData: false);
    await h.db(() async {
      for (final p in h.repo.pool) {
        await h.repo.insert(p, registeredBy: 'Sample data');
      }
    });
    await h.openAdd();
    expect(find.text('Enter the patient’s full name.'), findsNothing);
    await h.save();

    expect(find.byType(PatientFormScreen), findsOneWidget);
    for (final message in [
      'Enter the 13-digit national ID.',
      'Enter the patient’s full name.',
      'Choose male or female.',
      'Enter the birth year in B.E.',
      'Choose a subdistrict.',
      'Tap Use my location.',
      'Enter the contact person’s name.',
      'Choose a relationship.',
      'Set the ADL score.',
      'Choose a main condition.',
      'Choose a living situation.',
    ]) {
      await h.scrollTo(find.text(message));
      expect(find.text(message), findsOneWidget, reason: message);
    }
    expect(await h.db(() => h.repo.list(showInactive: true)), hasLength(50));
  });

  testWidgets('Age must be 60–110', (tester) async {
    final h = await pumpFormHarness(tester);
    await h.openAdd();
    await h.enter('Born (B.E.)', '2530'); // age 39 in 2026
    await h.save();
    expect(
      find.text('Age must be 60–110: born 2459–2509 B.E.'),
      findsOneWidget,
    );
    await h.enter('Born (B.E.)', '2509'); // age 60
    expect(find.text('Age must be 60–110: born 2459–2509 B.E.'), findsNothing);
  });

  testWidgets('A phone must have 10 digits', (tester) async {
    final h = await pumpFormHarness(tester);
    await h.openAdd();
    await h.enter('Phone 1', '08123');
    await h.save();
    expect(find.text('Phone numbers have 10 digits.'), findsOneWidget);
    expect(find.byType(PatientFormScreen), findsOneWidget);
  });
}
