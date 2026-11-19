import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:map_geo/geo/nearest_road.dart';
import 'package:map_geo/geo/random_points.dart';

void main() {
  final area = GeoArea.fromGeoJson(
    File('assets/geo/khlong_san_boundary.geojson').readAsStringSync(),
    exclude: [File('assets/geo/khlong_san_water.geojson').readAsStringSync()],
  );

  test('center is inside the area and on land', () {
    expect(area.contains(13.7228, 100.5023), isTrue);
  });

  test('mid-river and outside points are rejected', () {
    expect(
      area.contains(13.7330, 100.5105),
      isFalse,
    ); // Chao Phraya, inside boundary
    expect(area.contains(13.7500, 100.5000), isFalse); // north of the area
  });

  test(
    'every generated point falls in exactly one of the four subdistricts',
    () {
      final subs = NamedAreas.fromGeoJson(
        File('assets/geo/khlong_san_subdistricts.geojson').readAsStringSync(),
      );
      expect(subs.names, [
        'Somdet Chao Phraya Subdistrict',
        'Khlong San Subdistrict',
        'Khlong Ton Sai Subdistrict',
        'Bang Lamphu Lang Subdistrict',
      ]);
      expect(subs.nameAt(13.7228, 100.5023), 'Khlong Ton Sai Subdistrict');
      for (final p in randomPointsInArea(area, 200, seed: 9)) {
        expect(subs.nameAt(p.point.lat, p.point.lng), isNotNull);
      }
    },
  );

  test('generated points are all inside, clustered and repeatable', () {
    final a = randomPointsInArea(area, 50, clusters: 6, seed: 3);
    final b = randomPointsInArea(area, 50, clusters: 6, seed: 3);
    expect(a.length, 50);
    expect(a.every((p) => area.contains(p.point.lat, p.point.lng)), isTrue);
    expect(a.map((p) => p.cluster).toSet(), {1, 2, 3, 4, 5, 6});
    expect([for (final p in a) p.point], [for (final p in b) p.point]);
  });

  test('nearestRoad finds a real named road near every bootstrap patient', () {
    final roads = NamedRoads.fromGeoJson(
      File('assets/geo/khlong_san_roads.geojson').readAsStringSync(),
    );
    expect(roads.length, 386);
    // The district center lies in a built-up block.
    final onRoad = roads.nearestRoad(13.7228, 100.5023)!;
    expect(onRoad.distanceM, lessThan(200));
    final records =
        jsonDecode(File('assets/bootstrap.json').readAsStringSync()) as List;
    final far = [
      for (final r in records)
        if (roads
                .nearestRoad(
                  (r['lat'] as num).toDouble(),
                  (r['lng'] as num).toDouble(),
                )!
                .distanceM >
            300)
          r['id'],
    ];
    expect(far, isEmpty);
  });
}
