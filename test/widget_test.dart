import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bedridden_pt/main.dart';

void main() {
  testWidgets('app starts as a CupertinoApp with the placeholder home', (tester) async {
    await tester.pumpWidget(const BedriddenPtApp());

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });
}
