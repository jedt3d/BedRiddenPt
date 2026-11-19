# Sample patient data and the app's SQLite schema

**Every person in these files is fictitious.** Names, national IDs, phone
numbers, contact persons and address notes are generated. All text is in
English; Thai names are romanized (e.g. "Somchai Tantiwong"). National IDs pass the Thai
checksum so the validator can be tested, and they or the phone numbers may
still match a real person by chance. Use them only to test this prototype.

## Files

| File | What it is |
|---|---|
| `gen_bootstrap.dart` | Deterministic generator (fixed seed `20261119`). The only source; everything below is its output. |
| `schema.sql` | **The app's real SQLite schema** (SPEC §5), ready for `sqflite`. |
| `../assets/bootstrap.json` | The 50-record sample pool the app seeds from (camelCase field names). |
| `patients.csv` | Same 50 records, same column names. |
| `seed.sql` | `INSERT`s for all 50, in one transaction, for the `sqlite3` CLI. |
| `ER.md` / `ER.svg` | ER diagram of `schema.sql` (Mermaid source and a rendered copy). |

Don't edit generated files by hand; change the generator and re-run it.

## Regenerate

From the project root (Dart SDK only, no packages):

```bash
dart run data/gen_bootstrap.dart
```

Output is byte-identical on every run. It needs four files from the map-geo
work; if any is missing the script prints which one and writes nothing:

| File | Used for |
|---|---|
| `assets/geo/khlong_san_boundary.geojson` | Khlong San **district** outline; every point is inside it |
| `assets/geo/khlong_san_water.geojson` | River and canals; no point is inside them |
| `assets/geo/khlong_san_subdistricts.geojson` | The four khwaeng, each a feature with an OSM `name:en`; a record's `subdistrict` is the one containing its point |
| `assets/geo/khlong_san_roads.geojson` | Named roads; the road in `address_note` is the nearest one to the point |

Points come from map-geo's `randomPointsInArea` in
`spikes/map_geo/lib/geo/random_points.dart` (10 clusters, 150 m spread). If that
helper moves into the app's `lib/`, update the import at the top of the
generator. The other fields use their own PRNG (mulberry32), so changing the geo
files changes only `lat`, `lng` and `subdistrict`.

## Using the schema with sqflite

`sqflite`'s `execute()` runs **one statement per call**. The source says so
(`sqflite_common` 2.5.11, `lib/sqlite_api.dart`, `DatabaseExecutor.execute`).
In a test, a two-statement string raised no error. So always split the schema:

- Every statement in `schema.sql` ends with `;` at the end of a line, and no
  other line does. Split at line-ending semicolons, drop pieces that are only
  comments or blank, and `execute` each piece.
- `schema.sql` has no `PRAGMA`. Turn on foreign keys in `onConfigure`:

```dart
openDatabase(path,
  version: 1,
  onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
  onCreate: (db, _) async { for (final s in statements) await db.execute(s); },
);
```

This was checked with `sqflite_common_ffi` 2.4.2 (the same `sqflite` API on
desktop SQLite 3.53.2). The 4 statements ran, foreign keys were on, all 50
records inserted from `bootstrap.json`, a duplicate `national_id` failed with
`isUniqueConstraintError()`, and deleting a patient cascaded to its phones. It
was not run on the iOS or Android system SQLite. The schema only uses long-standing
features (`CHECK`, `GLOB`, `substr`, foreign keys).

With the `sqlite3` CLI:

```bash
(echo 'PRAGMA foreign_keys = ON;'; cat data/schema.sql) | sqlite3 patients.db
```

```bash
sqlite3 patients.db < data/seed.sql
```

## Field encodings

| Field | JSON | CSV | SQLite |
|---|---|---|---|
| `phones` | array of strings | values joined with `\|` | table `patient_phones(patient_id, seq, phone)`; `seq` 0 = primary |
| `careNeeds` | array of enum strings | joined with `\|`; empty cell = none | table `patient_care_needs(patient_id, need)` |
| `birthYear` | **Gregorian** int | same | `birth_year`; the UI shows Buddhist era = +543 |
| `subdistrict` | OSM `name:en` of the khwaeng, e.g. `Khlong San Subdistrict` | same | `CHECK` against the four names |
| `null` values | `null` | empty cell | `NULL` |
| enums | camelCase strings | same | same, `CHECK (... IN ...)` |
| timestamps | ISO 8601 with `+07:00` | same | TEXT |

- Phones and IDs are text, so leading zeros survive.
- SQLite column names are the snake_case form of the JSON names
  (`nationalId` → `national_id`).
- CSV: UTF-8 without a BOM, CRLF line ends, RFC 4180 quoting. Excel may garble
  non-ASCII text on double-click; use Data → From Text/CSV and pick UTF-8.

**Why child tables for phones and care needs:** with one row per value, each
phone gets a 10-digit `CHECK`, each care need gets an enum `CHECK`, and "everyone
who needs X" is an indexed query.

**Birth year range:** the schema accepts ages **60–110** counted from 2026
(`birth_year BETWEEN 1916 AND 1966`), and the sample data reaches both ends. SQLite forbids
`date('now')` in a `CHECK`, so the years are fixed: from 2027, a 60-year-old
(born 1967) is rejected until the range is moved.

## Photos

The team-supplied portraits are in `assets/avatars/`, named
`avatar_NN_<sex>_age_<age>.png` (NN = 01–50, 256×256 PNG). Record N (in file
order) uses `avatar_NN`, and `photoPath` holds that path, e.g.
`assets/avatars/avatar_01_female_age_72.png`. The generator reads the folder,
so the files must keep this naming. It stops if an index is missing or
duplicated, or if the split isn't 25 male / 25 female.

Each record takes **sex and age from its avatar's file name**, with no
exceptions. The portraits were made for ages 60–90. To cover the 100+ edge
cases, the four oldest-looking ones were renamed on 2026-11-19:

| Avatar now | Was |
|---|---|
| `avatar_04_female_age_110.png` | `avatar_04_female_age_90.png` |
| `avatar_42_male_age_106.png` | `avatar_42_male_age_90.png` |
| `avatar_07_female_age_103.png` | `avatar_07_female_age_89.png` |
| `avatar_08_male_age_100.png` | `avatar_08_male_age_89.png` |

To change a record's age or sex, rename its avatar and re-run the generator.
A record with no photo file falls back to the initials avatar.

## What the data contains

Fixed by construction and checked in SQLite after each generation:

- 50 records; 25 male, 25 female, ages 60–110, all taken from the avatar file
  names (four aged 100+, one aged exactly 110), so the edges 60 and 110 are
  both present.
- Dependency 10 bedridden / 25 homebound / 15 social; ADL inside each band.
- Status 43 active / 3 deceased / 2 moved / 2 inHospital.
- Living situation 8 livesAlone (never bedridden) / 10 elderlyCaregiver / 32
  withCaregiver. livesAlone records have contact relation `self` (contact
  name = the patient).
- Contact relation: child 16, otherRelative 11, spouse 8, self 8, grandchild 5,
  sibling 2. `neighbour` and `other` are allowed by the schema but unused.
- National IDs unique, 13 digits, valid checksum, all starting `3`.
- 1–2 phone numbers each, all unique, 10 digits, starting 06/08/09.
- `address_note` is `<nearest named road>, <generic landmark>`, e.g. "Soi
  Charoen Nakhon 46, near the grocery shop at the soi entrance". The road is the
  nearest OSM road with an English name (`assets/geo/khlong_san_roads.geojson`,
  via map-geo's `nearestRoad`). Footways, paths, pedestrian ways and service
  roads are left out. Only the capitalization is tidied; the spelling is OSM's.
  The 50 notes use 30 roads, a median of 35 m and at most 190 m from the point.
  No soi number or road name is invented; only the landmark is generic.
- `gpsAccuracyM = null`, `registeredBy = "Sample data"`,
  `createdAt = updatedAt = 2026-11-19T09:00:00+07:00`.
