// #27 walkthrough re-run: fast backspaces in the National ID / phone fields
// left hidden digits ("3-5" after clearing and typing 5) and lost keypresses.
// iOS edits its own copy of the text and sends the whole state; when a
// formatter rewrote it (adding dashes), the framework's setEditingState
// reached iOS after later keystrokes, and iOS went on from the stale text.
// The fields now hold digits only, so the framework never rewrites what iOS
// typed. FakeIos below keeps its own buffer and gets the framework's
// setEditingState only after a burst of keys, like the device.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/features/form/form_draft.dart';
import 'package:bedridden_pt/features/form/form_widgets.dart';
import 'package:bedridden_pt/shared/national_id.dart';
import 'package:bedridden_pt/theme/tokens.dart';

/// The iOS side of the text connection: its own text and cursor, edited by
/// each key, with the framework's setEditingState held until [land].
class FakeIos {
  FakeIos(this.tester, TextEditingController c)
    : text = c.text,
      cursor = c.selection.baseOffset,
      _read = tester.testTextInput.log.length;

  final WidgetTester tester;
  String text;
  int cursor;
  int _read;
  final _inFlight = <(String, int)>[];

  /// setEditingState calls the framework has sent since this fake started.
  int get setEditingStateCount => _sent;
  int _sent = 0;

  Future<void> _send() async {
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor),
      ),
    );
    await tester.idle();
    final log = tester.testTextInput.log;
    for (; _read < log.length; _read++) {
      if (log[_read].method != 'TextInput.setEditingState') continue;
      final m = log[_read].arguments as Map;
      _sent++;
      _inFlight.add((m['text'] as String, m['selectionBase'] as int));
    }
  }

  Future<void> backspace() async {
    if (cursor == 0) return;
    text = text.substring(0, cursor - 1) + text.substring(cursor);
    cursor--;
    await _send();
  }

  Future<void> type(String chars) async {
    for (final ch in chars.split('')) {
      text = text.substring(0, cursor) + ch + text.substring(cursor);
      cursor++;
      await _send();
    }
  }

  /// The burst is over: late states from the framework arrive now.
  void land() {
    for (final (t, c) in _inFlight) {
      text = t;
      cursor = c;
    }
    _inFlight.clear();
  }
}

void main() {
  const id = '3100149316490'; // 3-1001-49316-49-0

  late TextEditingController controller;
  const fieldWidth = 300.0;

  Future<void> pumpField(
    WidgetTester tester, {
    required String text,
    int maxDigits = 13,
    String Function(String) format = formatNationalId,
  }) async {
    controller = TextEditingController(text: text);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: DigitsField(
                    controller: controller,
                    placeholder: '13 digits',
                    maxDigits: maxDigits,
                    format: format,
                  ),
                ),
                const CupertinoTextField(placeholder: 'other'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<FakeIos> focusAt(WidgetTester tester, int cursor) async {
    await tester.showKeyboard(find.byType(CupertinoTextField).first);
    controller.selection = TextSelection.collapsed(offset: cursor);
    await tester.pump();
    return FakeIos(tester, controller);
  }

  String withCursor() {
    final o = controller.selection.baseOffset;
    return '${controller.text.substring(0, o)}|${controller.text.substring(o)}';
  }

  testWidgets('Clear fast, then type: no hidden digits come back', (
    tester,
  ) async {
    await pumpField(tester, text: id);
    final ios = await focusAt(tester, id.length);
    for (var i = 0; i < 20; i++) {
      await ios.backspace();
    }
    ios.land();
    await ios.type('5');
    ios.land();
    await tester.pump();
    expect(controller.text, '5'); // was "3-5" on the device
    expect(ios.text, controller.text);
    expect(ios.setEditingStateCount, 0);
  });

  testWidgets('Fast backspaces in the middle remove one digit each', (
    tester,
  ) async {
    await pumpField(tester, text: id);
    final ios = await focusAt(tester, 9); // 310014931|6490
    for (var i = 0; i < 6; i++) {
      await ios.backspace();
    }
    ios.land();
    await tester.pump();
    expect(withCursor(), '310|6490');
    expect(ios.text, controller.text);
    expect(ios.setEditingStateCount, 0);
  });

  testWidgets('Phone: fast backspaces at the end, then type', (tester) async {
    await pumpField(
      tester,
      text: '0877620274',
      maxDigits: 10,
      format: formatPhoneInput,
    );
    final ios = await focusAt(tester, 10);
    for (var i = 0; i < 4; i++) {
      await ios.backspace();
    }
    ios.land();
    expect(withCursor(), '087762|');
    for (var i = 0; i < 20; i++) {
      await ios.backspace();
    }
    ios.land();
    await ios.type('5');
    ios.land();
    await tester.pump();
    expect(controller.text, '5'); // was "076-5" on the device
    expect(ios.setEditingStateCount, 0);
  });

  testWidgets('Non-digits and a 14th digit are dropped', (tester) async {
    await pumpField(tester, text: '');
    await focusAt(tester, 0);
    tester.testTextInput.enterText('3-1001-49316-49-09');
    await tester.pump();
    expect(controller.text, id);
  });

  testWidgets('Grouped when not focused; digits plus a grouped caption while '
      'focused', (tester) async {
    await pumpField(tester, text: id);
    final grouped = formatNationalId(id);
    expect(find.text(grouped), findsOneWidget);
    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField).first,
    );
    expect(field.style!.color, AppColors.transparent);

    await focusAt(tester, id.length);
    expect(controller.text, id);
    final caption = tester.widget<Text>(find.text(grouped));
    expect(caption.style!.fontSize, AppText.footnote.fontSize);
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField).first)
          .style!
          .color,
      AppColors.labelPrimary,
    );

    // Partly typed: the caption groups what's there.
    controller.text = '31001';
    await tester.pump();
    expect(find.text('3-1001'), findsOneWidget);

    await tester.showKeyboard(find.byType(CupertinoTextField).last);
    await tester.pump();
    expect(find.text('3-1001'), findsOneWidget); // painted over the field
    expect(controller.text, '31001');
  });

  testWidgets('A tap right of the digits focuses the field', (tester) async {
    await pumpField(tester, text: '31001');
    final box = tester.getRect(find.byType(DigitsField));
    await tester.tapAt(box.centerRight.translate(-AppSpace.s4, 0));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text('3-1001'), findsOneWidget); // now the caption
  });

  testWidgets('Empty and not focused shows the placeholder', (tester) async {
    await pumpField(tester, text: '');
    expect(find.text('13 digits'), findsOneWidget);
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField).first)
          .style!
          .color,
      AppColors.labelPrimary,
    );
  });
}
