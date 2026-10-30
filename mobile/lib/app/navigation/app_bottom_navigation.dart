import 'package:flutter/material.dart';

import '../routes.dart';
import 'main_tabs.dart';
import 'tab_chrome.dart';

/// Canonical five destinations. Existing detail routes stay in the same Navigator.
class AppBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final TabChromeController? chrome;
  final bool forceChromeVisible;
  final ValueChanged<int>? onFallback;
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    this.onFallback,
    this.chrome,
    this.forceChromeVisible = false,
  });

  static const labels = ['Cộng đồng', 'Trang chủ', 'Tin nhắn', 'Lịch', 'Hồ sơ'];
  static const destinations = [
    AppRoutes.community,
    AppRoutes.home,
    AppRoutes.chatHome,
    AppRoutes.calendar,
    AppRoutes.profile,
  ];
  static const icons = [
    Icons.public_outlined,
    Icons.home_outlined,
    Icons.chat_bubble_outline,
    Icons.calendar_today_outlined,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final bar = BottomNavigationBar(
      currentIndex: selectedIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        FocusManager.instance.primaryFocus?.unfocus();
        final settings = RouteSettings(name: destinations[index]);
        if (selectRetainedTab(context, settings)) return;
        if (onFallback != null) {
          onFallback!(index);
        } else {
          Navigator.of(context).pushNamed(destinations[index]);
        }
      },
      items: [
        for (var i = 0; i < labels.length; i++)
          BottomNavigationBarItem(icon: Icon(icons[i]), label: labels[i]),
      ],
    );
    return chrome == null
        ? bar
        : TabChromeRegion(
            controller: chrome!,
            forceVisible: forceChromeVisible,
            child: bar,
          );
  }
}
