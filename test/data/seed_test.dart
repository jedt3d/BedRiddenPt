import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/data/patient_repository.dart';

import 'test_db.dart';

void main() {
  initTestDatabases();

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('seed_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<PatientRepository> launch() => PatientRepository.open(
    factory: databaseFactoryFfiNoIsolate,
    path: '${dir.path}/patients.db',
  );

  Future<List<String>> ids(PatientRepository repo) async =>
      [for (final p in await repo.list(showInactive: true)) p.id]..sort();

  test('a fresh install has exactly 5 pool patients; relaunching keeps them plus anything added', () async {
    final first = await launch();
    final seeded = await ids(first);
    expect(seeded, hasLength(5));
    // Seeded from active pool records only: 5 show with Show inactive off.
    expect(await first.list(), hasLength(5));
    final poolIds = {for (final p in first.pool) p.id};
    expect(seeded.every(poolIds.contains), isTrue);
    final all = await first.list(showInactive: true);
    expect(all.every((p) => p.registeredBy == sampleRegisteredBy), isTrue);
    await first.close();

    final second = await launch();
    expect(await ids(second), seeded);
    final added = await second.insert(
      (await second.nextUnusedPoolRecord())!,
      registeredBy: 'Nok',
    );
    await second.close();

    final third = await launch();
    expect(await ids(third), ([...seeded, added.id]..sort()));
    await third.close();
  });

  test('the seed is random', () async {
    final a = await PatientRepository.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    final b = await PatientRepository.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    // 50 choose 5 sets: two equal draws are vanishingly unlikely.
    expect(await ids(a), isNot(await ids(b)));
    await a.close();
    await b.close();
  });

  test(
    'pool records survive the round trip through SQLite unchanged',
    () async {
      final repo = await openTestRepository();
      addTearDown(repo.close);
      for (final p in repo.pool) {
        await repo.insert(p, registeredBy: sampleRegisteredBy);
        final back = (await repo.getById(p.id))!;
        expect(
          [
            back.nationalId,
            back.fullName,
            back.sex,
            back.birthYear,
            back.photoPath,
            back.contactName,
            back.contactRelation,
            back.phones,
            back.subdistrict,
            back.addressNote,
            back.lat,
            back.lng,
            back.gpsAccuracyM,
            back.careLevel,
            back.adlScore,
            back.mainCondition,
            back.careNeeds,
            back.livingSituation,
            back.status,
            back.notes,
          ],
          [
            p.nationalId,
            p.fullName,
            p.sex,
            p.birthYear,
            p.photoPath,
            p.contactName,
            p.contactRelation,
            p.phones,
            p.subdistrict,
            p.addressNote,
            p.lat,
            p.lng,
            p.gpsAccuracyM,
            p.careLevel,
            p.adlScore,
            p.mainCondition,
            p.careNeeds,
            p.livingSituation,
            p.status,
            p.notes,
          ],
        );
      }
      expect(await repo.list(showInactive: true), hasLength(50));
      expect(CareLevel.fromAdl(4), CareLevel.bedridden);
    },
  );
}
