// Form (SPEC §2, §7.3) #25: Use my location overwrites lat/lng, shows ±m
// and sets the subdistrict from the real polygons; outside the district the
// subdistrict stays and a note says so.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/features/form/form_draft.dart';
import 'package:bedridden_pt/features/form/form_location.dart';
import 'package:bedridden_pt/features/form/patient_form_screen.dart';
import 'package:bedridden_pt/geo/random_points.dart';
import 'package:bedridden_pt/shared/map_config.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  late NamedAreas areas;
  setUpAll(() async {
    areas = NamedAreas.fromGeoJson(
      await File(MapConfig.subdistrictsAsset).readAsString(),
    );
  });

  /// Makes Use my location return [fix] (or throw [error]).
  void fakeFix({LocationFix? fix, Object? error}) {
    formLocate = () async {
      if (error != null) throw error;
      return fix!;
    };
    formSubdistricts = () async => areas;
    addTearDown(() {
      formLocate = () => throw UnimplementedError();
      formSubdistricts = () => throw UnimplementedError();
    });
  }

  Future<void> useMyLocation(FormHarness h) =>
      h.tapVisible(find.text('Use my location'));

  testWidgets('At the district centre: coordinates, ±5 m, Khlong Ton Sai', (
    tester,
  ) async {
    fakeFix(fix: (lat: 13.7228, lng: 100.5023, accuracyM: 5));
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list()))
        .firstWhere((p) => p.subdistrict != 'Khlong Ton Sai Subdistrict');
    await h.openEdit(p.id);
    await useMyLocation(h);

    expect(find.text('13.722800, 100.502300'), findsOneWidget);
    expect(find.text('±5 m'), findsOneWidget);
    expect(find.text('Khlong Ton Sai'), findsOneWidget);
    expect(
      find.text('Use my location replaced the saved coordinates.'),
      findsOneWidget,
    );
    expect(find.text(outsideDistrictMessage), findsNothing);

    await h.save();
    final saved = (await h.db(() => h.repo.getById(p.id)))!;
    expect(saved.lat, 13.7228);
    expect(saved.lng, 100.5023);
    expect(saved.gpsAccuracyM, 5);
    expect(saved.subdistrict, 'Khlong Ton Sai Subdistrict');
  });

  testWidgets('Outside the district the subdistrict stays, with a note', (
    tester,
  ) async {
    fakeFix(fix: (lat: 13.7563, lng: 100.5018, accuracyM: 12)); // Phra Nakhon
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.openEdit(p.id);
    await useMyLocation(h);

    expect(find.text(outsideDistrictMessage), findsOneWidget);
    expect(find.text('Outside Khlong San district'), findsOneWidget);
    expect(find.text('13.756300, 100.501800'), findsOneWidget);
    expect(find.text('±12 m'), findsOneWidget);
    await h.save();
    final saved = (await h.db(() => h.repo.getById(p.id)))!;
    expect(saved.subdistrict, p.subdistrict);
    expect(saved.lat, 13.7563);
  });

  testWidgets('Prefilled Add: the footer says the prefilled coordinates', (
    tester,
  ) async {
    fakeFix(fix: (lat: 13.7228, lng: 100.5023, accuracyM: 8));
    final h = await pumpFormHarness(tester);
    await h.openAdd();
    await useMyLocation(h);
    expect(
      find.text('Use my location replaced the prefilled coordinates.'),
      findsOneWidget,
    );
    expect(find.text('±8 m'), findsOneWidget);
  });

  testWidgets('Empty form: Use my location fills the required location', (
    tester,
  ) async {
    fakeFix(fix: (lat: 13.7228, lng: 100.5023, accuracyM: 5));
    final h = await pumpFormHarness(tester, seedData: false);
    await h.db(() async {
      for (final p in h.repo.pool) {
        await h.repo.insert(p, registeredBy: 'Sample data');
      }
    });
    await h.openAdd();
    await h.save();
    expect(find.text('Tap Use my location.'), findsOneWidget);
    expect(find.text('Choose a subdistrict.'), findsOneWidget);
    await useMyLocation(h);
    expect(find.text('Tap Use my location.'), findsNothing);
    expect(find.text('Choose a subdistrict.'), findsNothing);
    expect(find.text('Khlong Ton Sai'), findsOneWidget);
  });

  testWidgets('No fix: the reason shows and the coordinates stay', (
    tester,
  ) async {
    fakeFix(error: const LocationUnavailable('Location services are off.'));
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.openEdit(p.id);
    await useMyLocation(h);
    expect(find.text('Location services are off.'), findsOneWidget);
    expect(
      find.text('${p.lat.toStringAsFixed(6)}, ${p.lng.toStringAsFixed(6)}'),
      findsOneWidget,
    );
    expect(find.byType(PatientFormScreen), findsOneWidget);
  });

  test('the picker offers exactly the subdistrict polygons', () {
    expect(areas.names.toSet(), khlongSanSubdistricts.toSet());
  });
}
