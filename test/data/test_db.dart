// Test helpers: the real schema on the host's SQLite through sqflite_common_ffi.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bedridden_pt/data/app_database.dart';

/// Call at the top of main() in a test file that opens databases.
void initTestDatabases() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
}

/// A fresh in-memory database with data/schema.sql (each call is a new one).
Future<OpenedDatabase> openTestDatabase({String path = inMemoryDatabasePath}) =>
    openAppDatabase(factory: databaseFactoryFfiNoIsolate, path: path);
