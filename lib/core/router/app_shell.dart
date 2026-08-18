import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';

/// Ported from findme_app/app/(app)/_layout.tsx -- six tabs mirroring the mockup's main
/// sections. Emoji icons for now, same as the original (kept the dependency list
/// minimal rather than pulling in an icon package).
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  static const _tabs = [
    (label: 'Situation Room', icon: '🛰️'),
    (label: 'Map', icon: '🌐'),
    (label: 'Intel', icon: '📰'),
    (label: 'People & Devices', icon: '👥'),
    (label: 'Alerts', icon: '⚠️'),
    (label: 'Privacy Center', icon: '🔒'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.ink3,
        selectedFontSize: 9,
        unselectedFontSize: 9,
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        items: [
          for (final tab in _tabs)
            BottomNavigationBarItem(icon: Text(tab.icon, style: const TextStyle(fontSize: 18)), label: tab.label),
        ],
      ),
    );
  }
}
