// Random points inside a GeoJSON area, minus excluded areas (e.g. river).
//
// Pure Dart (dart:convert, dart:math only) so the bootstrap-data generator
// (`tool/gen_bootstrap.dart`) can import it without Flutter.
//
// GeoJSON stores coordinates as [lng, lat]. Point-in-polygon uses the
// even-odd ray-casting rule on raw degrees, which is accurate enough for an
// area of ~1 km².

import 'dart:convert';
import 'dart:math';

typedef GeoPoint = ({double lat, double lng});

/// A polygon as rings of [lng, lat] pairs: ring 0 is the outer ring, the
/// rest are holes.
typedef Rings = List<List<List<double>>>;

class GeoArea {
  GeoArea(this.polygons, {this.exclusions = const []});

  /// Area = union of these polygons.
  final List<Rings> polygons;

  /// Points inside any of these polygons are rejected (water, etc.).
  final List<Rings> exclusions;

  /// Builds an area from a boundary GeoJSON string and optional exclusion
  /// GeoJSON strings. Accepts FeatureCollection, Feature, Polygon and
  /// MultiPolygon.
  factory GeoArea.fromGeoJson(
    String boundary, {
    List<String> exclude = const [],
  }) => GeoArea(
    _polygonsOf(jsonDecode(boundary)),
    exclusions: [for (final e in exclude) ..._polygonsOf(jsonDecode(e))],
  );

  bool contains(double lat, double lng) =>
      polygons.any((p) => _inPolygon(lng, lat, p)) &&
      !exclusions.any((p) => _inPolygon(lng, lat, p));

  /// [minLat, minLng, maxLat, maxLng] of the outer rings.
  List<double> get bounds {
    var b = [90.0, 180.0, -90.0, -180.0];
    for (final p in polygons) {
      for (final c in p.first) {
        b = [
          min(b[0], c[1]),
          min(b[1], c[0]),
          max(b[2], c[1]),
          max(b[3], c[0]),
        ];
      }
    }
    return b;
  }

  /// Outer ring of the first polygon as GeoPoints (for drawing).
  List<GeoPoint> get outline => [
    for (final c in polygons.first.first) (lat: c[1], lng: c[0]),
  ];

  GeoPoint randomPoint(Random rand) {
    final b = bounds;
    for (var i = 0; i < 100000; i++) {
      final lat = b[0] + rand.nextDouble() * (b[2] - b[0]);
      final lng = b[1] + rand.nextDouble() * (b[3] - b[1]);
      if (contains(lat, lng)) return (lat: lat, lng: lng);
    }
    throw StateError('Area too small or empty: no point found');
  }
}

class ClusteredPoint {
  ClusteredPoint(this.point, this.cluster);
  final GeoPoint point;

  /// 1-based cluster number (use as village no.); 0 when not clustered.
  final int cluster;
}

/// Generates [n] random points inside [area].
///
/// With [clusters] > 0, picks that many random cluster centers inside the
/// area, then scatters points around them (Gaussian, [spreadM] metres
/// standard deviation), round-robin so clusters get equal counts. Every point
/// is still checked against [area]. Same [seed] → same output.
List<ClusteredPoint> randomPointsInArea(
  GeoArea area,
  int n, {
  int clusters = 0,
  double spreadM = 150,
  int seed = 1,
}) {
  final rand = Random(seed);
  if (clusters <= 0) {
    return [
      for (var i = 0; i < n; i++) ClusteredPoint(area.randomPoint(rand), 0),
    ];
  }
  final centers = [for (var i = 0; i < clusters; i++) area.randomPoint(rand)];
  final out = <ClusteredPoint>[];
  for (var i = 0; i < n; i++) {
    final c = centers[i % clusters];
    final mPerDegLng = 111320 * cos(c.lat * pi / 180);
    GeoPoint? p;
    for (var tries = 0; tries < 1000 && p == null; tries++) {
      final lat = c.lat + _gauss(rand) * spreadM / 110540;
      final lng = c.lng + _gauss(rand) * spreadM / mPerDegLng;
      if (area.contains(lat, lng)) p = (lat: lat, lng: lng);
    }
    out.add(ClusteredPoint(p ?? c, (i % clusters) + 1));
  }
  return out;
}

/// The features of a GeoJSON FeatureCollection, looked up by point.
/// Used to find which subdistrict a coordinate falls in.
class NamedAreas {
  NamedAreas.fromGeoJson(String geojson, {String nameKey = 'name:en'}) {
    for (final f in (jsonDecode(geojson)['features'] as List)) {
      _areas.add((f['properties'][nameKey] as String, _polygonsOf(f)));
    }
  }
  final _areas = <(String, List<Rings>)>[];

  List<String> get names => [for (final a in _areas) a.$1];

  /// Outer ring of each feature's first polygon, keyed by name (for drawing).
  Map<String, List<GeoPoint>> get outlines => {
    for (final a in _areas)
      a.$1: [for (final c in a.$2.first.first) (lat: c[1], lng: c[0])],
  };

  /// Name of the first feature containing the point, or null.
  String? nameAt(double lat, double lng) {
    for (final a in _areas) {
      if (a.$2.any((p) => _inPolygon(lng, lat, p))) return a.$1;
    }
    return null;
  }
}

double _gauss(Random r) =>
    sqrt(-2 * log(1 - r.nextDouble())) * cos(2 * pi * r.nextDouble());

bool _inRing(double x, double y, List<List<double>> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i][0], yi = ring[i][1], xj = ring[j][0], yj = ring[j][1];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

bool _inPolygon(double x, double y, Rings p) =>
    _inRing(x, y, p.first) && !p.skip(1).any((h) => _inRing(x, y, h));

List<Rings> _polygonsOf(dynamic g) {
  Rings rings(dynamic r) => [
    for (final ring in r as List)
      [
        for (final c in ring as List)
          [(c[0] as num).toDouble(), (c[1] as num).toDouble()],
      ],
  ];
  switch (g['type']) {
    case 'FeatureCollection':
      return [for (final f in g['features'] as List) ..._polygonsOf(f)];
    case 'Feature':
      return _polygonsOf(g['geometry']);
    case 'Polygon':
      return [rings(g['coordinates'])];
    case 'MultiPolygon':
      return [for (final p in g['coordinates'] as List) rings(p)];
    default:
      return [];
  }
}
