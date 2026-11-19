// Form (SPEC §2, §6, §7.3, Figma frame 20) #26: Change photo → Take photo /
// Choose from library; the picked file is copied into the documents folder,
// photo_path stores only its file name, and the row shows it after a
// restart.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/features/form/form_photo.dart';
import 'package:bedridden_pt/features/form/patient_form_screen.dart';
import 'package:bedridden_pt/shared/patient_avatar.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  late Directory temp;
  late Directory documents;
  late String picked;
  final realPhotoDirectory = photoDirectory;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('form_photo_');
    documents = Directory('${temp.path}/Documents')..createSync();
    final avatar = Directory('assets/avatars')
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.png'));
    picked = avatar.copySync('${temp.path}/IMG_0001.PNG').path;
    photoDirectory = () async => documents;
  });
  tearDown(() {
    photoDirectory = realPhotoDirectory;
    formPickImage = (_) => throw UnimplementedError();
    temp.deleteSync(recursive: true);
  });

  /// Lets real file I/O finish, then rebuilds.
  Future<void> waitForFiles(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  bool showsFilePhoto(WidgetTester tester) => tester
      .widgetList<Image>(find.byType(Image))
      .any((i) => i.image is FileImage);

  testWidgets('Change photo opens the Take photo / Choose from library sheet', (
    tester,
  ) async {
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.openEdit(p.id);

    await h.tapVisible(find.text('Change photo'));
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.text('Patient photo'), findsOneWidget);
    expect(
      find.text('The Simulator has no camera; use the photo library there.'),
      findsOneWidget,
    );
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from library'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoActionSheet),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsNothing);
  });

  testWidgets('A library photo is copied to documents, stored by file name, '
      'and still shows after a restart', (tester) async {
    final sources = <PhotoSource>[];
    formPickImage = (source) async {
      sources.add(source);
      return picked;
    };
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.openEdit(p.id);

    await h.tapVisible(find.text('Change photo'));
    await tester.tap(find.text('Choose from library'));
    await waitForFiles(tester);
    expect(sources, [PhotoSource.library]);
    expect(showsFilePhoto(tester), isTrue);

    await h.save();
    final saved = (await h.db(() => h.repo.getById(p.id)))!;
    final name = saved.photoPath!;
    expect(name, matches(RegExp(r'^photo_[0-9a-f-]{36}\.png$')));
    expect(File('${documents.path}/$name').existsSync(), isTrue);
    expect(File(picked).existsSync(), isTrue); // copied, not moved

    // "Restart": a fresh widget tree on the same database and documents.
    await tester.pumpWidget(const SizedBox());
    await h.rebuildApp();
    await waitForFiles(tester);
    expect(find.text(saved.fullName), findsOneWidget);
    expect(showsFilePhoto(tester), isTrue);
  });

  testWidgets('Cancelling the picker keeps the photo', (tester) async {
    formPickImage = (_) async => null;
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.openEdit(p.id);
    await h.tapVisible(find.text('Change photo'));
    await tester.tap(find.text('Choose from library'));
    await waitForFiles(tester);
    await h.save();
    expect((await h.db(() => h.repo.getById(p.id)))!.photoPath, p.photoPath);
  });

  testWidgets('No camera: an alert points to the library', (tester) async {
    formPickImage = (_) async => throw Exception('no_available_camera');
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.openEdit(p.id);
    await h.tapVisible(find.text('Change photo'));
    await tester.tap(find.text('Take photo'));
    await waitForFiles(tester);
    expect(
      find.text('The camera isn’t available. Choose from library instead.'),
      findsOneWidget,
    );
    expect(find.byType(PatientFormScreen), findsOneWidget);
  });
}
