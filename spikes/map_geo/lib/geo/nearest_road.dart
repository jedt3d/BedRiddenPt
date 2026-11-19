// Nearest named road to a point, from assets/geo/khlong_san_roads.geojson.
//
// Pure Dart (dart:convert, dart:math only), like random_points.dart, so the
// bootstrap generator can use it without Flutter.
//
// Distance is point-to-segment on a local flat projection (metres east/north
// of the query point). Error is well under 1 m at district scale (~4 km).

import 'dart:convert';
import 'dart:math';

class NearestRoad {
  NearestRoad(this.nameEn, this.name, this.highway, this.osmId, this.distanceM);

  /// English name (OSM `name:en`, or a Latin-script `name`).
  final String nameEn;

  /// OSM `name` (Thai where OSM has it).
  final String name;

  /// OSM `highway` value, e.g. residential, secondary.
  final String highway;
  final int osmId;
  final double distanceM;

  @override
  String toString() => '$nameEn (${distanceM.toStringAsFixed(0)} m)';
}

class NamedRoads {
  /// Loads a FeatureCollection of LineStrings with `name:en`, `name`,
  /// `highway` and `osm_id` properties.
  NamedRoads.fromGeoJson(String geojson) {
    for (final f in (jsonDecode(geojson)['features'] as List)) {
      final g = f['geometry'];
      if (g['type'] != 'LineString') continue;
      final p = f['properties'];
      _roads.add((
        p['name:en'] as String,
        p['name'] as String,
        p['highway'] as String,
        p['osm_id'] as int,
        [
          for (final c in g['coordinates'] as List)
            [(c[0] as num).toDouble(), (c[1] as num).toDouble()],
        ],
      ));
    }
  }

  final _roads = <(String, String, String, int, List<List<double>>)>[];

  int get length => _roads.length;

  /// Nearest named road to (lat, lng). With [highways], only those `highway`
  /// types are considered (e.g. {'residential', 'secondary'} to skip footpaths).
  /// Returns null when no road matches.
  NearestRoad? nearestRoad(double lat, double lng, {Set<String>? highways}) {
    const mPerDegLat = 110540.0;
    final mPerDegLng = 111320.0 * cos(lat * pi / 180);
    NearestRoad? best;
    for (final r in _roads) {
      if (highways != null && !highways.contains(r.$3)) continue;
      final pts = r.$5;
      for (var i = 0; i + 1 < pts.length; i++) {
        // Segment endpoints in metres relative to the query point.
        final ax = (pts[i][0] - lng) * mPerDegLng,
            ay = (pts[i][1] - lat) * mPerDegLat;
        final bx = (pts[i + 1][0] - lng) * mPerDegLng,
            by = (pts[i + 1][1] - lat) * mPerDegLat;
        final dx = bx - ax, dy = by - ay;
        final len2 = dx * dx + dy * dy;
        final t = len2 == 0
            ? 0.0
            : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
        final d = sqrt(pow(ax + t * dx, 2) + pow(ay + t * dy, 2));
        if (best == null || d < best.distanceM) {
          best = NearestRoad(r.$1, r.$2, r.$3, r.$4, d);
        }
      }
    }
    return best;
  }
}
