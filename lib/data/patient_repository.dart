// All patient reads and writes (SPEC §5–§7). Screens use only this class.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'patient.dart';

const sampleSeedCount = 5;
const samplePoolAsset = 'assets/bootstrap.json';

/// `registered_by` of sample-pool records inserted by seeding or reset.
const sampleRegisteredBy = 'Sample data';

/// The 50 fictitious records in assets/bootstrap.json.
Future<List<Patient>> loadSamplePool([AssetBundle? bundle]) async {
  final json = jsonDecode(
    await (bundle ?? rootBundle).loadString(samplePoolAsset),
  ) as List;
  return [for (final r in json) Patient.fromJson(r as Map<String, dynamic>)];
}

/// Saving a patient whose national ID another patient already has.
class DuplicateNationalIdException implements Exception {
  const DuplicateNationalIdException(this.nationalId);
  final String nationalId;

  /// The message SPEC §6 shows under the field.
  static const message = 'A patient with this national ID already exists.';

  @override
  String toString() => message;
}

/// Notifies its listeners after every write, so List and Map can reload.
class PatientRepository extends ChangeNotifier {
  PatientRepository(
    this._db, {
    required List<Patient> pool,
    Random? random,
    DateTime Function()? now,
  }) : pool = List.unmodifiable(pool),
       _random = random ?? Random(),
       _now = now ?? DateTime.now;

  /// Opens the database and loads the pool. On the very first launch (the
  /// database file was just created) it seeds [sampleSeedCount] patients;
  /// after that the data persists. Arguments are for tests.
  static Future<PatientRepository> open({
    DatabaseFactory? factory,
    String? path,
    AssetBundle? bundle,
    Random? random,
    DateTime Function()? now,
  }) async {
    final opened = await openAppDatabase(
      factory: factory,
      path: path,
      bundle: bundle,
    );
    final repo = PatientRepository(
      opened.db,
      pool: await loadSamplePool(bundle),
      random: random,
      now: now,
    );
    if (opened.created) await repo.seedSampleData();
    return repo;
  }

  final Database _db;
  final Random _random;
  final DateTime Function() _now;

  /// The sample pool (SPEC §6).
  final List<Patient> pool;

  /// Closes the database.
  Future<void> close() => _db.close();

  // ---- reads ----

  /// Patients ordered by name. [query] matches the name or national ID
  /// (dashes ignored). Inactive patients (moved, deceased) are left out
  /// unless [showInactive]; a [status] filter still obeys that.
  Future<List<Patient>> list({
    String query = '',
    CareLevel? careLevel,
    PatientStatus? status,
    bool showInactive = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    final q = query.trim();
    if (q.isNotEmpty) {
      final digits = q.replaceAll(RegExp(r'[\s-]'), '');
      if (RegExp(r'^[0-9]+$').hasMatch(digits)) {
        where.add('(full_name LIKE ? OR national_id LIKE ?)');
        args.addAll(['%$q%', '%$digits%']);
      } else {
        where.add('full_name LIKE ?');
        args.add('%$q%');
      }
    }
    if (careLevel != null) {
      where.add('dependency = ?');
      args.add(careLevel.name);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    if (!showInactive) {
      where.add("status NOT IN ('moved', 'deceased')");
    }
    final rows = await _db.query(
      'patients',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'full_name COLLATE NOCASE',
    );
    return _withChildren(rows);
  }

  Future<Patient?> getById(String id) async {
    final rows = await _db.query('patients', where: 'id = ?', whereArgs: [id]);
    final found = await _withChildren(rows);
    return found.isEmpty ? null : found.single;
  }

  /// Whether a patient other than [exceptId] has [nationalId].
  Future<bool> nationalIdExists(String nationalId, {String? exceptId}) =>
      _nationalIdExists(_db, nationalId, exceptId: exceptId);

  /// A random pool record not yet in the database (by id or national ID), to
  /// prefill Add. Null when all 50 are registered: Add then opens empty.
  Future<Patient?> nextUnusedPoolRecord() async {
    final unused = await _unusedPool(_db);
    return unused.isEmpty ? null : unused[_random.nextInt(unused.length)];
  }

  // ---- writes ----

  /// Inserts [patient] and returns it as saved. [registeredBy] is the
  /// volunteer's name (or [sampleRegisteredBy]); it is set here and never
  /// changed afterwards. An empty `id` gets a new UUID. Throws
  /// [DuplicateNationalIdException].
  Future<Patient> insert(
    Patient patient, {
    required String registeredBy,
  }) async {
    final saved = await _db.transaction(
      (txn) => _insert(txn, patient, registeredBy: registeredBy),
    );
    notifyListeners();
    return saved;
  }

  /// Overwrites the registration (no history). Never changes `id`,
  /// `registered_by` or `created_at`. Throws [DuplicateNationalIdException].
  Future<Patient> update(Patient patient) async {
    await _db.transaction((txn) async {
      if (await _nationalIdExists(
        txn,
        patient.nationalId,
        exceptId: patient.id,
      )) {
        throw DuplicateNationalIdException(patient.nationalId);
      }
      final n = await txn.update(
        'patients',
        {...patient.editableColumns(), 'updated_at': _timestamp()},
        where: 'id = ?',
        whereArgs: [patient.id],
      );
      if (n != 1) throw StateError('No patient with id ${patient.id}');
      await txn.delete(
        'patient_phones',
        where: 'patient_id = ?',
        whereArgs: [patient.id],
      );
      await txn.delete(
        'patient_care_needs',
        where: 'patient_id = ?',
        whereArgs: [patient.id],
      );
      await _insertChildren(txn, patient);
    });
    notifyListeners();
    return (await getById(patient.id))!;
  }

  /// Swipe → Deceased (SPEC §7).
  Future<void> markDeceased(String id) =>
      _setStatus(id, PatientStatus.deceased);

  /// Swipe → Restore: back to active (SPEC §7).
  Future<void> restoreToActive(String id) =>
      _setStatus(id, PatientStatus.active);

  /// First launch: inserts [sampleSeedCount] random pool records.
  Future<void> seedSampleData() async {
    await _db.transaction(_seed);
    notifyListeners();
  }

  // ---- internals ----

  Future<void> _seed(Transaction txn) async {
    final unused = await _unusedPool(txn)
      ..shuffle(_random);
    for (final p in unused.take(sampleSeedCount)) {
      await _insert(txn, p, registeredBy: sampleRegisteredBy);
    }
  }

  Future<Patient> _insert(
    DatabaseExecutor txn,
    Patient patient, {
    required String registeredBy,
  }) async {
    if (await _nationalIdExists(txn, patient.nationalId)) {
      throw DuplicateNationalIdException(patient.nationalId);
    }
    final now = _timestamp();
    final saved = patient.copyWith(
      id: patient.id.isEmpty ? Patient.newId() : patient.id,
      registeredBy: registeredBy,
      createdAt: now,
      updatedAt: now,
    );
    await txn.insert('patients', {
      'id': saved.id,
      ...saved.editableColumns(),
      'registered_by': saved.registeredBy,
      'created_at': saved.createdAt,
      'updated_at': saved.updatedAt,
    });
    await _insertChildren(txn, saved);
    return saved;
  }

  Future<void> _insertChildren(DatabaseExecutor txn, Patient p) async {
    for (final (seq, phone) in p.phones.indexed) {
      await txn.insert('patient_phones', {
        'patient_id': p.id,
        'seq': seq,
        'phone': phone,
      });
    }
    for (final need in p.careNeeds) {
      await txn.insert('patient_care_needs', {
        'patient_id': p.id,
        'need': need.name,
      });
    }
  }

  Future<void> _setStatus(String id, PatientStatus status) async {
    final n = await _db.update(
      'patients',
      {'status': status.name, 'updated_at': _timestamp()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (n != 1) throw StateError('No patient with id $id');
    notifyListeners();
  }

  Future<bool> _nationalIdExists(
    DatabaseExecutor ex,
    String nationalId, {
    String? exceptId,
  }) async {
    final rows = await ex.query(
      'patients',
      columns: ['id'],
      where: exceptId == null
          ? 'national_id = ?'
          : 'national_id = ? AND id <> ?',
      whereArgs: [nationalId, ?exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Patient>> _unusedPool(DatabaseExecutor ex) async {
    final rows = await ex.query('patients', columns: ['id', 'national_id']);
    final ids = {for (final r in rows) r['id']};
    final nids = {for (final r in rows) r['national_id']};
    return [
      for (final p in pool)
        if (!ids.contains(p.id) && !nids.contains(p.nationalId)) p,
    ];
  }

  Future<List<Patient>> _withChildren(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r['id'] as String];
    final marks = List.filled(ids.length, '?').join(', ');
    final phoneRows = await _db.query(
      'patient_phones',
      where: 'patient_id IN ($marks)',
      whereArgs: ids,
      orderBy: 'patient_id, seq',
    );
    final needRows = await _db.query(
      'patient_care_needs',
      where: 'patient_id IN ($marks)',
      whereArgs: ids,
    );
    final phones = <String, List<String>>{};
    for (final r in phoneRows) {
      phones
          .putIfAbsent(r['patient_id'] as String, () => [])
          .add(r['phone'] as String);
    }
    final needs = <String, Set<CareNeed>>{};
    for (final r in needRows) {
      needs
          .putIfAbsent(r['patient_id'] as String, () => {})
          .add(CareNeed.values.byName(r['need'] as String));
    }
    return [
      for (final r in rows)
        Patient.fromRow(
          r,
          phones: phones[r['id']] ?? const [],
          careNeeds: needs[r['id']] ?? const {},
        ),
    ];
  }

  /// Local time as ISO 8601 with its offset, e.g. 2026-11-19T09:00:00+07:00
  /// (the format of the sample pool).
  String _timestamp() {
    final t = _now();
    final local = t.isUtc ? t.toLocal() : t;
    final o = local.timeZoneOffset;
    String two(int n) => n.toString().padLeft(2, '0');
    final sign = o.isNegative ? '-' : '+';
    final base = local.toIso8601String().split('.').first;
    return '$base$sign${two(o.inHours.abs())}:${two(o.inMinutes.abs() % 60)}';
  }
}
