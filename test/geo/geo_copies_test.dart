import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/geo/random_points.dart';
import 'package:bedridden_pt/shared/map_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // lib/geo/ holds copies; data/gen_bootstrap.dart imports the originals.
  for (final name in ['random_points.dart', 'nearest_road.dart']) {
    test(
      'lib/geo/$name matches spikes/map_geo/lib/geo/$name byte for byte',
      () {
        expect(
          File('lib/geo/$name').readAsBytesSync(),
          File('spikes/map_geo/lib/geo/$name').readAsBytesSync(),
        );
      },
    );
  }

  test('the map centre is inside the district, in Khlong Ton Sai', () async {
    final boundary = await rootBundle.loadString(MapConfig.boundaryAsset);
    final water = await rootBundle.loadString(MapConfig.waterAsset);
    final subdistricts = await rootBundle.loadString(
      MapConfig.subdistrictsAsset,
    );
    final c = MapConfig.center;
    expect(
      GeoArea.fromGeoJson(
        boundary,
        exclude: [water],
      ).contains(c.latitude, c.longitude),
      isTrue,
    );
    expect(
      NamedAreas.fromGeoJson(subdistricts).nameAt(c.latitude, c.longitude),
      'Khlong Ton Sai Subdistrict',
    );
  });
}
