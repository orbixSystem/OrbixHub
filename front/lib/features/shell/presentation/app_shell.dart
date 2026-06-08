import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import 'nav_items.dart';
import 'sidebar.dart';

/// Responsive app chrome: a persistent graphite sidebar on wide screens, a
/// drawer on narrow ones, and a content header that titles the active page.
/// Routed screens render only their body — the shell owns the chrome.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final me = session.me;
    final items = gatedNavItems(me);
    final location = GoRouterState.of(context).matchedLocation;
    final selected = selectedNavIndex(items, location);
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    void navigate(String route) {
      context.go(route);
      _scaffoldKey.currentState?.closeDrawer();
    }

    final sidebar = SidebarContent(
      me: me,
      items: items,
      selectedIndex: selected,
      onNavigate: navigate,
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: wide ? null : Drawer(width: 272, child: sidebar),
      body: Row(
        children: [
          if (wide) sidebar,
          Expanded(
            child: Column(
              children: [
                _ContentHeader(title: items[selected].label, showMenu: !wide),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({required this.title, required this.showMenu});

  final String title;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.only(left: showMenu ? 8 : 28, right: 20),
      child: Row(
        children: [
          if (showMenu)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
        ],
      ),
    );
  }
}
