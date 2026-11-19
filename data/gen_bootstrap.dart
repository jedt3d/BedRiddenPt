// Deterministic generator for the 50 bootstrap (sample) patient records.
//
// Run from the project root:   dart run data/gen_bootstrap.dart
//
// Writes, all from the same in-memory records:
//   assets/bootstrap.json   (SPEC §5 field names, camelCase)
//   data/patients.csv       (same field names; list fields joined with '|')
//   data/schema.sql         (SQLite DDL)
//   data/seed.sql           (INSERTs in one transaction)
//
// Every person, ID, phone number and address note is FICTITIOUS.
//
// No pubspec is needed: it uses dart: libraries plus the map-geo session's
// pure-Dart helper (spikes/map_geo/lib/geo/random_points.dart). Record fields
// come from a hand-written PRNG (mulberry32), because dart:math Random does not
// promise the same sequence for a seed across SDK versions. Coordinates come
// from the helper (it uses dart:math Random with its own seed), so changing the
// geo files changes no other field.
//
// Coordinates and subdistrict (all three geo files required; nothing is
// written if one is missing):
//   assets/geo/khlong_san_boundary.geojson     Khlong San DISTRICT outline
//   assets/geo/khlong_san_water.geojson        river/canal, excluded
//   assets/geo/khlong_san_subdistricts.geojson the four khwaeng; a point's
//                                              subdistrict = the one containing it

import 'dart:convert';
import 'dart:io';

import '../spikes/map_geo/lib/geo/nearest_road.dart';
import '../spikes/map_geo/lib/geo/random_points.dart';

const int seed = 20261119;
const int recordCount = 50;
const int referenceYear = 2026; // ages are computed as referenceYear - birthYear
const String fixedTimestamp = '2026-11-19T09:00:00+07:00';
// Record N uses the team-supplied portrait assets/avatars/avatar_NN_<sex>_age_<age>.png
// and takes its sex and age from the file name, so photo and record agree.
// The sample must include ages 100+ and exactly 110 (schema CHECK:
// birth_year 1916..1966 = ages 60..110 in 2026). The portraits were made for
// ages 60..90, so the four oldest-looking ones were renamed to ages 110, 106,
// 103, 100 (avatars 04, 42, 07, 08; originally 90, 90, 89, 89).
const String avatarDir = 'assets/avatars';
const String boundaryPath = 'assets/geo/khlong_san_boundary.geojson';
const String waterPath = 'assets/geo/khlong_san_water.geojson';
const String subdistrictsPath = 'assets/geo/khlong_san_subdistricts.geojson';
// Named OSM roads (map-geo). addressNote = nearest named road + generic landmark.
const String roadsPath = 'assets/geo/khlong_san_roads.geojson';
// Road types used in addresses: footway, path, pedestrian and service are left out.
const roadHighways = {
  'primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary',
  'residential', 'unclassified',
};
// The four khwaeng of Khlong San district, exactly as OSM `name:en` in
// subdistrictsPath (relations 11355107..11355110). The script checks this.
const subdistrictNames = [
  'Somdet Chao Phraya Subdistrict', 'Khlong San Subdistrict',
  'Khlong Ton Sai Subdistrict', 'Bang Lamphu Lang Subdistrict',
];
const int coordSeed = seed + 1;
const int clusterCount = 10;
const double clusterSpreadM = 150;

// ---------------------------------------------------------------- PRNG

class Mulberry32 {
  int _s;
  Mulberry32(int seed) : _s = seed & 0xFFFFFFFF;
  int nextU32() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;
  double nextDouble() => nextU32() / 4294967296.0;
  int nextInt(int n) => (nextDouble() * n).floor();
  bool chance(double p) => nextDouble() < p;
  T pick<T>(List<T> xs) => xs[nextInt(xs.length)];
  void shuffle<T>(List<T> xs) {
    for (var i = xs.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = xs[i];
      xs[i] = xs[j];
      xs[j] = t;
    }
  }
}

// ---------------------------------------------------------------- vocab

// Romanized (RTGS-style) Thai names. Each list keeps the length and order of
// the Thai list it replaced, so the PRNG draws, and with them every ID, date,
// phone and coordinate, are unchanged.
const maleFirst = [
  'Somchai', 'Somsak', 'Bunmi', 'Prasoet', 'Wichai', 'Somphong', 'Chan', 'Thongdi',
  'Suchat', 'Bunsong', 'Prayun', 'Sombat', 'Sathian', 'Amnuai', 'Wirat', 'Manop',
  'Sommai', 'Prasit', 'Chamlong', 'Surin', 'Chaloem', 'Bunloet', 'Phairot',
  'Sa-ngat', 'Anan', 'Chaiwat', 'Suwit', 'Narong', 'Prachuap', 'Phayung',
];
const femaleFirst = [
  'Somsi', 'Bunruean', 'Thongbai', 'Mali', 'Somchit', 'Pranom', 'La-iat', 'Suni',
  'Bang-on', 'Chanphen', 'Lamduan', 'Somphon', 'Amphai', 'Wanphen', 'Praphai', 'Saiyut',
  'Bunma', 'Yaowalak', 'Phayao', 'Suphap', 'Nongluk', 'Sinuan', 'Samran',
  'Lamom', 'Kimlang', 'Chawiwan', 'Phensi', 'Urai', 'Chamnian', 'Thongkham',
];
// Younger-generation names for contact persons (children, grandchildren).
const youngMale = [
  'Thanaphon', 'Wiraphong', 'Aphichat', 'Kittisak', 'Natthawut', 'Piya', 'Surachet',
  'Atthaphon', 'Chakkraphan', 'Thirawat',
];
const youngFemale = [
  'Kamonwan', 'Suphawadi', 'Chiraphon', 'Pawina', 'Wanna', 'Aruni', 'Siriphon', 'Naphaphon',
  'Phonthip', 'Rattana',
];
const surnames = [
  'Chaidi', 'Saengthong', 'Sisuk', 'Bunprasoet', 'Misuk', 'Thongma', 'Wongyai',
  'Kaeomani', 'Chanhom', 'Sukcharoen', 'Phuengbun', 'Rueangsi', 'Chuenchit',
  'Nakprasoet', 'Inkaeo', 'Panthong', 'Rungrueang', 'Saisuwan', 'Sapmak',
  'Phetcharat', 'Klinhom', 'Bunyuen', 'Sakdi', 'Khongsombun', 'Prasoetwong',
  'Sae-tang', 'Sae-lim', 'Tantiwong', 'Siwilai', 'Phunsawat', 'Mankhong', 'Ketkaeo',
  'Sombunchai', 'Onsi', 'Phuthong', 'Duangkaeo', 'Chitdi', 'Iamsa-at',
  'Suwannarat', 'Watthanaphong',
];
// Generic landmarks only: no real road, temple or shop names are claimed.
const landmarks = [
  'near the grocery shop at the soi entrance', 'opposite the community hall',
  'blue fence, iron gate', 'end of the soi, next to the canal',
  'next to the motorcycle repair shop', 'near the spirit house at the soi entrance',
  'two-storey wooden house, third from the soi entrance', 'diagonally opposite the noodle shop',
  'next to the community car park', 'mango tree in front of the house',
  'narrow alley, about 50 m in', 'near the bus stop', 'next to the pharmacy',
  'shophouse, 2nd floor, stairs at the side',
];
const notesPool = [
  '', '', '', 'Family asks for a phone call before a visit', 'Dog in the house',
  'Caregiver is home in the evenings', 'Already receives the elderly allowance',
  'Needs physiotherapy at home', 'Narrow entrance, hard for a wheelchair',
];

const conditionByDependency = {
  'bedridden': ['stroke', 'stroke', 'stroke', 'spinalInjury', 'cancer', 'dementia'],
  'homebound': ['stroke', 'dementia', 'dementia', 'frailty', 'frailty', 'other'],
  'social': ['frailty', 'frailty', 'other', 'other', 'stroke', 'dementia'],
};
const careNeedChance = {
  'bedridden': {'bedsore': .45, 'feedingTube': .3, 'catheter': .3, 'oxygen': .15, 'needsAirMattress': .6, 'needsWheelchair': .2},
  'homebound': {'bedsore': .08, 'feedingTube': 0.0, 'catheter': .08, 'oxygen': .1, 'needsAirMattress': .08, 'needsWheelchair': .55},
  'social': {'bedsore': 0.0, 'feedingTube': 0.0, 'catheter': 0.0, 'oxygen': .05, 'needsAirMattress': 0.0, 'needsWheelchair': .2},
};
const careNeedOrder = ['bedsore', 'feedingTube', 'catheter', 'oxygen', 'needsAirMattress', 'needsWheelchair'];

// ---------------------------------------------------------------- helpers

/// Thai national ID: d13 = (11 - Σ_{i=1..12} d_i × (14 − i) mod 11) mod 10.
int thaiCheckDigit(String first12) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(first12[i]) * (13 - i); // i is 0-based, so 14-(i+1)
  }
  return (11 - sum % 11) % 10;
}

bool isValidThaiId(String id) =>
    RegExp(r'^\d{13}$').hasMatch(id) && thaiCheckDigit(id.substring(0, 12)) == int.parse(id[12]);

String uuidV4(Mulberry32 r) {
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String digits(Mulberry32 r, int n) => List.generate(n, (_) => r.nextInt(10)).join();

// ---------------------------------------------------------------- records

typedef Avatar = ({int index, String sex, int age, String path});

/// Reads assets/avatars and checks there is exactly one avatar per record
/// (indices 1..recordCount), 25 male and 25 female.
List<Avatar> loadAvatars() {
  final re = RegExp(r'^avatar_(\d{2})_(male|female)_age_(\d+)\.png$');
  final byIndex = <int, Avatar>{};
  for (final f in Directory(avatarDir).listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    final m = re.firstMatch(name);
    if (m == null) continue;
    final i = int.parse(m[1]!);
    if (byIndex.containsKey(i)) throw StateError('two avatars with index $i');
    byIndex[i] = (index: i, sex: m[2]!, age: int.parse(m[3]!), path: '$avatarDir/$name');
  }
  final list = [for (var i = 1; i <= recordCount; i++) byIndex[i] ?? (throw StateError('avatar $i missing in $avatarDir'))];
  final males = list.where((a) => a.sex == 'male').length;
  if (males != recordCount ~/ 2) throw StateError('avatars: $males male, need ${recordCount ~/ 2}');
  return list;
}

List<Map<String, dynamic>> buildRecords() {
  final r = Mulberry32(seed);

  final avatars = loadAvatars();
  final sexes = [for (final a in avatars) a.sex];
  final ages = [for (final a in avatars) a.age];
  final dependency = [
    ...List.filled(10, 'bedridden'), ...List.filled(25, 'homebound'), ...List.filled(15, 'social'),
  ]..let(r.shuffle);
  final status = [
    ...List.filled(3, 'deceased'), ...List.filled(2, 'moved'), ...List.filled(2, 'inHospital'),
    ...List.filled(43, 'active'),
  ]..let(r.shuffle);

  // Living situation: 8 livesAlone, never bedridden; 10 elderlyCaregiver; rest withCaregiver.
  final living = List.filled(recordCount, 'withCaregiver');
  final notBedridden = [for (var i = 0; i < recordCount; i++) if (dependency[i] != 'bedridden') i]..let(r.shuffle);
  for (final i in notBedridden.take(8)) living[i] = 'livesAlone';
  final rest = [for (var i = 0; i < recordCount; i++) if (living[i] != 'livesAlone') i]..let(r.shuffle);
  for (final i in rest.take(10)) living[i] = 'elderlyCaregiver';

  final maleNames = [...maleFirst]..let(r.shuffle);
  final femaleNames = [...femaleFirst]..let(r.shuffle);
  var mi = 0, fi = 0;

  final ids = <String>{}, phones = <String>{}, names = <String>{};
  final out = <Map<String, dynamic>>[];

  for (var n = 0; n < recordCount; n++) {
    final sex = sexes[n];
    final first = sex == 'male' ? maleNames[mi++] : femaleNames[fi++];
    String surname;
    do {
      surname = r.pick(surnames);
    } while (names.contains('$first $surname'));
    names.add('$first $surname');
    final fullName = '$first $surname';

    // National ID: type 3 (registered before 1984, fits everyone born ≤1966),
    // then a Bangkok-style 4-digit area code, random serial, check digit.
    String nid;
    do {
      final first12 = '3${r.pick(['1018', '1001', '1015', '1020'])}${digits(r, 7)}';
      nid = '$first12${thaiCheckDigit(first12)}';
    } while (!ids.add(nid));

    final dep = dependency[n];
    final adl = switch (dep) {
      'bedridden' => r.nextInt(5),
      'homebound' => 5 + r.nextInt(7),
      _ => 12 + r.nextInt(9),
    };
    final cond = r.pick(conditionByDependency[dep]!);
    final needs = [for (final k in careNeedOrder) if (r.chance(careNeedChance[dep]![k]!)) k];

    // Contact person: the one person to call (GLOSSARY.md).
    final liv = living[n];
    String cName, cRel;
    if (liv == 'livesAlone') {
      cName = fullName;
      cRel = 'self';
    } else if (liv == 'elderlyCaregiver') {
      if (r.chance(.7)) {
        cRel = 'spouse';
        cName = sex == 'male' ? '${r.pick(femaleFirst)} $surname' : '${r.pick(maleFirst)} $surname';
      } else {
        cRel = 'sibling';
        final cm = r.chance(.5);
        cName = cm ? '${r.pick(maleFirst)} $surname' : '${r.pick(femaleFirst)} $surname';
      }
    } else {
      // Six entries, as before, so the PRNG stream is unchanged.
      cRel = r.pick(['child', 'child', 'child', 'grandchild', 'otherRelative', 'otherRelative']);
      final cm = r.chance(.4);
      final cFirst = cm ? r.pick(youngMale) : r.pick(youngFemale);
      final cSur = (cRel == 'child' || cRel == 'grandchild') && r.chance(.7) ? surname : r.pick(surnames);
      if (!cm) r.chance(.5); // was the Thai title choice; kept to preserve the PRNG stream
      cName = '$cFirst $cSur';
    }

    final phoneCount = r.chance(.3) ? 2 : 1;
    final ph = <String>[];
    while (ph.length < phoneCount) {
      final p = '0${r.pick(['6', '8', '9'])}${digits(r, 8)}';
      if (phones.add(p)) ph.add(p);
    }

    final st = status[n];
    var note = r.pick(notesPool);
    if (st == 'deceased') note = 'Deceased, record kept';
    if (st == 'moved') note = 'Moved to live with a child in another province';
    if (st == 'inHospital') note = 'Currently in hospital';

    out.add({
      'id': uuidV4(r),
      'nationalId': nid,
      'fullName': fullName,
      'sex': sex,
      'birthYear': referenceYear - ages[n],
      'photoPath': avatars[n].path,
      'contactName': cName,
      'contactRelation': cRel,
      'phones': ph,
      'subdistrict': null, // filled from coordinates
      'addressNote': landmarkAfterUnusedDraw(r), // road name prepended in addCoordinates
      'lat': null,
      'lng': null,
      'gpsAccuracyM': null,
      'dependency': dep,
      'adlScore': adl,
      'mainCondition': cond,
      'careNeeds': needs,
      'livingSituation': liv,
      'status': st,
      'notes': note,
      'registeredBy': 'Sample data',
      'createdAt': fixedTimestamp,
      'updatedAt': fixedTimestamp,
    });
  }
  return out;
}

/// The generic landmark for an address note. The draw before it used to pick a
/// soi number; it is kept (unused) so the PRNG stream, and every other field,
/// stays the same. Soi numbers are no longer invented: the road name comes from
/// OSM instead.
String landmarkAfterUnusedDraw(Mulberry32 r) {
  r.nextInt(20);
  return r.pick(landmarks);
}

/// Capitalizes each word of an OSM English road name ("Lat ya 3" -> "Lat Ya 3").
/// Spelling is left exactly as in OSM.
String tidyRoadName(String name) => name
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Fills lat/lng, subdistrict and the road part of addressNote. Points come from map-geo's
/// randomPointsInArea (clustered, inside the district, outside water); the
/// subdistrict is the khwaeng polygon that contains the point.
/// Returns an error message, or null on success.
String? addCoordinates(List<Map<String, dynamic>> recs) {
  for (final f in [boundaryPath, waterPath, subdistrictsPath, roadsPath]) {
    if (!File(f).existsSync()) return '$f not found';
  }
  final district = GeoArea.fromGeoJson(File(boundaryPath).readAsStringSync(),
      exclude: [File(waterPath).readAsStringSync()]);

  final subs = <String, GeoArea>{};
  final fc = jsonDecode(File(subdistrictsPath).readAsStringSync()) as Map;
  for (final f in fc['features'] as List) {
    final name = (f['properties'] as Map)['name:en'] as String?;
    if (name == null) return 'a feature in $subdistrictsPath has no name:en';
    subs[name] = GeoArea.fromGeoJson(jsonEncode(f));
  }
  final names = subs.keys.toSet();
  if (names.length != subdistrictNames.length || !names.containsAll(subdistrictNames)) {
    return 'subdistrict names in $subdistrictsPath are $names, expected $subdistrictNames';
  }

  final roads = NamedRoads.fromGeoJson(File(roadsPath).readAsStringSync());
  final pts = randomPointsInArea(district, recs.length,
      clusters: clusterCount, spreadM: clusterSpreadM, seed: coordSeed);
  for (var i = 0; i < recs.length; i++) {
    final p = pts[i].point;
    final hits = [for (final e in subs.entries) if (e.value.contains(p.lat, p.lng)) e.key];
    if (hits.length != 1) {
      return 'point ${p.lat},${p.lng} is in ${hits.length} subdistricts ($hits)';
    }
    recs[i]['lat'] = double.parse(p.lat.toStringAsFixed(6));
    recs[i]['lng'] = double.parse(p.lng.toStringAsFixed(6));
    recs[i]['subdistrict'] = hits.single;
    final road = roads.nearestRoad(recs[i]['lat'], recs[i]['lng'], highways: roadHighways);
    if (road == null) return 'no named road found for record ${i + 1}';
    recs[i]['addressNote'] = '${tidyRoadName(road.nameEn)}, ${recs[i]['addressNote']}';
  }
  return null;
}

// ---------------------------------------------------------------- writers

String csvField(Object? v) {
  final s = switch (v) { null => '', List l => l.join('|'), _ => '$v' };
  return RegExp(r'[",\r\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

String sqlLit(Object? v) => switch (v) {
      null => 'NULL',
      bool b => b ? '1' : '0',
      num n => '$n',
      _ => "'${'$v'.replaceAll("'", "''")}'",
    };

const columns = [
  'id', 'nationalId', 'fullName', 'sex', 'birthYear', 'photoPath', 'contactName',
  'contactRelation', 'phones', 'subdistrict', 'addressNote', 'lat', 'lng', 'gpsAccuracyM',
  'dependency', 'adlScore', 'mainCondition', 'careNeeds', 'livingSituation', 'status',
  'notes', 'registeredBy', 'createdAt', 'updatedAt',
];

String snake(String c) => c.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

String buildCsv(List<Map<String, dynamic>> recs) {
  final b = StringBuffer()..write('${columns.join(',')}\r\n');
  for (final rec in recs) {
    b.write('${columns.map((c) => csvField(rec[c])).join(',')}\r\n');
  }
  return b.toString();
}

const schemaSql = '''
-- SQLite schema of the app (SPEC section 5). Generated by
-- data/gen_bootstrap.dart, so edit the generator, not this file.
--
-- sqflite runs ONE statement per execute() call. Every statement here ends
-- with a semicolon at the end of its last line, and no other line ends with
-- one, so splitting the file at every line-ending semicolon gives the
-- statements (then drop pieces that are only comments or blank).
-- No PRAGMA here: enable foreign keys in sqflite's onConfigure with
-- "PRAGMA foreign_keys = ON" (with the sqlite3 CLI, run it yourself first).

CREATE TABLE patients (
  id                TEXT PRIMARY KEY
                    CHECK (length(id) = 36),
  national_id       TEXT NOT NULL UNIQUE
                    CHECK (length(national_id) = 13
                       AND national_id NOT GLOB '*[^0-9]*'
                       -- Thai checksum: d13 = (11 - sum(d_i * (14 - i)) % 11) % 10
                       AND (11 - (substr(national_id,1,1)*13 + substr(national_id,2,1)*12
                                + substr(national_id,3,1)*11 + substr(national_id,4,1)*10
                                + substr(national_id,5,1)*9  + substr(national_id,6,1)*8
                                + substr(national_id,7,1)*7  + substr(national_id,8,1)*6
                                + substr(national_id,9,1)*5  + substr(national_id,10,1)*4
                                + substr(national_id,11,1)*3 + substr(national_id,12,1)*2) % 11) % 10
                           = CAST(substr(national_id,13,1) AS INTEGER)),
  full_name         TEXT NOT NULL CHECK (length(trim(full_name)) > 0),
  sex               TEXT NOT NULL CHECK (sex IN ('male','female')),
  -- Gregorian year, the UI shows Buddhist era (+543). Accepts ages 60..110
  -- counted from 2026. SQLite forbids date('now') in CHECK, so the years are
  -- fixed: from 2027 a 60-year-old (born 1967) is rejected until this changes.
  birth_year        INTEGER NOT NULL CHECK (birth_year BETWEEN 1916 AND 1966),
  photo_path        TEXT,
  -- The contact person: the one person to call, possibly the patient (self).
  contact_name      TEXT NOT NULL,
  contact_relation  TEXT NOT NULL CHECK (contact_relation IN
                      ('self','spouse','child','grandchild','sibling','otherRelative','neighbour','other')),
  -- OSM name:en of the four khwaeng (assets/geo/khlong_san_subdistricts.geojson).
  subdistrict       TEXT NOT NULL CHECK (subdistrict IN
                      ('Somdet Chao Phraya Subdistrict','Khlong San Subdistrict',
                       'Khlong Ton Sai Subdistrict','Bang Lamphu Lang Subdistrict')),
  address_note      TEXT NOT NULL DEFAULT '',
  -- Inside the Khlong San district boundary.
  lat               REAL NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng               REAL NOT NULL CHECK (lng BETWEEN -180 AND 180),
  gps_accuracy_m    REAL CHECK (gps_accuracy_m IS NULL OR gps_accuracy_m >= 0),
  dependency        TEXT NOT NULL CHECK (dependency IN ('bedridden','homebound','social')),
  adl_score         INTEGER CHECK (adl_score IS NULL OR adl_score BETWEEN 0 AND 20),
  main_condition    TEXT NOT NULL CHECK (main_condition IN
                      ('stroke','dementia','frailty','spinalInjury','cancer','other')),
  living_situation  TEXT NOT NULL CHECK (living_situation IN
                      ('withCaregiver','livesAlone','elderlyCaregiver')),
  status            TEXT NOT NULL CHECK (status IN ('active','inHospital','moved','deceased')),
  notes             TEXT NOT NULL DEFAULT '',
  -- Volunteer who first saved the patient, never changed by edits.
  registered_by     TEXT NOT NULL,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL,
  -- ADL score must match the dependency band.
  CHECK (adl_score IS NULL
      OR (dependency = 'bedridden' AND adl_score BETWEEN 0 AND 4)
      OR (dependency = 'homebound' AND adl_score BETWEEN 5 AND 11)
      OR (dependency = 'social'    AND adl_score BETWEEN 12 AND 20))
);

-- The contact person's phone numbers, one row each. seq keeps the order, 0 = primary (the one Call dials).
CREATE TABLE patient_phones (
  patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  seq        INTEGER NOT NULL CHECK (seq >= 0),
  phone      TEXT NOT NULL CHECK (length(phone) = 10 AND phone NOT GLOB '*[^0-9]*'),
  PRIMARY KEY (patient_id, seq),
  UNIQUE (patient_id, phone)
);

-- One row per care need. A set, so no order column.
CREATE TABLE patient_care_needs (
  patient_id TEXT NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  need       TEXT NOT NULL CHECK (need IN
               ('bedsore','feedingTube','catheter','oxygen','needsAirMattress','needsWheelchair')),
  PRIMARY KEY (patient_id, need)
);

CREATE INDEX idx_patient_care_needs_need ON patient_care_needs(need);
''';

String buildSeed(List<Map<String, dynamic>> recs) {
  final scalar = columns.where((c) => c != 'phones' && c != 'careNeeds').toList();
  final b = StringBuffer()
    ..writeln('-- Sample data: 50 FICTITIOUS patients. Generated by data/gen_bootstrap.dart.')
    ..writeln('PRAGMA foreign_keys = ON;')
    ..writeln('BEGIN TRANSACTION;');
  for (final rec in recs) {
    b.writeln('INSERT INTO patients (${scalar.map(snake).join(', ')}) VALUES '
        '(${scalar.map((c) => sqlLit(rec[c])).join(', ')});');
    final ph = rec['phones'] as List;
    for (var i = 0; i < ph.length; i++) {
      b.writeln('INSERT INTO patient_phones (patient_id, seq, phone) VALUES '
          '(${sqlLit(rec['id'])}, $i, ${sqlLit(ph[i])});');
    }
    for (final need in rec['careNeeds'] as List) {
      b.writeln('INSERT INTO patient_care_needs (patient_id, need) VALUES '
          '(${sqlLit(rec['id'])}, ${sqlLit(need)});');
    }
  }
  b.writeln('COMMIT;');
  return b.toString();
}

// ---------------------------------------------------------------- main

void main() {
  final recs = buildRecords();
  for (final rec in recs) {
    if (!isValidThaiId(rec['nationalId'])) throw StateError('bad ID ${rec['nationalId']}');
  }
  // The schema does not depend on geo data, so it is always written.
  File('data/schema.sql').writeAsStringSync(schemaSql);
  final geoError = addCoordinates(recs);
  if (geoError != null) {
    stderr.writeln('ERROR: $geoError. Coordinates and subdistrict are required. '
        'Wrote data/schema.sql only; bootstrap.json, patients.csv and seed.sql NOT written.');
    exitCode = 1;
    return;
  }

  Directory('assets').createSync(recursive: true);
  File('assets/bootstrap.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(recs)}\n');
  File('data/patients.csv').writeAsStringSync(buildCsv(recs));
  File('data/seed.sql').writeAsStringSync(buildSeed(recs));

  stdout.writeln('wrote ${recs.length} records (seed $seed) to assets/bootstrap.json, '
      'data/patients.csv, data/schema.sql, data/seed.sql');
}

extension<T> on T {
  void let(void Function(T) f) => f(this);
}
