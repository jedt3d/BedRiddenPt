import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/data/patient_repository.dart';

import 'test_db.dart';

void main() {
  initTestDatabases();

  late PatientRepository repo;
  setUp(() async => repo = await openTestRepository());
  tearDown(() => repo.close());

  Patient pool(String id) => repo.pool.firstWhere((p) => p.id == id);
  Patient firstWith(bool Function(Patient) test) => repo.pool.firstWhere(test);

  Future<void> insertAll() async {
    for (final p in repo.pool) {
      await repo.insert(p, registeredBy: sampleRegisteredBy);
    }
  }

  group('list', () {
    setUp(insertAll);

    test('hides inactive patients unless showInactive', () async {
      final inactive = repo.pool
          .where((p) => p.status.isInactive)
          .length; // 3 deceased + 2 moved
      expect(inactive, 5);
      expect(await repo.list(), hasLength(50 - inactive));
      expect(await repo.list(showInactive: true), hasLength(50));
      expect((await repo.list()).any((p) => p.status.isInactive), isFalse);
    });

    test('is ordered by name', () async {
      final names = [
        for (final p in await repo.list(showInactive: true))
          p.fullName.toLowerCase(),
      ];
      expect(names, [...names]..sort());
    });

    test('filters by care level and status', () async {
      expect(
        await repo.list(careLevel: CareLevel.bedridden, showInactive: true),
        hasLength(10),
      );
      expect(
        (await repo.list(careLevel: CareLevel.social))
            .every((p) => p.careLevel == CareLevel.social),
        isTrue,
      );
      expect(await repo.list(status: PatientStatus.inHospital), hasLength(2));
      expect(
        await repo.list(status: PatientStatus.deceased, showInactive: true),
        hasLength(3),
      );
      expect(await repo.list(status: PatientStatus.deceased), isEmpty);
    });

    test('searches by name (any case) or national ID (dashes ignored)', () async {
      final p = firstWith((p) => !p.status.isInactive);
      final byName = await repo.list(
        query: p.fullName.split(' ').first.toUpperCase(),
      );
      expect(byName.map((x) => x.id), contains(p.id));
      final n = p.nationalId;
      final dashed =
          '${n[0]}-${n.substring(1, 5)}-${n.substring(5, 10)}-${n.substring(10, 12)}-${n[12]}';
      expect((await repo.list(query: dashed)).single.id, p.id);
      expect(await repo.list(query: 'no such name'), isEmpty);
    });
  });

  test(
    'getById returns the patient with phones in order and care needs',
    () async {
      final p = firstWith(
        (p) => p.phones.length == 2 && p.careNeeds.isNotEmpty,
      );
      await repo.insert(p, registeredBy: sampleRegisteredBy);
      final got = (await repo.getById(p.id))!;
      expect(got.phones, p.phones);
      expect(got.careNeeds, p.careNeeds);
      expect(
        await repo.getById('00000000-0000-4000-8000-000000000000'),
        isNull,
      );
    },
  );

  group('insert', () {
    test(
      'sets registered_by and timestamps; an empty id gets a UUID',
      () async {
        final p = repo.pool.first.copyWith(id: '');
        final saved = await repo.insert(p, registeredBy: 'Nok');
        expect(
          saved.id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        final got = (await repo.getById(saved.id))!;
        expect(got.registeredBy, 'Nok');
        expect(got.createdAt, startsWith('2026-11-20T10:30:00'));
        expect(got.updatedAt, got.createdAt);
      },
    );

    test('blocks a duplicate national ID', () async {
      final p = repo.pool.first;
      await repo.insert(p, registeredBy: 'Nok');
      expect(await repo.nationalIdExists(p.nationalId), isTrue);
      expect(
        await repo.nationalIdExists(p.nationalId, exceptId: p.id),
        isFalse,
      );
      await expectLater(
        repo.insert(
          repo.pool[1].copyWith(nationalId: p.nationalId),
          registeredBy: 'Nok',
        ),
        throwsA(isA<DuplicateNationalIdException>()),
      );
      expect(
        DuplicateNationalIdException.message,
        'A patient with this national ID already exists.',
      );
      expect(await repo.list(showInactive: true), hasLength(1));
    });
  });

  group('update', () {
    test(
      'overwrites the fields and phones but never registered_by or created_at',
      () async {
        final p = repo.pool.first;
        final saved = await repo.insert(p, registeredBy: 'Nok');
        final updated = await repo.update(
          saved.copyWith(
            fullName: 'Edited Name',
            phones: ['0811111111', '0822222222'],
            careNeeds: {CareNeed.oxygen},
            registeredBy: 'Someone else',
            createdAt: '1999-01-01T00:00:00+07:00',
          ),
        );
        expect(updated.fullName, 'Edited Name');
        expect(updated.phones, ['0811111111', '0822222222']);
        expect(updated.careNeeds, {CareNeed.oxygen});
        expect(updated.registeredBy, 'Nok');
        expect(updated.createdAt, saved.createdAt);
      },
    );

    test("blocks taking another patient's national ID", () async {
      final a = await repo.insert(repo.pool[0], registeredBy: 'Nok');
      final b = await repo.insert(repo.pool[1], registeredBy: 'Nok');
      await expectLater(
        repo.update(b.copyWith(nationalId: a.nationalId)),
        throwsA(isA<DuplicateNationalIdException>()),
      );
      expect((await repo.getById(b.id))!.nationalId, b.nationalId);
      // Keeping its own ID is fine.
      await repo.update(b.copyWith(notes: 'ok'));
    });
  });

  test('markDeceased and restoreToActive', () async {
    final p = firstWith((p) => p.status == PatientStatus.active);
    await repo.insert(p, registeredBy: 'Nok');
    await repo.markDeceased(p.id);
    expect((await repo.getById(p.id))!.status, PatientStatus.deceased);
    expect(await repo.list(), isEmpty);
    await repo.restoreToActive(p.id);
    expect((await repo.getById(p.id))!.status, PatientStatus.active);
    expect(await repo.list(), hasLength(1));
  });

  test('nextUnusedPoolRecord skips registered records and is null when all 50 are in', () async {
    final first = (await repo.nextUnusedPoolRecord())!;
    await repo.insert(first, registeredBy: 'Nok');
    for (var i = 0; i < 20; i++) {
      expect((await repo.nextUnusedPoolRecord())!.id, isNot(first.id));
    }
    for (final p in repo.pool.where((p) => p.id != first.id)) {
      await repo.insert(p, registeredBy: 'Nok');
    }
    expect(await repo.nextUnusedPoolRecord(), isNull);
  });

  test(
    'a pool record whose national ID is already used is not offered',
    () async {
      final target = repo.pool[3];
      await repo.insert(
        repo.pool[0].copyWith(id: '', nationalId: target.nationalId),
        registeredBy: 'Nok',
      );
      for (final p in repo.pool.skip(1).where((p) => p.id != target.id)) {
        await repo.insert(p, registeredBy: 'Nok');
      }
      final next = await repo.nextUnusedPoolRecord();
      expect(next?.id, pool(repo.pool[0].id).id); // only record 0 is left
    },
  );

  test('every write notifies listeners', () async {
    var n = 0;
    repo.addListener(() => n++);
    final p = await repo.insert(repo.pool.first, registeredBy: 'Nok');
    await repo.update(p.copyWith(notes: 'x'));
    await repo.markDeceased(p.id);
    await repo.restoreToActive(p.id);
    expect(n, 4);
  });
}
