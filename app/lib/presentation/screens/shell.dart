import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The five main destinations (section 8.2 — the important parts must be one
/// tap away).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _destinations = <({String path, IconData icon, IconData active, String label})>[
    (path: '/home', icon: Icons.home_outlined, active: Icons.home_rounded, label: 'خانه'),
    (
      path: '/search',
      icon: Icons.search_rounded,
      active: Icons.search_rounded,
      label: 'جست‌وجو',
    ),
    (
      path: '/watchlist',
      icon: Icons.bookmark_outline_rounded,
      active: Icons.bookmark_rounded,
      label: 'فهرست من',
    ),
    (
      path: '/lists',
      icon: Icons.playlist_play_rounded,
      active: Icons.playlist_add_check_rounded,
      label: 'فهرست‌ها',
    ),
    (
      path: '/profile',
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
      label: 'پروفایل',
    ),
  ];

  int _indexOf(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _destinations.indexWhere((d) => location.startsWith(d.path));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexOf(context);

    // Android back from a tab should walk back to Home, not drop the user out
    // of the app — only Home itself exits.
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => context.go(_destinations[i].path),
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.active),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}
