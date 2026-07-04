import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import 'nav_items.dart';
import 'sidebar.dart';

/// App chrome adaptativo (spec 2026-07-04):
/// desktop ≥1100 → sidebar navy fixa · tablet 600–1100 → drawer ·
/// mobile <600 → bottom navigation (3 destinos + "Mais").
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
    final size = context.screenSize;

    void navigate(String route) {
      context.go(route);
      _scaffoldKey.currentState?.closeDrawer();
    }

    final isMobile = size == ScreenSize.mobile;
    final isDesktop = size == ScreenSize.desktop;
    // Colapso só no desktop; no drawer (tablet) sempre expandido.
    final collapsed = isDesktop && ref.watch(sidebarCollapsedProvider);

    final sidebar = SidebarContent(
      me: me,
      items: items,
      selectedIndex: selected,
      onNavigate: navigate,
      collapsed: collapsed,
      onToggleCollapse: isDesktop
          ? () => ref.read(sidebarCollapsedProvider.notifier).toggle()
          : null,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.neu.base,
      drawer:
          (!isDesktop && !isMobile) ? Drawer(width: 272, child: sidebar) : null,
      bottomNavigationBar: isMobile
          ? _NeuBottomBar(
              items: items,
              selectedIndex: selected,
              onNavigate: navigate,
            )
          : null,
      body: Row(
        children: [
          if (isDesktop) sidebar,
          Expanded(
            child: Column(
              children: [
                _ContentHeader(
                  title: items[selected].label,
                  showMenu: !isDesktop && !isMobile,
                ),
                // A transição entre telas é feita pelo Navigator do ShellRoute
                // (pageBuilder + neuPage), não aqui — envolver o child num
                // AnimatedSwitcher duplicava a GlobalKey da página do go_router.
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
    final neu = context.neu;
    // Faixa do topo com borda inferior em ONDA SIMÉTRICA (vale no centro, tipo
    // parábola) e cor levemente diferente do canvas (neu.surface sobre neu.base)
    // — o visual "soft" da referência. SafeArea(top) garante que no mobile o
    // conteúdo/botões não colidam com a barra de status.
    return PhysicalShape(
      clipper: _HeaderWaveClipper(),
      color: neu.surface,
      elevation: 3,
      shadowColor: neu.shadowDark,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding:
                EdgeInsets.only(left: showMenu ? 8 : 28, right: 20, bottom: 16),
            child: Row(
              children: [
                if (showMenu)
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu_rounded, color: neu.ink),
                      tooltip: 'Menu',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: neu.ink),
                ),
                const Spacer(),
                // Sino + toggle de tema vivem no overlay global (GlobalControls).
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recorta a faixa do topo com um BURACO côncavo simétrico no centro: as
/// laterais descem até o fim (`h`) e o meio é "escavado" para cima (`h - dip`),
/// como o topo da referência. Espelhado e responsivo (depende só da largura).
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const dip = 22.0;
    final edge = h - dip;
    final path = Path()
      ..lineTo(0, h)
      // Sobe suavemente das laterais até o topo do buraco no centro...
      ..cubicTo(w * 0.34, h, w * 0.40, edge, w * 0.50, edge)
      // ...e desce de volta, espelhado.
      ..cubicTo(w * 0.60, edge, w * 0.66, h, w, h)
      ..lineTo(w, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Bottom navigation neumórfica do mobile: até 3 destinos principais + "Mais"
/// (sheet com o restante do menu gated). Alvos grandes, rótulo sempre visível
/// (usuário pouco digital — ícone sozinho não basta).
class _NeuBottomBar extends StatelessWidget {
  const _NeuBottomBar({
    required this.items,
    required this.selectedIndex,
    required this.onNavigate,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final void Function(String route) onNavigate;

  static const int _slots = 3;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final primary = items.take(_slots).toList();
    final overflow = items.skip(_slots).toList();
    final overflowSelected = selectedIndex >= _slots;

    return Container(
      decoration: BoxDecoration(
        color: neu.surface,
        boxShadow: [
          BoxShadow(
            color: neu.shadowDark,
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < primary.length; i++)
                Expanded(
                  child: _BottomItem(
                    icon: primary[i].icon,
                    label: primary[i].label,
                    active: !overflowSelected && i == selectedIndex,
                    onTap: () => onNavigate(primary[i].route),
                  ),
                ),
              if (overflow.isNotEmpty)
                Expanded(
                  child: _BottomItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Mais',
                    active: overflowSelected,
                    onTap: () => _showMore(context, overflow),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMore(BuildContext context, List<NavItem> overflow) {
    final neu = context.neu;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: neu.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: neu.inkFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final item in overflow)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeuListTile(
                    leading: Icon(item.icon, color: neu.inkMuted, size: 22),
                    title: Text(item.label),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onNavigate(item.route);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final color = active ? neu.navy : neu.inkMuted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: active ? neu.accentTint : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
