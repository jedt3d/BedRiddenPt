import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/app_database.dart';

import 'test_db.dart';

void main() {
  initTestDatabases();

  test('schema.sql splits into its 4 statements', () async {
    final statements = splitSchema(await rootBundle.loadString(schemaAsset));
    expect(statements, hasLength(4));
    expect(statements.first, contains('CREATE TABLE patients ('));
    expect(
      statements.last,
      startsWith('CREATE INDEX idx_patient_care_needs_need'),
    );
  });

  test(
    'first open creates the schema tables and turns foreign keys on',
    () async {
      final opened = await openTestDatabase();
      final db = opened.db;
      addTearDown(db.close);

      expect(opened.created, isTrue);
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
      );
      expect(
        [for (final t in tables) t['name']],
        ['patient_care_needs', 'patient_phones', 'patients'],
      );
      final fk = await db.rawQuery('PRAGMA foreign_keys');
      expect(fk.single.values.single, 1);
    },
  );
}
