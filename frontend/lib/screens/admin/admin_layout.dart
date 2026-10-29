import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/common.dart';

class _AdminDestination {
  const _AdminDestination(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

const _destinations = [
  _AdminDestination('Dashboard', Icons.dashboard_outlined, '/admin'),
  _AdminDestination('Drivers', Icons.badge_outlined, '/admin/drivers'),
  _AdminDestination('Routes', Icons.place_outlined, '/admin/routes'),
  _AdminDestination('Queues', Icons.people_outline, '/admin/queues'),
];

/// Admin shell: NavigationRail sa desktop, bottom NavigationBar sa phone.
class AdminLayout extends StatelessWidget {
  const AdminLayout({super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  int get _selectedIndex {
    final index = _destinations.indexWhere(
      (item) => item.path != '/admin' && currentPath.startsWith(item.path),
    );
    return index == -1 ? 0 : index;
  }

  void _go(BuildContext context, int index) {
    final path = _destinations[index].path;
    if (path != currentPath) context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final index = _selectedIndex;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text(
              'ParkKeys Admin',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: const [UserMenu()],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (value) => _go(context, value),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) => _go(context, value),
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}
