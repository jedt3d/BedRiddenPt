import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';

import 'test_db.dart';

void main() {
  initTestDatabases();

  test(
    'reset leaves exactly 5 new pool patients and keeps the volunteer name',
    () async {
      SharedPreferences.setMockInitialValues({});
      final volunteer = await VolunteerStore.open();
      await volunteer.setName('Nok');

      final repo = await openTestRepository();
      addTearDown(repo.close);
      await repo.seedSampleData();
      final added = await repo.insert(
        (await repo.nextUnusedPoolRecord())!.copyWith(id: ''),
        registeredBy: 'Nok',
      );
      await repo.markDeceased(added.id);
      expect(await repo.list(showInactive: true), hasLength(6));

      await repo.resetSampleData();

      final after = await repo.list(showInactive: true);
      expect(after, hasLength(5));
      final poolIds = {for (final p in repo.pool) p.id};
      expect(
        after.every(
          (p) => poolIds.contains(p.id) && p.registeredBy == sampleRegisteredBy,
        ),
        isTrue,
      );
      expect(await repo.getById(added.id), isNull);
      expect((await VolunteerStore.open()).name, 'Nok');
    },
  );

  test('VolunteerStore has no name until one is saved, and trims it', () async {
    SharedPreferences.setMockInitialValues({});
    final volunteer = await VolunteerStore.open();
    expect(volunteer.name, isNull);
    await volunteer.setName('  Nok  ');
    expect(volunteer.name, 'Nok');
    expect(appPin, '000000');
  });
}
