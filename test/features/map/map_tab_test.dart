import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/features/map/map_tab.dart';
import 'package:bedridden_pt/shared/map_config.dart';
import 'package:bedridden_pt/theme/tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_map's tile cache asks path_provider for a directory; tests have
  // no plugins. (Tile requests themselves get HTTP 400 under flutter_test.)
  setUpAll(() {
    final cache = Directory.systemTemp.createTempSync('map_tab_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.path,
        );
  });

  // rootBundle caches each loadString future, and a future from an earlier
  // test's fake-async zone never completes in the next test.
  setUp(rootBundle.clear);

  Future<void> pumpMap(WidgetTester tester) async {
    await tester.pumpWidget(const CupertinoApp(home: MapTab()));
    // The GeoJSON assets load through a real platform message; wait
    // outside the fake clock until the outlines are drawn.
    for (
      var i = 0;
      i < 50 && find.byType(PolygonLayer).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets('OSM tiles with the User-Agent, centred on the district', (
    tester,
  ) async {
    await pumpMap(tester);

    final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tiles.urlTemplate, MapConfig.tileUrl);
    expect(
      tiles.tileProvider.headers['User-Agent'],
      contains(MapConfig.userAgentPackageName),
    );

    final options = tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
    expect(options.initialCenter, MapConfig.center);
    expect(options.initialZoom, MapConfig.initialZoom);
    expect(tester.getSize(find.byType(FlutterMap)).height, MapTab.mapHeight);
  });

  testWidgets('draws the district outline and the four subdistricts', (
    tester,
  ) async {
    await pumpMap(tester);

    final polygons = tester
        .widget<PolygonLayer>(find.byType(PolygonLayer))
        .polygons;
    final district = polygons.where(
      (p) => p.borderColor == AppColors.mapDistrict,
    );
    expect(district, hasLength(1));
    expect(district.single.points.length, greaterThan(10));
    expect(
      polygons.where((p) => p.borderColor == AppColors.mapSubdistrict),
      hasLength(4),
    );
  });

  testWidgets('shows the OSM attribution', (tester) async {
    await pumpMap(tester);
    expect(find.textContaining('© OpenStreetMap contributors'), findsOneWidget);
  });
}
