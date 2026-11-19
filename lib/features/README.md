# Feature folders

One folder per parallel stream. Each stream edits only its own folder, so
`lib/main.dart`, `lib/app/` and `lib/data/` stay as they are; ask the hub for
a change there.

| Folder | Stream | Entry widget (keep its name and constructor) | Route |
|---|---|---|---|
| `launch/` | Launch | `NameScreen`, `PinScreen` | `Routes.name`, `Routes.pin` |
| `list/` | List | `ListTab` (Home tab 1) | inside `Routes.home` |
| `map/` | Map | `MapTab` (Home tab 2) | inside `Routes.home` |
| `detail/` | Detail | `DetailScreen(patientId:)` | `Routes.detail`, argument: the id |
| `form/` | Form | `PatientFormScreen(patientId:)` (null = Add) | `Routes.add`, `Routes.edit` + id |

- Get shared objects with `AppScope.of(context)`: `patients` (`PatientRepository`, a
  `ChangeNotifier` that fires after every write), `volunteer` (`VolunteerStore`:
  name, `appPin`), `showInactive` (`ValueNotifier<bool>`, shared by List and Map).
- Navigate with `Routes.openDetail / openAdd / openEdit / replaceAllWith`
  (`lib/app/routes.dart`). Detail, Add and Edit go on the root navigator, so
  the tab bar is hidden there.
- Styles come only from `lib/theme/tokens.dart` (`tool/check_tokens.sh`).
- Replace `PlaceholderBody` with the real screen; delete
  `lib/app/placeholder_body.dart` once no screen uses it.
