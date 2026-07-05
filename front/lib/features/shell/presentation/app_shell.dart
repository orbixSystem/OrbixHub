import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/session_state.dart';
import '../../customers/presentation/customer_form_dialog.dart';
import '../../customers/presentation/customers_providers.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../inventory/presentation/item_form_dialog.dart';
import '../../os/presentation/order_form_dialog.dart';
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
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
                // FAB de criação rápida aninhado no berço do header (centro).
                // Sobe para dentro do entalhe fundo → protrai só ~8px na tela.
                Positioned(
                  top: MediaQuery.of(context).padding.top + 68 - 46,
                  left: 0,
                  right: 0,
                  child: const Center(child: _QuickCreateFab()),
                ),
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
    // Faixa do topo com borda inferior em ENTALHE (berço do FAB) e cor levemente
    // diferente do canvas (neu.surface sobre neu.base) — o visual "soft" da
    // referência. SafeArea(top) impede o conteúdo de colidir com a barra de
    // status no mobile. Uma linha sobre a curva evita que a faixa se funda com
    // os cards abaixo (nos dois temas).
    return Stack(
      children: [
        PhysicalShape(
          clipper: _HeaderWaveClipper(),
          color: neu.surface,
          elevation: 3,
          shadowColor: neu.shadowDark,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 68,
              child: Padding(
                padding: EdgeInsets.only(
                    left: showMenu ? 8 : 28, right: 20, bottom: 16),
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
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _HeaderBorderPainter(
                color: neu.ink.withValues(alpha: 0.14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const double _headerNotchR = 64.0; // meia-largura do entalhe (~128px, cabe o FAB)
const double _headerNotchDepth = 48.0; // profundidade do recorte (berço fundo)

/// Traça a borda INFERIOR do header (reta com o entalhe circular no centro),
/// assumindo que o ponto atual já está em `(0, h)`. Compartilhada pelo clipper
/// (recorte) e pelo painter (linha da borda) para não divergirem.
void _traceHeaderBottom(Path path, double w, double h) {
  final cx = w / 2;
  const r = _headerNotchR;
  const depth = _headerNotchDepth;
  path
    ..lineTo(cx - r - 14, h)
    ..cubicTo(cx - r + 8, h, cx - r + 16, h - depth, cx, h - depth)
    ..cubicTo(cx + r - 16, h - depth, cx + r - 8, h, cx + r + 14, h)
    ..lineTo(w, h);
}

/// Recorta a faixa do topo com um ENTALHE circular pequeno e centralizado (um
/// "berço", como o notch do FAB na referência): borda inferior reta, com um
/// recorte suave no centro. Simétrico e responsivo (só depende da largura).
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, h);
    _traceHeaderBottom(path, w, h);
    path
      ..lineTo(w, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Desenha a linha da borda inferior do header (na própria curva do entalhe),
/// para a faixa não se fundir com os cards abaixo. Cor derivada do `ink` →
/// contrasta nos dois temas (hairline escuro no claro, claro no escuro).
class _HeaderBorderPainter extends CustomPainter {
  const _HeaderBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height);
    _traceHeaderBottom(path, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeaderBorderPainter old) => old.color != color;
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

/// Atalho de criação rápida aninhado no berço do header. Abre um menu com as
/// ações de criação que o usuário PODE fazer (gated por módulo + permissão).
/// Some quando não há nenhuma.
class _QuickCreateFab extends ConsumerWidget {
  const _QuickCreateFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) return const SizedBox.shrink();
    final actions = _quickActions(session.me);
    if (actions.isEmpty) return const SizedBox.shrink();
    final neu = context.neu;
    return Tooltip(
      message: 'Criar',
      child: GestureDetector(
        onTap: () => _openMenu(context, ref, actions),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: neu.navy,
              boxShadow: [
                BoxShadow(
                  color: neu.navy.withValues(alpha: 0.42),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(Icons.add_rounded, color: neu.onNavy, size: 28),
          ),
        ),
      ),
    );
  }

  void _openMenu(
    BuildContext context,
    WidgetRef ref,
    List<_QuickAction> actions,
  ) {
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
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  'Criar',
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final a in actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeuListTile(
                    leading: NeuIconChip.glyph(context,
                        icon: a.icon, index: a.glyph, size: 40),
                    title: Text(a.label),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _run(context, ref, a.key);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, String key) async {
    switch (key) {
      case 'os':
        final id = await OrderFormDialog.show(context);
        if (id != null && context.mounted) context.go('/m/os/$id');
      case 'customer':
        final cfg = ref.read(customersConfigProvider).value;
        final ok = await CustomerFormDialog.show(
          context,
          documentRequired: cfg?.documentRequired ?? false,
        );
        if (ok == true) ref.invalidate(customersListProvider);
      case 'product':
        final ok = await ItemFormDialog.show(context);
        if (ok == true) ref.invalidate(itemListProvider);
    }
  }

  List<_QuickAction> _quickActions(Me me) {
    return [
      if (me.hasModule('os') && me.hasPermission('os.write'))
        const _QuickAction('os', Icons.build_rounded, 0, 'Nova ordem de serviço'),
      if (me.hasModule('customers') && me.hasPermission('customer.write'))
        const _QuickAction(
            'customer', Icons.person_add_alt_1_rounded, 3, 'Novo cliente'),
      if (me.hasModule('inventory') && me.hasPermission('inventory.write'))
        const _QuickAction('product', Icons.inventory_2_rounded, 5,
            'Novo produto ou serviço'),
    ];
  }
}

/// Especificação de uma ação de criação rápida do [_QuickCreateFab].
class _QuickAction {
  const _QuickAction(this.key, this.icon, this.glyph, this.label);
  final String key;
  final IconData icon;
  final int glyph;
  final String label;
}
