import 'package:flutter/cupertino.dart';

void main() {
  runApp(const BedriddenPtApp());
}

/// Root widget. Cupertino only (SPEC §2): no Material widgets in screens.
class BedriddenPtApp extends StatelessWidget {
  const BedriddenPtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Bedridden Patient Locator',
      home: PlaceholderHome(),
    );
  }
}

/// Temporary home screen until the app shell lands.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Bedridden Patient Locator')),
      child: Center(child: Text('Coming soon')),
    );
  }
}
