import 'package:flutter/cupertino.dart';

import '../features/list/list_tab.dart';
import '../features/map/map_tab.dart';

/// Home: the List | Map tabs (SPEC §7.2). Each tab has its own navigator;
/// Detail, Add and Edit go on the root navigator through [Routes].
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'List',
          ),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.map), label: 'Map'),
        ],
      ),
      tabBuilder: (context, index) => CupertinoTabView(
        builder: (context) => index == 0 ? const ListTab() : const MapTab(),
      ),
    );
  }
}
