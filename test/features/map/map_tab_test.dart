import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bedridden_pt/app/app_scope.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';
import 'package:bedridden_pt/features/map/map_pin.dart';
import 'package:bedridden_pt/features/map/map_tab.dart';
import 'package:bedridden_pt/shared/care_style.dart';
import 'package:bedridden_pt/shared/map_config.dart';
import 'package:bedridden_pt/theme/tokens.dart';

import '../../data/test_db.dart';

void main() {
  initTestDatabases();

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

  late PatientRepository repo;
  late ValueNotifier<bool> showInactive;

  /// Pumps real time until [done] (assets and the database load for real).
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 50 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  /// The pins on the map (the legend swatches are MapPins too).
  List<MapPin> pins(WidgetTester tester) => tester
      .widgetList<MapPin>(
        find.descendant(
          of: find.byType(MarkerLayer),
          matching: find.byType(MapPin),
        ),
      )
      .toList();

  /// MapTab on a database seeded with the 5 sample patients.
  Future<void> pumpMap(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final volunteer = (await tester.runAsync(() async {
      repo = await openTestRepository();
      await repo.seedSampleData();
      return VolunteerStore.open();
    }))!;
    addTearDown(() => tester.runAsync(repo.close));
    showInactive = ValueNotifier(false);
    await tester.pumpWidget(
      AppScope(
        patients: repo,
        volunteer: volunteer,
        showInactive: showInactive,
        child: const CupertinoApp(home: MapTab()),
      ),
    );
    await settle(
      tester,
      () =>
          find.byType(PolygonLayer).evaluate().isNotEmpty &&
          pins(tester).isNotEmpty,
    );
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

  testWidgets('one pin per active patient, coloured by care level', (
    tester,
  ) async {
    await pumpMap(tester);
    final patients = (await tester.runAsync(() => repo.list()))!;
    expect(patients, hasLength(5));

    final shown = {for (final p in pins(tester)) (p.key! as ValueKey).value};
    expect(shown, {for (final p in patients) p.id});
    for (final p in patients) {
      final pin = tester.widget<MapPin>(find.byKey(ValueKey(p.id)));
      expect(pin.color, CareStyle.of(p.careLevel).pin, reason: p.fullName);
    }

    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    for (final m in markers.markers) {
      final p = patients.singleWhere(
        (p) => (m.child.key! as ValueKey).value == p.id,
      );
      expect(m.point.latitude, p.lat);
      expect(m.point.longitude, p.lng);
    }
  });

  testWidgets('a deceased patient: no pin, grey pin with Show inactive on', (
    tester,
  ) async {
    await pumpMap(tester);
    final gone = (await tester.runAsync(() => repo.list()))!.first;
    await tester.runAsync(() => repo.markDeceased(gone.id));
    await settle(tester, () => pins(tester).length == 4);
    expect(find.byKey(ValueKey(gone.id)), findsNothing);

    // The switch on the Map tab drives the shared AppScope.showInactive.
    await tester.ensureVisible(find.byType(CupertinoSwitch));
    await tester.pump();
    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pump();
    expect(showInactive.value, isTrue);
    expect(pins(tester), hasLength(5));
    expect(
      tester.widget<MapPin>(find.byKey(ValueKey(gone.id))).color,
      AppColors.pinInactive,
    );

    // Turned off from elsewhere (the List tab): the grey pin goes again.
    showInactive.value = false;
    await tester.pump();
    expect(pins(tester), hasLength(4));
  });

  testWidgets('legend counts match the pins shown; grey row says N hidden', (
    tester,
  ) async {
    await pumpMap(tester);
    final gone = (await tester.runAsync(() => repo.list()))!.first;
    await tester.runAsync(() => repo.markDeceased(gone.id));
    await settle(tester, () => pins(tester).length == 4);

    /// The count text of the legend row titled [title].
    String count(String title) {
      final row = find.ancestor(
        of: find.text(title),
        matching: find.byType(Row),
      );
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: row.first, matching: find.byType(Text)),
          )
          .map((t) => t.data!)
          .toList();
      return texts.last;
    }

    /// How many map pins (not legend swatches) have [color].
    int pinsOf(Color color) =>
        pins(tester).where((p) => p.color == color).length;

    // Scroll the page to the legend (a drag at the centre would pan the map).
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(MapTab.mapHeight);
    await tester.pump();
    expect(find.text('COLOR LEGEND'), findsOneWidget);
    expect(count('Red: bedridden'), '${pinsOf(AppColors.pinBedridden)}');
    expect(count('Orange: homebound'), '${pinsOf(AppColors.pinHomebound)}');
    expect(count('Green: social'), '${pinsOf(AppColors.pinSocial)}');
    expect(
      int.parse(count('Red: bedridden')) +
          int.parse(count('Orange: homebound')) +
          int.parse(count('Green: social')),
      4,
    );
    expect(count('Grey: inactive'), '1 hidden');

    showInactive.value = true;
    await tester.pump();
    expect(count('Grey: inactive'), '1');
    expect(pinsOf(AppColors.pinInactive), 1);
  });
}
