# Bedridden Patient Locator — Prototype Spec (Draft 3)

Date: 2026-11-19 · Status: draft 3, **implemented** on `main` (issues #1–#28 on GitHub; see `docs/STATUS.md`). Includes the grilling session decisions (terms in `GLOSSARY.md`). Timebox was 1–2 hours of build; the actual build took about 2 h 40 min (§9)

**Changes in draft 3**
- UI uses Flutter's **Cupertino** (iOS-style) widgets.
- Data **persists** between launches. **Reset sample data** is in the top-right ⋮ menu of the PIN screen.
- **No delete.** Swipe left on a list row → **Deceased** (with confirmation). Inactive patients (moved or deceased) are hidden unless **Show inactive** is on.
- "Guardian" becomes **contact person**, with a fixed relationship list. `recorded_by` becomes **registered by**, set once.
- Sample text is **romanized/English**.
- One registration per patient; **no visit history**.
- The **PIN is fixed at `000000`** (no PIN setup, can't be changed). First launch asks once for the volunteer's name.
- **Restore** a deceased patient by swiping its row (Show inactive on) → green **Restore**; the form's "Restore to active" link is dropped.
- §7 now follows the 25-frame Figma prototype: no tab bar on Detail/Add/Edit, care level derived from ADL, birth year typed in B.E., national ID shown as `3-XXXX-XXXXX-XX-X`, "Use my location" also sets the subdistrict, moved patients can be marked deceased.

**Changes from draft 1**
- The area is the **Khlong San district, Bangkok**.
- Storage is **SQLite on the phone** (was a JSON file).
- The app starts with **5 random records**.
- A duplicate national ID **blocks saving**.
- The UI is **English only**.
- The **consent/PDPA field is removed**.
- Birth year is **stored as Gregorian and shown as Buddhist era**.
- `villageNo` is replaced by subdistrict + soi/road (§5).

## 1. Purpose

A mobile app for volunteers to visit homes, record where each bedridden or
homebound patient lives, and capture basic demographics and care needs.
A **patient** is any elderly person a volunteer registers, whatever their care
level: social (independent) patients are registered too, because care levels
change over time. Each phone belongs to one volunteer.
**Prototype only:** it will not be used with real patients, so privacy and
legal compliance (PDPA) are deliberately out of scope. It must work end to end
in the iOS Simulator.

## 2. Platform and stack

| Concern | Choice | Notes |
|---|---|---|
| App framework | **Flutter** 3.47.9 / Dart 3.13.7 (installed) | iOS Simulator first; Android should work unchanged |
| UI widgets | **Cupertino** (`CupertinoApp`, `CupertinoTabScaffold`, `CupertinoListSection`, `CupertinoTextField`, `CupertinoAlertDialog`, `CupertinoActionSheet`) | No Material widgets in screens |
| Map widget | **`flutter_map` 8.3.2** + `latlong2` 0.10.1 | Pure Dart, no API key |
| Map tiles | **OpenStreetMap** `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | Needs internet; see §8 |
| Database | **`sqflite` 2.4.6**, a local SQLite file | Device only, nothing sent to a server |
| Location | `geolocator` 14.1.2 | `getCurrentPosition(locationSettings: LocationSettings(accuracy: best))`; `Position.accuracy` is metres |
| Area | **Khlong San District (เขตคลองสาน), Bangkok**: OSM relation 3147280, ≈ 5.96 km², 4 subdistricts (§3) | Files in `assets/geo/`; source and attribution in `assets/geo/README.md` |
| Map start view | Center **13.7228, 100.5023** (district centroid), zoom **14.5** as the start; the Map tab then **fits the whole district outline** in its map area (≈ zoom 14.3 on iPhone 16 Pro), as in Figma frame 14 | Spike verified 14.5 full-screen; the Map tab's map is shorter (legend below), so it fits to the outline (PR #63) |
| Photo | `image_picker` 1.2.4 | Simulator has no camera → gallery |
| Photo files | `path_provider` 2.1.6 | Picked photos are copied into the app documents folder; `photo_path` stores only the **file name** (iOS container paths change on reinstall) |
| Call / navigate | `url_launcher` 6.3.3 | `tel:` and an Apple Maps URL |
| Volunteer name | `shared_preferences` 2.5.6 | Plain storage, no encryption (accepted). The PIN is the constant `000000` in code, not stored |
| Tests (dev only) | `sqflite_common_ffi` 2.4.2 (`dev_dependencies`) | Runs the real `data/schema.sql` in an in-memory DB under `flutter test`; not shipped. `data/schema.sql` is listed under `flutter: assets:` and loaded at first launch. New patient ids are UUID v4 from `Random.secure()` (no `uuid` package) |

### Map decision — Google Maps rejected

**Leaflet** is a JavaScript map library for web apps and doesn't fit Flutter.
**OpenStreetMap** is the map data and tiles. We use **`flutter_map`**, a
Leaflet-style Flutter package, to draw OpenStreetMap tiles.

It needs no Google Cloud project, billing or API key, and no native key setup,
and it works in the iOS Simulator as is.

```dart
FlutterMap(
  options: MapOptions(initialCenter: LatLng(13.7228, 100.5023), initialZoom: 14.5),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.bedriddenPt', // iOS bundle id from flutter create; required by OSM policy
    ),
    PolygonLayer(polygons: [districtBoundary]),           // Khlong San outline
    MarkerLayer(markers: [
      Marker(point: LatLng(lat, lng), child: Icon(Icons.location_pin, color: color)),
    ]),
  ],
)
```

Don't use the old `{s}.tile.openstreetmap.org` subdomain URL.

## 3. Area: Khlong San district, Bangkok

- Boundary: the OpenStreetMap administrative boundary of Khlong San district, saved as `assets/geo/khlong_san_boundary.geojson`. Source, OSM relation id and retrieval date go in `assets/geo/README.md`, with the attribution "© OpenStreetMap contributors (ODbL)".
- Boundary in OSM: relation **3147280** (`admin_level=6`), ≈ 5.96 km², ≈ 3.8 km N–S × 2.2 km E–W. Retrieved 2026-11-19.
- Center point: **13.7228, 100.5023** (area centroid of the district polygon; on land, in Khlong Ton Sai). Starting zoom: **14.5**, which fits the whole district on a portrait phone screen.
- The district has four subdistricts (khwaeng). **Checked against OSM**: the `name:en` values are *Somdet Chao Phraya Subdistrict* (relation 11355107), *Khlong San Subdistrict* (11355108), *Khlong Ton Sai Subdistrict* (11355109) and *Bang Lamphu Lang Subdistrict* (11355110). Together they cover the district with no gaps or overlaps.
- Subdistrict polygons: `assets/geo/khlong_san_subdistricts.geojson`, a FeatureCollection with one feature per khwaeng and the OSM `name:en` property. The sample data takes each record's `subdistrict` from the polygon its coordinates fall in.
- **River:** the east edge follows the middle of the Chao Phraya, so about 10 % of the district polygon is water. `assets/geo/khlong_san_water.geojson` (OSM relations 14038959 river, 15646612 canal) lists the areas that sample coordinates must avoid.
- The map shows the district outline. All sample coordinates fall inside it.

## 4. In scope / out of scope

**In scope**
1. 6-digit PIN lock (fixed PIN `000000`)
2. Patient list with search and filters
3. Map with color-coded pins and the district outline
4. Add patient (prefilled from the unused part of the pool) / edit / view
5. Capture GPS with accuracy
6. Block duplicate national IDs
7. Call and navigate buttons
8. Mark a patient deceased (swipe), restore a mistaken one (swipe)
9. Show inactive switch
10. Reset sample data (from the PIN screen)

**Out of scope**
- Server, sync, multi-user
- Encryption, lost-device protection
- PDPA / consent handling (prototype only)
- Reports and dashboards
- Offline map tiles
- Thai-language UI
- In-app CSV export (dropped by the team; the sample-data file `data/patients.csv` is unrelated and stays)
- Deleting patients
- Visit history (each patient has one registration; editing overwrites it)
- Several volunteers sharing one phone

## 5. Data model (SQLite)

The schema is `data/schema.sql`, generated by `data/gen_bootstrap.dart`. It is
the app's real schema. Main table `patients`, plus two child tables:

| Column | Type | Rule / values |
|---|---|---|
| `id` | TEXT (UUID) | primary key |
| `national_id` | TEXT | 13 digits, valid Thai checksum, **UNIQUE**: a duplicate blocks saving |
| `full_name` | TEXT | required |
| `sex` | TEXT | `male`, `female` |
| `birth_year` | INTEGER | **Gregorian** (e.g. 1950). The UI shows the Buddhist era = Gregorian + 543 (e.g. 2493) and the age. The schema CHECK is fixed at 1916–1966 (reference year 2026; SQLite can't use `date('now')` in a CHECK), and the app also checks age 60–110 against the current year. Known limit: from 2027 the CHECK rejects a 60-year-old |
| `photo_path` | TEXT? | bundled asset or a file in app documents |
| `contact_name` | TEXT | the **contact person**: the one person to call about the patient; may be the patient ("Self") |
| `contact_relation` | TEXT | one of `self`, `spouse`, `child`, `grandchild`, `sibling`, `otherRelative`, `neighbour`, `other` |
| `subdistrict` | TEXT | the OSM `name:en` from §3, exactly, including the " Subdistrict" suffix (the schema CHECK uses these strings). Sample data: 5 / 10 / 18 / 17 in §3 order *(replaces `village_no`)* |
| `address_note` | TEXT | soi/road + landmark |
| `lat`, `lng` | REAL | required, inside the district |
| `gps_accuracy_m` | REAL? | null for bootstrap data |
| `dependency` | TEXT | the **care level**: `bedridden` (ADL 0–4), `homebound` (5–11), `social` (12–20). The app derives it from `adl_score` |
| `adl_score` | INTEGER? | 0–20, must match the dependency band |
| `main_condition` | TEXT | stroke, dementia, frailty, spinalInjury, cancer, other |
| `living_situation` | TEXT | withCaregiver, livesAlone, elderlyCaregiver |
| `status` | TEXT | active, inHospital, moved, deceased. **Inactive** = moved or deceased |
| `notes` | TEXT | free text |
| `registered_by` | TEXT | the volunteer's name when the patient was first saved; never changed by edits. Sample pool: "Sample data" |
| `created_at`, `updated_at` | TEXT (ISO 8601) | |

- `patient_phones(patient_id, seq, phone)`: the **contact person's** phone numbers, stored as text, 10 digits, `seq` 0 = primary (the one Call dials).
- `patient_care_needs(patient_id, need)`: bedsore, feedingTube, catheter, oxygen, needsAirMattress, needsWheelchair.

Removed since draft 1: `consent`. Replaced: `village_no` → `subdistrict`.
Bangkok addresses use soi and road, not village numbers.

**National ID checksum:** for digits d1…d12, sum = Σ dᵢ × (14 − i);
check digit = (11 − sum mod 11) mod 10. The schema enforces it with a CHECK.

## 6. Sample data pool

- **50 fictitious records**, ages **60–110**, **25 male / 25 female**. Ages spread across the whole range, including at least two aged 100+ and one at exactly 110 to test the edge cases. Reference year 2026 → `birth_year` 1916–1966.
- Generated by `data/gen_bootstrap.dart` (fixed seed) into `data/patients.csv`, `data/seed.sql` and `assets/bootstrap.json`.
- Photos: the team's portraits in `assets/avatars/`, 256×256 PNG, named `avatar_NN_<sex>_age_<age>.png`. Record N uses avatar NN, and each record's sex comes from the file name. Each record's age also comes from the file name; four files carry ages 110, 106, 103 and 100 (4 people aged 100+). List `assets/avatars/` under `flutter: assets:` in `pubspec.yaml`. A photo picked in the app is copied to the app documents folder; a missing photo falls back to an initials avatar drawn in Flutter.
- Distribution: 10 bedridden, 25 homebound, 15 social; 3 deceased, 2 moved, 2 in hospital; about 8 live alone.
- Coordinates: random points inside the district boundary and outside `khlong_san_water.geojson`, grouped in clusters. Helper: `spikes/map_geo/lib/geo/random_points.dart`. It is pure Dart with no dependencies and provides `GeoArea.fromGeoJson(boundary, exclude: [water])`, `randomPointsInArea(area, n, clusters:, spreadM:, seed:)` and `NamedAreas.fromGeoJson(subdistricts).nameAt(lat, lng)`.

### Startup and Add behaviour

1. **First launch:** 5 patients chosen at random from the **active** records of the sample pool are inserted (so the list shows 5 with Show inactive off). Reset does the same. After that, data **persists** between launches.
   **Reset sample data** (⋮ menu, top-right of the PIN screen, so it works before login; asks for confirmation) replaces all patients with 5 new random ones. It keeps the volunteer's name.
2. **Add** picks a random pool record **not yet in the database** and prefills the form, with status forced to **Active** (an inactive pool record never opens a locked form). The volunteer can edit any field, and "Use my location" overwrites lat/lng. Saving inserts it.
3. When all 50 are in the database, Add opens an empty form.
4. Saving with an existing `national_id` is **blocked** with the message "A patient with this national ID already exists."

## 7. Screens

The 25 frames in the [Figma prototype](https://www.figma.com/design/zHNLIMNEn1XPcNwBTZGw7B) (page "Screens") follow this section.

1. **Launch.** The PIN is fixed at `000000`; there is no PIN setup and it can't be changed.
   - First launch: **Your name** (required, saved as the volunteer's name and used for `registered_by`) → PIN entry → List with the 5 seeded patients.
   - Every later launch: PIN entry → List. No lockout.
   - Top-right ⋮ opens a `CupertinoActionSheet` with **Reset sample data** → confirmation alert that says the volunteer's name is kept.
2. **Home**, with tabs **List** | **Map**.
   - List: photo, name, age, subdistrict, care-level badge, status. Search by name or national ID. Filter by care level and status. **Show inactive** switch (shared with the map), off by default.
   - Header counts: "8 PATIENTS · 1 INACTIVE HIDDEN" (Show inactive off) / "9 PATIENTS · INCLUDING 1 INACTIVE" (on).
   - Status filter: action sheet "All statuses / Active / In hospital / Moved / Deceased"; **Moved** and **Deceased** are shown greyed out and can't be picked while Show inactive is off (Figma frame 08).
   - Status colours: "In hospital" in indigo (#5856D6); inactive rows are dimmed (dimmed photo, grey name).
   - **Swipe left** on an active, in-hospital or **moved** row → full-width red **Deceased** background → `CupertinoAlertDialog` "Mark <name> as deceased? Their pin will be hidden from the map." (Cancel / Mark deceased). Built with Flutter's `Dismissible` and `confirmDismiss` returning false, so the row isn't dismissed by the swipe and no package is needed. After the confirm, the list reloads: with Show inactive off the now-deceased patient leaves the list, as the alert says. (Moved rows are only visible, so only swipeable, while Show inactive is on.)
   - **Restore:** with Show inactive on, swipe left on a **deceased** row → full-width green **Restore** background → `CupertinoAlertDialog` "Restore <name> to active? Their pin will show on the map again." (Cancel / Restore). Status becomes active at once (no Save) and the list stays. Same `Dismissible` pattern.
   - Map: the district outline plus pins colored by **care level, not age** (bedridden = red, homebound = orange, social = green, deceased/moved = grey). The map opens with no callout; tap a pin → name callout; tap the name → Detail.
   - **Color legend below the map:** the map takes the top part of the screen; scrolling down shows a short legend with one row per color: a swatch, the label and a one-line meaning (e.g. "Red: bedridden (ADL 0–4), needs help with almost everything"), plus the patient count for each color. While Show inactive is off, the grey row shows its count as "N hidden".
3. **Add / Edit form** (pushed on the root navigator, no tab bar):
   - Prefilled as in §6. When all 50 pool patients are registered, the form starts empty with the banner "All 50 sample-pool patients are already registered, so this form starts empty."
   - **Use my location** sets lat/lng, shows ±m accuracy, and also sets the subdistrict from the polygon it falls in (`NamedAreas.nameAt`). Outside the district, the subdistrict is left unchanged and the form shows "Outside Khlong San district".
   - Photo: "Change photo" → action sheet Take photo / Choose from library / Cancel.
   - National ID is shown and typed as `3-XXXX-XXXXX-XX-X` and stored as 13 digits. A bad checksum shows "This national ID isn't valid. Check the 13 digits." A duplicate shows "A patient with this national ID already exists." under the field after Save, and Save is blocked.
   - Birth year is entered in the Buddhist era ("Born (B.E.)") and stored Gregorian.
   - ADL score is set with a − / + stepper. Care level is derived from it (bands in §5) and shown read-only ("Set by ADL score"); there is no care-level picker.
   - Contact phones: "+ Add phone"; Phone 1 is the one Call dials.
   - Status picker: **Active / In hospital / Moved** only. A deceased patient shows "Deceased" read-only with a lock (restore is by swipe, see Home).
   - Display labels: relationship Self / Spouse / Child / Grandchild / Sibling / Other relative / Neighbour / Other; care needs Bedsore / Feeding tube / Catheter / Oxygen / Air mattress / Wheelchair; "Main condition"; "Living situation".
4. **Detail** (pushed on the root navigator, no tab bar): all fields, a small map, **Call**, **Navigate** (Apple Maps) and one **Edit** button (no Edit in the top bar).

Dates show the Buddhist era (e.g. "Born 2493 (age 76)"). All UI text is in English.

## 8. Platform setup notes

**iOS `Info.plist` keys:**
- `NSLocationWhenInUseUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSCameraUsageDescription`

**Simulator**
- Set the location under **Features → Location → Custom Location…** to the district center **13.7228, 100.5023**, or from a shell: `xcrun simctl location <device> set 13.7228,100.5023`. The spike then reports that point with ±5 m accuracy.
- There's no camera, so drag images onto the simulator to add them to Photos.

**OSM tiles:** free for light use; needs a real User-Agent; bulk or offline
download is not allowed. Fine for a prototype. Change `urlTemplate` for a real
rollout.

## 9. Build order: plan and result

The plan became 28 GitHub issues, each with "Done when" and "Blocked by" lines. One hub session built them in worker streams (Opus 5.5, own git worktree, one PR per issue), with a read-only expert session for consults. Details: `docs/STATUS.md`; retrospective: `docs/LESSONS_LEARNED.md`.

| Stream | Issues | What |
|---|---|---|
| A Foundation | #1 #2 #3 #28 #4–#7 | `flutter create`, packages, Info.plist, design tokens + check, DB, seed, repository, reset, app shell |
| B1 Launch | #8–#10 | Your name, PIN 000000, ⋮ Reset |
| B2 List | #11–#14 | Rows, search/filters, Show inactive, swipe Deceased/Restore |
| B3 Map | #15–#18 | Tiles + outline, pins, callout → Detail, legend |
| B4 Detail | #19 #20 | Fields, BE dates, mini map, Call/Navigate/Edit |
| C Form | #21–#26 | Fields, pool prefill, validation, deceased lock, Use my location, photo |
| E Walkthrough | #27 | Every screen on the iOS Simulator against §6–§7 and Figma |

The plan estimated 1 h 45 min (later 2 h 45 min). Actual: first PR 17:16, all features merged by about 19:06, last fix merged 19:52 (ICT). That's 40 PRs, 38 merged; #30 and #32 were closed by a hub merge mistake and replaced by #38 and #39. Per-screen Simulator checks and the walkthrough found the fixes in #54, #58, #63, #65 and #66–#68.

## 10. Open questions

None open. Previously:

1. ~~Reset on every launch~~ **Resolved:** persist, plus Reset sample data on the PIN screen (§6). Original question: I read "start with 5 records … every time we start the application" as *wipe and reseed on every launch*, which also discards anything added during testing. If you instead want 5 records only on the very first launch, say so. It is a one-line change.
2. ~~Thai text in data~~ **Resolved:** romanize all sample text. Original question: the UI is English, but the sample names and notes are in Thai script. Keep them in Thai (realistic), or switch to romanized names?
3. ~~District center and zoom~~ **Resolved:** center 13.7228, 100.5023, zoom 14.5 (§3); the Map tab then fits the district outline (§2, PR #63).

**Known limits (accepted for the prototype):** the `birth_year` CHECK is fixed at 1916–1966, so from 2027 a 60-year-old is rejected (§5). Overlapping pins: the top one takes the tap until you zoom in. `tel:` doesn't work on the Simulator, which shows "Can't place a call on this device.". Reset sample data on the PIN screen works without the PIN. The volunteer name is stored without encryption.
