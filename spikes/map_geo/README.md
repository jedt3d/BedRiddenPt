# map_geo spike

A throwaway Flutter app that proved the map approach before the build. It's a separate package with its own `pubspec.yaml`, and the root analyzer excludes it.

It showed, on the iOS Simulator (iPhone 16 Pro):
- OpenStreetMap tiles through `flutter_map`, with the Khlong San district and subdistrict outlines from `assets/geo/`
- all 50 sample patients as pins colored by care level
- "Use my location" with ±m accuracy

Screenshots are in `docs/`. The spike uses Material widgets; the app does not.

## Still in use

- `lib/geo/random_points.dart` (`GeoArea`, `randomPointsInArea`, `NamedAreas.nameAt`) and `lib/geo/nearest_road.dart` (`NamedRoads.nearestRoad`) are imported by `data/gen_bootstrap.dart`. **Don't move them.**
- The app uses byte-for-byte copies in the root `lib/geo/`; a test there keeps the copies identical.
- `assets/` here holds copies of the root `assets/geo/` files and `assets/bootstrap.json`; refresh them if those change.

## Run

```bash
cd spikes/map_geo && flutter run
```

```bash
cd spikes/map_geo && flutter test
```
