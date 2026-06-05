import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import 'nav_items.dart';

/// App shell: persistent gated navigation around the routed [child]. Menu items
/// appear ONLY for the user's role + enabled modules (from `/me`). Routes are
/// also guarded in the router — hiding alone is never the security boundary.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final me = session.me;
    final items = gatedNavItems(me);
    final location = GoRouterState.of(context).matchedLocation;
    final selected = selectedNavIndex(items, location);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width >= 900,
            selectedIndex: selected,
            onDestinationSelected: (i) => context.go(items[i].route),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                children: [
                  const Icon(Icons.hub, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    me.activeTenant?.name ?? 'OrbixHub',
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (me.hasMultipleTenants)
                        IconButton(
                          tooltip: 'Trocar oficina',
                          icon: const Icon(Icons.swap_horiz),
                          onPressed: () => context.go('/picker'),
                        ),
                      IconButton(
                        tooltip: 'Sair',
                        icon: const Icon(Icons.logout),
                        onPressed: () =>
                            ref.read(sessionControllerProvider.notifier).logout(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
