// All patient reads and writes (SPEC §5–§7). Screens use only this class.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../shared/national_id.dart';
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

/// Saving a national ID that fails the SPEC §5 checksum (or isn't 13 digits).
class InvalidNationalIdException implements Exception {
  const InvalidNationalIdException(this.nationalId);
  final String nationalId;

  /// The message SPEC §7.3 shows under the field.
  static const message = invalidNationalIdMessage;

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
  /// prefill Add, with its status forced to active (SPEC §6). Null when all
  /// 50 are registered: Add then opens empty.
  Future<Patient?> nextUnusedPoolRecord() async {
    final unused = await _unusedPool(_db);
    if (unused.isEmpty) return null;
    return unused[_random.nextInt(unused.length)].copyWith(
      status: PatientStatus.active,
    );
  }

  // ---- writes ----

  /// Inserts [patient] and returns it as saved. [registeredBy] is the
  /// volunteer's name (or [sampleRegisteredBy]); it is set here and never
  /// changed afterwards. An empty `id` gets a new UUID. The care level is
  /// derived from the ADL score when there is one. Throws
  /// [InvalidNationalIdException] or [DuplicateNationalIdException].
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
  /// `registered_by` or `created_at`. The care level is derived from the ADL
  /// score when there is one. Status: a deceased patient stays deceased
  /// (restore is [restoreToActive]), and an edit can't make anyone deceased
  /// (that is [markDeceased]); setting status deceased throws
  /// [ArgumentError]. Throws [InvalidNationalIdException] or
  /// [DuplicateNationalIdException].
  Future<Patient> update(Patient patient) async {
    await _db.transaction((txn) async {
      await _checkNationalId(txn, patient.nationalId, exceptId: patient.id);
      final stored = await txn.query(
        'patients',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [patient.id],
      );
      if (stored.isEmpty) throw StateError('No patient with id ${patient.id}');
      final wasDeceased =
          stored.single['status'] == PatientStatus.deceased.name;
      if (!wasDeceased && patient.status == PatientStatus.deceased) {
        throw ArgumentError.value(
          patient.status,
          'status',
          'Use markDeceased to mark a patient deceased',
        );
      }
      final saved = _withDerivedCareLevel(
        patient,
      ).copyWith(status: wasDeceased ? PatientStatus.deceased : patient.status);
      await txn.update(
        'patients',
        {...saved.editableColumns(), 'updated_at': _timestamp()},
        where: 'id = ?',
        whereArgs: [patient.id],
      );
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

  /// Swipe → Deceased (SPEC §7). Only changes a patient who isn't deceased
  /// yet; returns whether it changed anything.
  Future<bool> markDeceased(String id) =>
      _setStatus(id, PatientStatus.deceased, onlyIf: "status <> 'deceased'");

  /// Swipe → Restore: deceased back to active (SPEC §7). Only changes a
  /// deceased patient; returns whether it changed anything.
  Future<bool> restoreToActive(String id) =>
      _setStatus(id, PatientStatus.active, onlyIf: "status = 'deceased'");

  /// First launch: inserts [sampleSeedCount] random active pool records.
  Future<void> seedSampleData() async {
    await _db.transaction(_seed);
    notifyListeners();
  }

  /// Replaces all patients with [sampleSeedCount] new random active pool
  /// records (SPEC §6).
  /// Only touches the database, so the volunteer's name is kept.
  Future<void> resetSampleData() async {
    await _db.transaction((txn) async {
      await txn.delete('patients'); // phones and care needs cascade
      await _seed(txn);
    });
    notifyListeners();
  }

  // ---- internals ----

  Future<void> _seed(Transaction txn) async {
    final unused = [
      for (final p in await _unusedPool(txn))
        if (p.status == PatientStatus.active) p,
    ]..shuffle(_random);
    for (final p in unused.take(sampleSeedCount)) {
      await _insert(txn, p, registeredBy: sampleRegisteredBy);
    }
  }

  Future<Patient> _insert(
    DatabaseExecutor txn,
    Patient patient, {
    required String registeredBy,
  }) async {
    await _checkNationalId(txn, patient.nationalId);
    final now = _timestamp();
    final saved = _withDerivedCareLevel(patient).copyWith(
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

  Future<bool> _setStatus(
    String id,
    PatientStatus status, {
    required String onlyIf,
  }) async {
    final n = await _db.update(
      'patients',
      {'status': status.name, 'updated_at': _timestamp()},
      where: 'id = ? AND $onlyIf',
      whereArgs: [id],
    );
    if (n == 0) {
      if (await getById(id) == null) throw StateError('No patient with id $id');
      return false;
    }
    notifyListeners();
    return true;
  }

  /// Care level follows the ADL score bands (SPEC §5) when a score is set.
  Patient _withDerivedCareLevel(Patient p) {
    final adl = p.adlScore;
    return adl == null ? p : p.copyWith(careLevel: CareLevel.fromAdl(adl));
  }

  Future<void> _checkNationalId(
    DatabaseExecutor ex,
    String nationalId, {
    String? exceptId,
  }) async {
    if (!isValidNationalId(nationalId)) {
      throw InvalidNationalIdException(nationalId);
    }
    if (await _nationalIdExists(ex, nationalId, exceptId: exceptId)) {
      throw DuplicateNationalIdException(nationalId);
    }
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
