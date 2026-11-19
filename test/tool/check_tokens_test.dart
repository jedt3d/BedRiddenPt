// Runs tool/check_tokens.sh against planted files, so the check itself is
// tested in CI.
@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('check_tokens_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ProcessResult check(String source) {
    File('${dir.path}/screen.dart').writeAsStringSync(source);
    return Process.runSync('bash', ['tool/check_tokens.sh', dir.path]);
  }

  test('passes on the real lib/', () {
    final r = Process.runSync('bash', ['tool/check_tokens.sh']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test('passes on token use and comments', () {
    final r = check('''
// Colors.red and Color(0xFF000000) in a comment are fine.
final a = AppColors.accent;
final b = EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8);
final c = BorderRadius.all(Radius.circular(AppRadius.card));
final d = AppText.body.copyWith(color: AppColors.labelSecondary);
final e = EdgeInsets.zero;
''');
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  for (final bad in [
    'const a = Color(0xFF000000);',
    'final a = Color.fromARGB(255, 0, 0, 0);',
    'final a = Colors.red;',
    'final a = CupertinoColors.systemRed;',
    'final a = TextStyle(fontSize: 14);',
    'final a = EdgeInsets.all(8);',
    'final a = EdgeInsets.only(\n  left: AppSpace.s8,\n  top: 4,\n);',
    'final a = BorderRadius.circular(12);',
    'final a = BorderRadius.all(Radius.circular(8));',
  ]) {
    test('fails on: $bad', () {
      final r = check(bad);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
    });
  }

  test('ignores lib/theme/', () {
    Directory('${dir.path}/theme').createSync();
    File('${dir.path}/theme/tokens.dart').writeAsStringSync('const a = Color(0xFF000000);');
    final r = Process.runSync('bash', ['tool/check_tokens.sh', dir.path]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });
}
