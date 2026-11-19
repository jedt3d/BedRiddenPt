// Opens the app's SQLite database (SPEC §5) with the schema in data/schema.sql.

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

const schemaAsset = 'data/schema.sql';
const databaseFileName = 'patients.db';

/// Splits schema.sql into statements. sqflite's execute() runs one statement
/// per call; in schema.sql every statement ends with `;` at the end of a line
/// and no other line does (data/README.md).
List<String> splitSchema(String sql) => [
  for (final piece in sql.split(RegExp(r';[ \t]*\r?\n|;[ \t]*$')))
    if (piece
        .split('\n')
        .any((l) => l.trim().isNotEmpty && !l.trim().startsWith('--')))
      piece.trim(),
];

class OpenedDatabase {
  const OpenedDatabase(this.db, {required this.created});
  final Database db;

  /// True when the file didn't exist and the schema was just created: the
  /// very first launch, when the 5 sample patients are seeded.
  final bool created;
}

/// Opens (creating if needed) the database. Defaults: the platform sqflite
/// factory and `patients.db` in the app documents folder. Tests pass an FFI
/// factory and [inMemoryDatabasePath].
Future<OpenedDatabase> openAppDatabase({
  DatabaseFactory? factory,
  String? path,
  AssetBundle? bundle,
}) async {
  final dbFactory = factory ?? databaseFactory;
  final dbPath =
      path ??
      '${(await getApplicationDocumentsDirectory()).path}/$databaseFileName';
  final schema = splitSchema(
    await (bundle ?? rootBundle).loadString(schemaAsset),
  );
  var created = false;
  final db = await dbFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      // Each in-memory open is a fresh database (tests); files are shared.
      singleInstance: dbPath != inMemoryDatabasePath,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        for (final statement in schema) {
          await db.execute(statement);
        }
        created = true;
      },
    ),
  );
  return OpenedDatabase(db, created: created);
}
