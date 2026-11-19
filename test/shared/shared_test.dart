import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/data/patient.dart';
import 'package:bedridden_pt/data/patient_repository.dart';
import 'package:bedridden_pt/shared/care_style.dart';
import 'package:bedridden_pt/shared/labels.dart';
import 'package:bedridden_pt/shared/national_id.dart';
import 'package:bedridden_pt/shared/patient_avatar.dart';
import 'package:bedridden_pt/theme/tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('national ID', () {
    test('all 50 pool IDs pass the checksum; a changed digit fails', () async {
      final pool = await loadSamplePool();
      for (final p in pool) {
        expect(isValidNationalId(p.nationalId), isTrue, reason: p.nationalId);
        final n = p.nationalId;
        final bad = '${n.substring(0, 12)}${(int.parse(n[12]) + 1) % 10}';
        expect(isValidNationalId(bad), isFalse);
      }
      expect(isValidNationalId('310157926859'), isFalse);
      expect(isValidNationalId('31015792685a9'), isFalse);
    });

    test('formats as 3-XXXX-XXXXX-XX-X and parses back', () {
      expect(formatNationalId('3101579268599'), '3-1015-79268-59-9');
      expect(formatNationalId('31015'), '3-1015');
      expect(formatNationalId('310157'), '3-1015-7');
      expect(formatNationalId(''), '');
      expect(formatNationalId('3-1015-79268-59-9 12'), '3-1015-79268-59-9');
      expect(parseNationalId('3-1015-79268-59-9'), '3101579268599');
      expect(parseNationalId('3-1015-79268-59'), isNull);
    });
  });

  test('every enum value has a label', () {
    expect(ContactRelation.otherRelative.label, 'Other relative');
    expect(CareNeed.needsAirMattress.label, 'Air mattress');
    expect(CareNeed.needsWheelchair.label, 'Wheelchair');
    expect(PatientStatus.inHospital.label, 'In hospital');
    expect(MainCondition.spinalInjury.label, 'Spinal injury');
    expect(LivingSituation.livesAlone.label, 'Lives alone');
    for (final l in [
      ...Sex.values.map((v) => v.label),
      ...ContactRelation.values.map((v) => v.label),
      ...CareLevel.values.map((v) => v.label),
      ...MainCondition.values.map((v) => v.label),
      ...LivingSituation.values.map((v) => v.label),
      ...PatientStatus.values.map((v) => v.label),
      ...CareNeed.values.map((v) => v.label),
    ]) {
      expect(l, matches(RegExp(r'^[A-Z][a-z]*( [a-z]+)*$')));
    }
  });

  test(
    'care style colours come from the tokens; inactive pins are grey',
    () async {
      final pool = await loadSamplePool();
      expect(CareStyle.of(CareLevel.bedridden).pin, AppColors.pinBedridden);
      expect(
        CareStyle.of(CareLevel.social).badgeText,
        AppColors.careSocialText,
      );
      final deceased = pool.firstWhere(
        (p) => p.status == PatientStatus.deceased,
      );
      expect(CareStyle.pinColorFor(deceased), AppColors.pinInactive);
      final active = pool.firstWhere((p) => p.status == PatientStatus.active);
      expect(CareStyle.pinColorFor(active), CareStyle.of(active.careLevel).pin);
    },
  );

  group('avatar', () {
    test('initials and documents file resolution', () {
      expect(initialsOf('Somchit Bunyuen'), 'SB');
      expect(initialsOf(' thongdi '), 'T');
      final docs = Directory('/new/container/Documents');
      expect(
        documentsPhotoFile(docs, 'photo_1.jpg').path,
        '/new/container/Documents/photo_1.jpg',
      );
      expect(
        documentsPhotoFile(docs, '/old/container/Documents/photo_1.jpg').path,
        '/new/container/Documents/photo_1.jpg',
      );
      expect(
        isBundledPhoto('assets/avatars/avatar_01_female_age_72.png'),
        isTrue,
      );
    });

    testWidgets('bundled photo, missing file and no photo', (tester) async {
      final pool = (await tester.runAsync(loadSamplePool))!;
      final p = pool.first;
      final tmp = Directory.systemTemp.createTempSync('avatar_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      photoDirectory = () async => tmp;

      Future<void> show(Patient patient) => tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: PatientAvatar(patient: patient, size: AppSpace.s60),
          ),
        ),
      );

      await show(p);
      expect(find.byType(Image), findsOneWidget);

      await show(p.copyWith(photoPath: () => null));
      expect(find.text(initialsOf(p.fullName)), findsOneWidget);

      await show(p.copyWith(photoPath: () => 'photo_missing.jpg'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text(initialsOf(p.fullName)), findsOneWidget);

      File('${tmp.path}/photo_ok.png').writeAsBytesSync(
        File('assets/avatars/avatar_01_female_age_72.png').readAsBytesSync(),
      );
      await show(p.copyWith(photoPath: () => 'photo_ok.png'));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
