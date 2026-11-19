// Detail (SPEC §7.4): #19 all fields, Buddhist-era dates, mini map;
// #20 Call / Navigate / Edit.

import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bedridden_pt/app/app_scope.dart';
import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/data/volunteer_store.dart';
import 'package:bedridden_pt/app/routes.dart';
import 'package:bedridden_pt/features/form/patient_form_screen.dart';
import 'package:bedridden_pt/features/detail/detail_actions.dart';
import 'package:bedridden_pt/features/detail/detail_format.dart';
import 'package:bedridden_pt/features/detail/detail_mini_map.dart';
import 'package:bedridden_pt/features/detail/detail_screen.dart';
import 'package:bedridden_pt/shared/care_style.dart';

import '../../data/test_db.dart';

void main() {
  initTestDatabases();

  setUp(() {
    detailClock = () => DateTime(2026, 11, 20);
    miniMapShowTiles = false;
  });
  tearDown(() {
    detailClock = DateTime.now;
    miniMapShowTiles = true;
    detailLaunchUrl = (uri, mode) => launchUrl(uri, mode: mode);
  });

  /// Records launched URLs instead of opening them; returns [result].
  List<(Uri, LaunchMode)> fakeLauncher({bool result = true}) {
    final launched = <(Uri, LaunchMode)>[];
    detailLaunchUrl = (uri, mode) async {
      launched.add((uri, mode));
      return result;
    };
    return launched;
  }

  Finder button(String label) => find.widgetWithText(CupertinoButton, label);

  /// A seeded repository whose first patient is changed by [edit].
  Future<(PatientRepository, Patient)> seeded(
    WidgetTester tester, [
    Patient Function(Patient)? edit,
  ]) async {
    final result = (await tester.runAsync(() async {
      final repo = await openTestRepository();
      await repo.seedSampleData();
      var p = (await repo.list()).first;
      if (edit != null) p = await repo.update(edit(p));
      return (repo, p);
    }))!;
    addTearDown(() => tester.runAsync(result.$1.close));
    return result;
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    PatientRepository repo,
    String id,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final volunteer = (await tester.runAsync(VolunteerStore.open))!;
    final showInactive = ValueNotifier(false);
    addTearDown(showInactive.dispose);
    await tester.pumpWidget(
      AppScope(
        patients: repo,
        volunteer: volunteer,
        showInactive: showInactive,
        child: CupertinoApp(
          home: DetailScreen(patientId: id),
          onGenerateRoute: Routes.onGenerateRoute,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('born 1950 shows "Born 2493 (age 76)"; map centres on the pin', (
    tester,
  ) async {
    final (repo, p) = await seeded(tester, (p) => p.copyWith(birthYear: 1950));
    await pumpDetail(tester, repo, p.id);

    expect(find.textContaining('Born 2493 (age 76)'), findsOneWidget);
    expect(find.text('2493 (age 76)'), findsOneWidget);

    final pin = LatLng(p.lat, p.lng);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter, pin);
    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markers.markers.single.point, pin);
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(MarkerLayer),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.color, CareStyle.pinColorFor(p));
  });

  testWidgets('shows every field with display labels and formats', (
    tester,
  ) async {
    final (repo, p) = await seeded(
      tester,
      (p) => p.copyWith(
        nationalId: '1101700203450',
        sex: Sex.female,
        contactRelation: ContactRelation.otherRelative,
        phones: ['0637592951', '0812345678'],
        subdistrict: 'Somdet Chao Phraya Subdistrict',
        addressNote: 'Soi Itsaraphap 8',
        lat: 13.730103,
        lng: 100.498575,
        gpsAccuracyM: () => 5,
        adlScore: () => 1,
        careLevel: CareLevel.bedridden,
        mainCondition: MainCondition.spinalInjury,
        livingSituation: LivingSituation.elderlyCaregiver,
        careNeeds: {CareNeed.needsAirMattress, CareNeed.bedsore},
        status: PatientStatus.inHospital,
        notes: 'Receives the elderly allowance',
      ),
    );
    // Tall enough that the lazy list builds every row; wide for the test font.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpDetail(tester, repo, p.id);

    for (final text in [
      p.fullName,
      '1-1017-00203-45-0',
      'Other relative',
      p.contactName,
      'Phone 1',
      '063-759-2951',
      'Phone 2',
      '081-234-5678',
      'Somdet Chao Phraya',
      'Soi Itsaraphap 8',
      '13.730103, 100.498575',
      '±5 m',
      '1 of 20',
      'Spinal injury',
      'Elderly caregiver',
      'Bedsore\nAir mattress',
      'Receives the elderly allowance',
      'Call dials the first phone number.',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    // In hospital appears in the header and the Status row.
    expect(find.text('In hospital'), findsNWidgets(2));
    expect(find.text('Bedridden'), findsWidgets);
  });

  testWidgets('reloads after a repository change', (tester) async {
    final (repo, p) = await seeded(tester);
    await pumpDetail(tester, repo, p.id);
    expect(find.text('Renamed Person'), findsNothing);

    await tester.runAsync(
      () => repo.update(p.copyWith(fullName: 'Renamed Person')),
    );
    await settle(tester);
    expect(find.text('Renamed Person'), findsWidgets);
  });

  testWidgets('Call dials Phone 1 with tel:', (tester) async {
    final launched = fakeLauncher();
    final (repo, p) = await seeded(
      tester,
      (p) => p.copyWith(phones: ['0637592951', '0812345678']),
    );
    await pumpDetail(tester, repo, p.id);

    await tester.tap(button('Call'));
    await tester.pump();
    expect(launched, [
      (Uri.parse('tel:0637592951'), LaunchMode.platformDefault),
    ]);
  });

  testWidgets('Call is disabled with no phone number', (tester) async {
    final launched = fakeLauncher();
    final (repo, p) = await seeded(tester, (p) => p.copyWith(phones: []));
    await pumpDetail(tester, repo, p.id);

    expect(tester.widget<CupertinoButton>(button('Call')).onPressed, isNull);
    await tester.tap(button('Call'), warnIfMissed: false);
    await tester.pump();
    expect(launched, isEmpty);
    expect(tester.widget<CupertinoButton>(button('Navigate')).enabled, isTrue);
  });

  testWidgets('Navigate opens Apple Maps at the patient, outside the app', (
    tester,
  ) async {
    final launched = fakeLauncher();
    final (repo, p) = await seeded(
      tester,
      (p) => p.copyWith(lat: 13.730103, lng: 100.498575),
    );
    await pumpDetail(tester, repo, p.id);

    await tester.tap(button('Navigate'));
    await tester.pump();
    expect(launched, [
      (
        Uri.parse('https://maps.apple.com/?daddr=13.730103%2C100.498575'),
        LaunchMode.externalApplication,
      ),
    ]);
  });

  testWidgets('a URL that cannot open shows an alert', (tester) async {
    fakeLauncher(result: false);
    final (repo, p) = await seeded(tester);
    await pumpDetail(tester, repo, p.id);

    await tester.tap(button('Navigate'));
    await tester.pumpAndSettle();
    expect(find.text("Can't open Maps on this device."), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('the single Edit button opens the form for this patient', (
    tester,
  ) async {
    final (repo, p) = await seeded(tester);
    await pumpDetail(tester, repo, p.id);

    expect(button('Edit'), findsOneWidget);
    await tester.tap(button('Edit'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PatientFormScreen>(find.byType(PatientFormScreen))
          .patientId,
      p.id,
    );
  });

  test('formats', () {
    expect(formatPhone('0637592951'), '063-759-2951');
    expect(formatPhone('12345'), '12345');
    expect(gpsAccuracyText(null), 'Not recorded');
    expect(gpsAccuracyText(4.6), '±5 m');
    expect(coordinatesText(13.7, 100.5), '13.700000, 100.500000');
    expect(timestampText('2026-11-19T09:00:00.000'), '19 Nov 2569, 09:00');
    expect(timestampText(''), '—');
  });
}

/// Lets the repository's database futures finish, then pumps the frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}
