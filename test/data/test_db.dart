// Test helpers: the real schema on the host's SQLite through sqflite_common_ffi.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bedridden_pt/data/app_database.dart';
import 'package:bedridden_pt/data/patient_repository.dart';

/// Call at the top of main() in a test file that opens databases.
void initTestDatabases() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
}

/// A fresh in-memory database with data/schema.sql (each call is a new one).
Future<OpenedDatabase> openTestDatabase({String path = inMemoryDatabasePath}) =>
    openAppDatabase(factory: databaseFactoryFfiNoIsolate, path: path);

/// A repository on a fresh in-memory database, with no patients yet.
Future<PatientRepository> openTestRepository({int seed = 1}) async {
  final opened = await openTestDatabase();
  return PatientRepository(
    opened.db,
    pool: await loadSamplePool(),
    random: Random(seed),
    now: () => DateTime(2026, 11, 20, 10, 30),
  );
}
