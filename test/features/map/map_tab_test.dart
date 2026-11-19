import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bedridden_pt/app/app_scope.dart';
import 'package:bedridden_pt/app/routes.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';
import 'package:bedridden_pt/features/detail/detail_screen.dart';
import 'package:bedridden_pt/features/map/map_callout.dart';
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
        child: const CupertinoApp(
          home: MapTab(),
          onGenerateRoute: Routes.onGenerateRoute,
        ),
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

  testWidgets('the whole district outline fits in the map', (tester) async {
    await pumpMap(tester);
    await tester.pump(); // the fit lands on the frame after the outline
    final camera = MapCamera.of(tester.element(find.byType(PolygonLayer)));
    final district = tester
        .widget<PolygonLayer>(find.byType(PolygonLayer))
        .polygons
        .singleWhere((p) => p.borderColor == AppColors.mapDistrict);
    for (final point in district.points) {
      expect(camera.visibleBounds.contains(point), isTrue, reason: '$point');
    }
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
        (p) =>
            ((m.child as GestureDetector).child!.key! as ValueKey).value ==
            p.id,
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

  testWidgets('tap a pin, then its name: Detail for that patient', (
    tester,
  ) async {
    await pumpMap(tester);
    final patients = (await tester.runAsync(() => repo.list()))!;
    expect(find.byType(MapCallout), findsNothing); // opens with no callout

    /// A tap on the map away from the pins closes the callout.
    Future<void> tapEmptyMap() async {
      await tester.tapAt(
        tester.getTopLeft(find.byType(FlutterMap)) + const Offset(5, 5),
      );
      // Past the map's double-tap window, so the tap counts as a tap.
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Pins that overlap at the start zoom: only the top one takes the tap
    // there, so test each pin that is on top at its centre.
    final onTop = [
      for (final p in patients)
        if (find.byKey(ValueKey(p.id)).hitTestable().evaluate().isNotEmpty) p,
    ];
    expect(onTop.length, greaterThanOrEqualTo(3));
    for (final p in onTop) {
      await tapEmptyMap();
      expect(find.byType(MapCallout), findsNothing);
      await tester.tap(find.byKey(ValueKey(p.id)));
      await tester.pump();
      expect(find.byType(MapCallout), findsOneWidget);
      expect(find.text(p.fullName), findsOneWidget);
      expect(
        find.text(MapCallout.summary(p, DateTime.now().year)),
        findsOneWidget,
      );
    }

    await tapEmptyMap();
    expect(find.byType(MapCallout), findsNothing);

    final target = onTop.last;
    await tester.tap(find.byKey(ValueKey(target.id)));
    await tester.pump();
    await tester.tap(find.text(target.fullName));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DetailScreen>(find.byType(DetailScreen)).patientId,
      target.id,
    );
  });

  testWidgets('a pin near the top edge: the whole callout stays visible', (
    tester,
  ) async {
    // iPhone 16 Pro size, where the walkthrough found the callout clipped.
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpMap(tester);
    await tester.pump(); // the camera fit lands on the next frame

    // Walkthrough #27 step 30: Suwit Sae-lim's pin, near the district's top.
    final moved = (await tester.runAsync(() async {
      final p = (await repo.list()).first;
      return repo.update(p.copyWith(lat: 13.735085, lng: 100.505356));
    }))!;
    await settle(tester, () {
      final pin = find.byKey(ValueKey(moved.id));
      return pin.evaluate().isNotEmpty &&
          tester.getTopLeft(pin).dy <
              tester.getTopLeft(find.byType(FlutterMap)).dy +
                  MapPin.size.height * 3;
    });

    await tester.tap(find.byKey(ValueKey(moved.id)));
    await tester.pump();
    final map = tester.getRect(find.byType(FlutterMap));
    final callout = tester.getRect(find.byType(MapCallout));
    expect(find.text(moved.fullName), findsOneWidget);
    expect(map.contains(callout.topLeft), isTrue, reason: '$callout in $map');
    expect(
      map.contains(callout.bottomRight),
      isTrue,
      reason: '$callout in $map',
    );
    // It went below the pin, not above.
    expect(
      callout.top,
      greaterThan(tester.getRect(find.byKey(ValueKey(moved.id))).top),
    );

    // Tapping the flipped callout still opens Detail.
    await tester.tap(find.text(moved.fullName));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DetailScreen>(find.byType(DetailScreen)).patientId,
      moved.id,
    );
  });

  testWidgets('pins near the left and right edges: the callout stays inside '
      'the map and over its pin, even with a long name', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpMap(tester);
    await tester.pump(); // the camera fit lands on the next frame

    const longName = 'Somboonsak Wongsuwannakul-Chaiyaphumphithak';
    final map = tester.getRect(find.byType(FlutterMap));
    for (final x in [12.0, map.width - 12]) {
      final camera = MapCamera.of(tester.element(find.byType(PolygonLayer)));
      final at = camera.screenOffsetToLatLng(Offset(x, map.height / 2));
      final moved = (await tester.runAsync(() async {
        final p = (await repo.list()).first;
        return repo.update(
          p.copyWith(fullName: longName, lat: at.latitude, lng: at.longitude),
        );
      }))!;
      final pinFinder = find.byKey(ValueKey(moved.id));
      await settle(
        tester,
        () =>
            pinFinder.evaluate().isNotEmpty &&
            (tester.getCenter(pinFinder).dx - (map.left + x)).abs() < 1,
      );

      await tester.tap(pinFinder);
      await tester.pump();
      expect(tester.takeException(), isNull); // no overflow
      final callout = tester.getRect(find.byType(MapCallout));
      final pin = tester.getRect(pinFinder);
      expect(callout.left, greaterThanOrEqualTo(map.left), reason: 'x=$x');
      expect(callout.right, lessThanOrEqualTo(map.right), reason: 'x=$x');
      expect(callout.left, lessThanOrEqualTo(pin.center.dx), reason: 'x=$x');
      expect(callout.right, greaterThanOrEqualTo(pin.center.dx));
      expect(callout.bottom, lessThanOrEqualTo(pin.top)); // still above

      // The name still opens Detail.
      await tester.tap(find.text(longName));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DetailScreen>(find.byType(DetailScreen)).patientId,
        moved.id,
      );
      Navigator.of(tester.element(find.byType(DetailScreen))).pop();
      await tester.pumpAndSettle();
    }
  });

  group('CalloutLayout', () {
    const map = Size(402, 520);
    const callout = Size(200, 51);

    test('centred above the pin in the middle of the map', () {
      final o = CalloutLayout(const Offset(201, 300))
          .getPositionForChild(map, callout);
      expect(o.dx, 201 - callout.width / 2);
      expect(
        o.dy + callout.height + CalloutLayout.gap + MapPin.size.height,
        300,
      );
    });

    test('below the tip when there is no room above', () {
      final o = CalloutLayout(const Offset(201, 40))
          .getPositionForChild(map, callout);
      expect(o.dy, 40 + CalloutLayout.gap);
    });

    test('clamped to the left and right edges', () {
      expect(
        CalloutLayout(const Offset(5, 300))
            .getPositionForChild(map, callout)
            .dx,
        CalloutLayout.margin,
      );
      expect(
        CalloutLayout(const Offset(400, 300))
                .getPositionForChild(map, callout)
                .dx +
            callout.width,
        map.width - CalloutLayout.margin,
      );
    });

    test('never wider than the map less its margins', () {
      final c = const CalloutLayout(Offset.zero)
          .getConstraintsForChild(BoxConstraints.loose(const Size(150, 520)));
      expect(c.maxWidth, 150 - 2 * CalloutLayout.margin);
    });
  });
}
