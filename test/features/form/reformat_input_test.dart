// #27 walkthrough: rapid backspaces in the National ID field dropped or
// misplaced digits. The field reformats to 3-XXXX-XXXXX-XX-X on every edit
// (ReformatInput); these tests delete like the iOS keyboard does (one
// editing-value update per backspace, no frame in between when rapid) and
// check the digits and the cursor.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/features/form/form_draft.dart';
import 'package:bedridden_pt/features/form/form_widgets.dart';
import 'package:bedridden_pt/shared/national_id.dart';

void main() {
  const full = '3102023946631'; // 3-1020-23946-63-1

  late TextEditingController controller;

  Future<void> pumpField(
    WidgetTester tester,
    String Function(String) format,
    String text, {
    required int cursor,
  }) async {
    controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: CupertinoTextField(
              controller: controller,
              inputFormatters: [ReformatInput(format)],
            ),
          ),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(CupertinoTextField));
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
    await tester.pump();
  }

  /// What iOS sends for one backspace: the character before the cursor gone.
  void backspace(WidgetTester tester) {
    final v = controller.value;
    final at = v.selection.baseOffset;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: v.text.substring(0, at - 1) + v.text.substring(at),
        selection: TextSelection.collapsed(offset: at - 1),
      ),
    );
  }

  String digits() => controller.text.replaceAll(RegExp(r'[^0-9]'), '');

  /// How many digits are left of the cursor.
  int digitsBeforeCursor() => controller.text
      .substring(0, controller.selection.baseOffset)
      .replaceAll(RegExp(r'[^0-9]'), '')
      .length;

  testWidgets('rapid backspaces at the end remove one digit each', (
    tester,
  ) async {
    final text = formatNationalId(full);
    await pumpField(tester, formatNationalId, text, cursor: text.length);
    for (var n = 1; n <= 13; n++) {
      backspace(tester); // no pump: rapid
      expect(digits(), full.substring(0, 13 - n), reason: 'backspace $n');
      expect(controller.selection.baseOffset, controller.text.length);
    }
    await tester.pump();
    expect(controller.text, isEmpty);
  });

  testWidgets('backspaces in the middle delete there and keep the cursor', (
    tester,
  ) async {
    final text = formatNationalId(full); // 3-1020-23946-63-1
    // Cursor after "3-1020-2" (6 digits).
    await pumpField(tester, formatNationalId, text, cursor: 8);
    backspace(tester);
    backspace(tester); // rapid
    await tester.pump();
    // Removed the 6th then the 5th digit ('2', then the '0' across the dash).
    expect(
      digits(),
      '3102'
      '3946631',
    );
    expect(controller.text, formatNationalId('31023946631'));
    expect(digitsBeforeCursor(), 4);
    expect(controller.selection.isCollapsed, isTrue);
  });

  testWidgets('backspace right after a dash deletes the digit before it', (
    tester,
  ) async {
    final text = formatNationalId(full);
    // Cursor right after the second dash: "3-1020-|23946-63-1".
    await pumpField(tester, formatNationalId, text, cursor: 7);
    backspace(tester);
    await tester.pump();
    expect(
      digits(),
      '3102'
      '23946631',
    );
    expect(digitsBeforeCursor(), 4);
  });

  testWidgets('typing in the middle keeps the cursor after the new digit', (
    tester,
  ) async {
    await pumpField(tester, formatNationalId, '3-1020-2394', cursor: 2);
    final v = controller.value;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '${v.text.substring(0, 2)}9${v.text.substring(2)}',
        selection: const TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();
    expect(
      digits(),
      '391020'
      '2394',
    );
    expect(digitsBeforeCursor(), 2);
  });

  testWidgets('phones: backspace after a dash deletes the digit before it', (
    tester,
  ) async {
    // "081-234-|5678"
    await pumpField(tester, formatPhoneInput, '081-234-5678', cursor: 8);
    backspace(tester);
    await tester.pump();
    expect(
      digits(),
      '08123'
      '5678',
    );
    expect(digitsBeforeCursor(), 5);
  });
}
