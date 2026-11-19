# Feature folders

One folder per parallel stream. Each stream edits only its own folder (and
its tests in `test/features/<stream>/`, e.g. `test/features/list/`).
`lib/main.dart`, `lib/app/`, `lib/data/`, `lib/shared/`, `lib/geo/` and
`lib/theme/` are hub-owned: ask the hub for a change there.

| Folder | Stream | Entry widget (keep its name and constructor) | Route |
|---|---|---|---|
| `launch/` | Launch | `NameScreen`, `PinScreen` | `Routes.name`, `Routes.pin` |
| `list/` | List | `ListTab` (Home tab 1) | inside `Routes.home` |
| `map/` | Map | `MapTab` (Home tab 2) | inside `Routes.home` |
| `detail/` | Detail | `DetailScreen(patientId:)` | `Routes.detail`, argument: the id |
| `form/` | Form | `PatientFormScreen(patientId:)` (null = Add) | `Routes.add`, `Routes.edit` + id |

- Get shared objects with `AppScope.of(context)` in `build`, or
  `AppScope.read(context)` in `initState` (no dependency): `patients` (`PatientRepository`, a
  `ChangeNotifier` that fires after every write), `volunteer` (`VolunteerStore`:
  name, `appPin`), `showInactive` (`ValueNotifier<bool>`, shared by List and Map).
- Navigate with `Routes.openDetail / openAdd / openEdit / replaceAllWith`
  (`lib/app/routes.dart`). Detail, Add and Edit go on the root navigator, so
  the tab bar is hidden there.
- Styles come only from `lib/theme/tokens.dart` (`tool/check_tokens.sh`).
- Replace `PlaceholderBody` with the real screen; delete
  `lib/app/placeholder_body.dart` once no screen uses it.

## Shared code (hub-owned; use it, don't copy it)

| File | What |
|---|---|
| `lib/shared/labels.dart` | `.label` for every enum, e.g. `ContactRelation.otherRelative.label` = "Other relative", `CareNeed.needsAirMattress.label` = "Air mattress", `PatientStatus.inHospital.label` = "In hospital" |
| `lib/shared/national_id.dart` | `isValidNationalId`, `formatNationalId` (3-XXXX-XXXXX-XX-X, also partial while typing), `parseNationalId`, `invalidNationalIdMessage` |
| `lib/shared/map_config.dart` | `MapConfig.tileUrl`, `userAgentPackageName` (`com.example.bedriddenPt`), `center` (13.7228, 100.5023), `initialZoom` (14.5), `attribution`, geo asset paths |
| `lib/shared/care_style.dart` | `CareStyle.of(level)`: `dot`, `badgeText`, `badgeBackground`, `pin`; `CareStyle.pinColorFor(patient)` (grey when inactive) |
| `lib/shared/patient_avatar.dart` | `PatientAvatar(patient:, size:)`: bundled asset, a photo in app documents, or initials. A picked photo is copied into app documents and `photo_path` stores only its **file name** (iOS container paths change on reinstall) |
| `lib/geo/` | Byte-for-byte copies of `spikes/map_geo/lib/geo/random_points.dart` and `nearest_road.dart` (`GeoArea`, `NamedAreas.nameAt`, …). A test keeps them identical; the originals stay for `data/gen_bootstrap.dart` |

Repository rules the screens rely on: the care level follows the ADL score;
`insert`/`update` throw `InvalidNationalIdException` or
`DuplicateNationalIdException` (each has `.message`); `update` never sets or
clears deceased (use `markDeceased` / `restoreToActive`, which return whether
anything changed); `nextUnusedPoolRecord()` comes back with status active.
