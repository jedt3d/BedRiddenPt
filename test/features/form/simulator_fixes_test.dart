// Regressions from the Simulator run of #25/#26: a focused field scrolled
// out of view must stay built and focused (iOS kept its keyboard up over the
// photo sheet otherwise), opening a sheet closes the keyboard, and section
// headers are footnote captions, not large titles.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/features/form/form_widgets.dart';
import 'package:bedridden_pt/theme/tokens.dart';

import '../../data/test_db.dart';
import 'harness.dart';

void main() {
  initTestDatabases();

  testWidgets('A focused field scrolled away stays built; Change photo closes '
      'the keyboard', (tester) async {
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.openEdit(p.id);

    await tester.tap(h.field('Full name'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await h.scrollTo(find.text('Registered by'));
    expect(find.text('Full name', skipOffstage: false), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.drag(find.text('Registered by'), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await h.tapVisible(find.text('Change photo'));
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('Section headers are footnote captions', (tester) async {
    final h = await pumpFormHarness(tester);
    final p = (await h.db(() => h.repo.list())).first;
    await h.openEdit(p.id);
    final header = tester.widget<Text>(
      find.descendant(of: find.byType(Caption), matching: find.text('PATIENT')),
    );
    expect(header.style!.fontSize, AppText.footnote.fontSize);
    expect(header.style!.color, AppColors.labelSecondary);
  });
}
