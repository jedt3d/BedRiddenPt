# Geo assets — Khlong San District (เขตคลองสาน), Bangkok

Map data © OpenStreetMap contributors (ODbL). https://www.openstreetmap.org/copyright

Retrieved: 2026-11-19. Coordinates are GeoJSON order `[lng, lat]`, WGS84.

## Files

| File | Contents | OSM source |
|---|---|---|
| `khlong_san_boundary.geojson` | Boundary of **Khlong San District** (khet), one `Polygon`, 112 points, no holes, ≈ 5.96 km² | relation [3147280](https://www.openstreetmap.org/relation/3147280), `admin_level=6`, wikidata Q1019456 |
| `khlong_san_subdistricts.geojson` | The district's four subdistricts (khwaeng), one `Polygon` feature each, properties `name`, `name:en`, `osm_id` | relations below |
| `khlong_san_roads.geojson` | 386 named road/soi ways (`LineString`) with an English name, properties `name:en`, `name`, `name_en_source`, `highway`, `osm_id` (way id). 206 distinct English names | ways with `highway` + `name` in relation 3147280 |
| `khlong_san_water.geojson` | Water to exclude when generating points: a Chao Phraya river section and the Khlong San canal | relations [14038959](https://www.openstreetmap.org/relation/14038959) (`water=river`), [15646612](https://www.openstreetmap.org/relation/15646612) (`water=canal`) |

Subdistricts (`admin_level=8`):

| `name:en` | name | OSM relation | Area | Population (OSM tag, 2023) |
|---|---|---|---|---|
| Somdet Chao Phraya Subdistrict | แขวงสมเด็จเจ้าพระยา | [11355107](https://www.openstreetmap.org/relation/11355107) | ≈ 0.91 km² | 11,444 |
| Khlong San Subdistrict | แขวงคลองสาน | [11355108](https://www.openstreetmap.org/relation/11355108) | ≈ 1.06 km² | 13,160 |
| Khlong Ton Sai Subdistrict | แขวงคลองต้นไทร | [11355109](https://www.openstreetmap.org/relation/11355109) | ≈ 1.73 km² | 17,886 |
| Bang Lamphu Lang Subdistrict | แขวงบางลำภูล่าง | [11355110](https://www.openstreetmap.org/relation/11355110) | ≈ 2.26 km² | 22,471 |

How they were fetched:
- District and subdistrict polygons: Nominatim
  `https://nominatim.openstreetmap.org/lookup?osm_ids=R3147280&format=geojson&polygon_geojson=1`
  (same for R11355107–R11355110).
- Subdistrict list: Overpass `rel(3147280);map_to_area->.a;rel(area.a)["boundary"="administrative"]["admin_level"="8"];out tags;`
- Roads: Overpass `rel(3147280);map_to_area->.a;way(area.a)["highway"]["name"];out tags geom;` on `overpass-api.de`
  (429 named ways). English name: `name:en` (363 ways), otherwise `name` when it is already Latin script
  (23 ways, `name_en_source` = "name (Latin script)"; `name` then holds that Latin text because OSM has no Thai).
  The other 43 ways (25 distinct Thai-only names) were dropped. Every `highway` type is kept (residential 280,
  secondary 76, path 21, primary 14, service 13, footway 10, …); filter on `highway` if footpaths are unwanted.
  A way is kept if any part of it is inside the district, so some extend past the boundary.
- Water: Overpass `relation(id:14038959,15646612);out geom;` on `overpass-api.de`. Member ways were joined
  into closed rings locally. The river relation is a long Chao Phraya section (13.685–13.746 N), stored unclipped.

## Derived values

- Center (area centroid of the district polygon, on land, in Khlong Ton Sai): **13.7228, 100.5023**
- Bounding box: lat 13.70515–13.73931, lng 100.49214–100.51276 (≈ 3.8 km N–S × 2.2 km E–W)
- Start zoom: **14.5** (the whole district fits a portrait phone screen)

## Checks done

- The four subdistricts tile the district: of 20,000 random points in the district, none fell in
  zero or in two subdistricts; their areas add up to the district area.
- About **10 %** of the district is river (its east edge runs along the middle of the Chao Phraya).
  Random points must exclude `khlong_san_water.geojson`.

## Data notes

- Nominatim does not index the river/canal water areas (they have no name), so Overpass was needed.
- `overpass-api.de` returned "at capacity" (HTTP 504) on the first attempt; a retry succeeded.
- Small ponds (`natural=water` ways, < 0.01 km² each) were ignored.
- Road English names in OSM are not normalized, and are kept as OSM has them: e.g. "Lat ya 3" next to "Lat Ya 9",
  "Krung Thon Buri" next to "Krung Thon Buri Road", "Itsara Phap 1/1" next to "Itsaraphap Road". One road is split
  into several ways, so the same name appears many times.
- Helper: `spikes/map_geo/lib/geo/nearest_road.dart`, `NamedRoads.fromGeoJson(roads).nearestRoad(lat, lng)` →
  English name, Thai name, highway, way id and distance in metres. For the 50 sample patients (2026-11-19 data) the
  nearest named road is a median 37 m away (max 190 m). Cross-checked the district center in Python: Soi Charoen
  Nakhon 14, 3 m.
- Earlier on 2026-11-19 `khlong_san_boundary.geojson` held only Khlong San *Subdistrict*
  (relation 11355108). It was replaced by the district when SPEC draft 2 chose the district.
