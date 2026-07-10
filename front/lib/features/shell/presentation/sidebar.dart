import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/offline/widgets/connection_chip.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import '../../messages/presentation/messages_providers.dart';
import 'nav_items.dart';

/// Estado (persistido) de colapso da sidebar no desktop — só ícones + tooltips.
final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
        SidebarCollapsedNotifier.new);

class SidebarCollapsedNotifier extends Notifier<bool> {
  static const _key = 'sidebar_collapsed';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getBool(_key);
    if (v != null && v != state) state = v;
  }

  Future<void> toggle() async {
    state = !state;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, state);
  }
}

/// Cores da sidebar. No claro é um painel navy; no escuro é um navy MAIS ESCURO
/// que o canvas (antes ficavam quase iguais) + relevo na borda para separar.
class _SideColors {
  _SideColors(BuildContext context)
      : _neu = context.neu,
        light = Theme.of(context).brightness == Brightness.light;

  final NeuTokens _neu;
  final bool light;

  /// Painel escuro tingido com o MATIZ do tema (segue a cor-semente escolhida),
  /// para o sidebar acompanhar a paleta em vez de ficar navy fixo. Em temas
  /// acromáticos (Preto & Branco), o navy é um cinza neutro: não forçamos
  /// saturação (senão o mínimo tom residual viraria um azul-arroxeado).
  Color _panel(double lightness, double saturation) {
    final navy = HSLColor.fromColor(_neu.navy);
    final s = navy.saturation < 0.08 ? 0.0 : saturation;
    return HSLColor.fromAHSL(1, navy.hue, s, lightness).toColor();
  }

  // Dark: bem mais escuro que o canvas — separa a sidebar. Claro: painel médio.
  Color get bg => light ? _panel(0.215, 0.24) : _panel(0.105, 0.34);
  Color get bgHi => light ? _panel(0.29, 0.22) : _panel(0.16, 0.30);
  Color get line => light ? _panel(0.315, 0.22) : _panel(0.235, 0.26);
  Color get fg => const Color(0xFFF2F3F8);
  Color get fgMuted => _panel(light ? 0.70 : 0.66, 0.16);
  Color get accent => _neu.accent;
  Color get badge => _neu.danger;

  /// Relevo interno (item ativo / chip) sobre o painel escuro.
  List<BoxShadow> get raised => const [
        BoxShadow(color: Color(0x59090B15), blurRadius: 10, offset: Offset(4, 4)),
        BoxShadow(color: Color(0x22515A8C), blurRadius: 10, offset: Offset(-3, -3)),
      ];

  /// Sombra da borda direita — mesma sombra do arco/header (neu.shadowDark),
  /// para padronizar a separação da moldura.
  List<BoxShadow> get edge => [
        BoxShadow(color: _neu.shadowDark, blurRadius: 16, offset: const Offset(2, 0)),
      ];

  /// Contorno da sidebar (direita + base). Como o painel é escuro nos dois
  /// temas, uma linha escura (como a do arco) sumiria; então usamos um RIM CLARO
  /// (highlight) que, junto da sombra [edge], dá o mesmo contorno "esculpido" do
  /// arco — visível no claro e no escuro.
  Border get edgeBorder {
    final rim = BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.5);
    return Border(right: rim, bottom: rim);
  }
}

/// The navy navigation sidebar content, shared by the persistent desktop
/// sidebar (opcionalmente [collapsed]) e o drawer do tablet.
class SidebarContent extends ConsumerWidget {
  const SidebarContent({
    super.key,
    required this.me,
    required this.items,
    required this.selectedIndex,
    required this.onNavigate,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  final Me me;
  final List<NavItem> items;
  final int selectedIndex;
  final void Function(String route) onNavigate;

  /// Modo compacto (só ícones + tooltips) — desktop.
  final bool collapsed;

  /// Se dado, mostra o botão de colapsar/expandir (desktop).
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _SideColors(context);
    final unreadMessages = ref.watch(unreadConversationsCountProvider);
    final logoUrl = ref
        .watch(settingsControllerProvider)
        .whenOrNull(data: (b) => b.company['logoUrl'] as String?);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      width: collapsed ? 76 : 272,
      decoration:
          BoxDecoration(color: c.bg, boxShadow: c.edge, border: c.edgeBorder),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          // Constraints justas (largura corrente) para os dois layouts durante
          // a animação — evita overflow ao encolher/expandir.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [...previousChildren, ?currentChild],
          ),
          child: Column(
            key: ValueKey(collapsed),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Topo: marca (+ botão de colapsar no desktop).
            Padding(
              padding: EdgeInsets.fromLTRB(collapsed ? 0 : 22, 22, collapsed ? 0 : 14, 14),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                children: [
                  if (collapsed)
                    const OrbixGlyph(size: 28, onDark: true)
                  else
                    const Flexible(child: BrandMark(size: 26, onDark: true)),
                  if (!collapsed && onToggleCollapse != null)
                    _GhostIconButton(
                      icon: Icons.menu_open_rounded,
                      tooltip: 'Recolher menu',
                      color: c.fgMuted,
                      onTap: onToggleCollapse!,
                    ),
                ],
              ),
            ),
            if (collapsed && onToggleCollapse != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Center(
                  child: _GhostIconButton(
                    icon: Icons.menu_rounded,
                    tooltip: 'Expandir menu',
                    color: c.fgMuted,
                    onTap: onToggleCollapse!,
                  ),
                ),
              ),
            if (!collapsed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WorkspaceChip(
                  name: me.activeTenant?.name ?? 'Oficina',
                  logoUrl: logoUrl,
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: Text(
                  'MENU',
                  style: TextStyle(
                    color: c.fgMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 14),
                children: [
                  for (var i = 0; i < items.length; i++)
                    _SideNavItem(
                      item: items[i],
                      active: i == selectedIndex,
                      collapsed: collapsed,
                      badge: items[i].route == '/mensagens'
                          ? unreadMessages
                          : 0,
                      onTap: () => onNavigate(items[i].route),
                    ),
                ],
              ),
            ),
            Divider(color: c.line, height: 1),
            if (me.hasMultipleTenants)
              Padding(
                padding: EdgeInsets.fromLTRB(collapsed ? 12 : 14, 10, collapsed ? 12 : 14, 0),
                child: _SideNavItem(
                  item: const NavItem(
                    'Trocar oficina',
                    Icons.swap_horiz_rounded,
                    '/picker',
                  ),
                  active: false,
                  collapsed: collapsed,
                  onTap: () => onNavigate('/picker'),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 14,
                vertical: 8,
              ),
              child: collapsed
                  ? const Center(child: ConnectionChip(collapsed: true))
                  : const Align(
                      alignment: Alignment.centerLeft,
                      child: ConnectionChip(),
                    ),
            ),
            _UserFooter(me: me, collapsed: collapsed),
          ],
          ),
        ),
      ),
    );
  }
}

/// Botão de ícone "fantasma" (sem relevo) para chrome da sidebar escura.
class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({required this.name, this.logoUrl});
  final String name;
  final String? logoUrl;

  void _showLogoDialog(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 320, maxHeight: 240),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _SideColors(context);
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    final avatarBox = hasLogo
        ? GestureDetector(
            onTap: () => _showLogoDialog(context, logoUrl!),
            child: Tooltip(
              message: 'Ver logo',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  logoUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _DefaultAvatar(),
                ),
              ),
            ),
          )
        : const _DefaultAvatar();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.bgHi,
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
        border: Border.all(color: c.line),
        boxShadow: c.raised,
      ),
      child: Row(
        children: [
          avatarBox,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                Text('Workspace',
                    style: TextStyle(color: c.fgMuted, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar();

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [neu.accent, neu.accent.withValues(alpha: .7)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.garage_rounded, size: 19, color: Colors.white),
    );
  }
}

class _SideNavItem extends StatefulWidget {
  const _SideNavItem({
    required this.item,
    required this.active,
    required this.onTap,
    this.collapsed = false,
    this.badge = 0,
  });

  final NavItem item;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;
  final int badge;

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = _SideColors(context);
    final active = widget.active;
    final bg = active
        ? c.accent.withValues(alpha: 0.22)
        : _hover
            ? c.bgHi
            : Colors.transparent;
    final fg = active ? c.fg : c.fgMuted;

    final Widget inner;
    if (widget.collapsed) {
      inner = Stack(
        alignment: Alignment.center,
        children: [
          Icon(widget.item.icon, size: 21, color: fg),
          if (widget.badge > 0)
            Positioned(
              top: 2,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.badge,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );
    } else {
      inner = Row(
        children: [
          Icon(widget.item.icon, size: 19, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (widget.badge > 0)
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.badge,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.badge > 99 ? '99+' : '${widget.badge}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else if (active)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
            ),
        ],
      );
    }

    Widget tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: widget.collapsed ? 48 : null,
            padding: widget.collapsed
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(NeuTokens.rChip),
              boxShadow: active ? c.raised : null,
            ),
            child: inner,
          ),
        ),
      ),
    );

    // No modo colapsado, o rótulo vira tooltip.
    if (widget.collapsed) {
      tile = Tooltip(message: widget.item.label, child: tile);
    }
    return tile;
  }
}

class _UserFooter extends ConsumerWidget {
  const _UserFooter({required this.me, this.collapsed = false});
  final Me me;
  final bool collapsed;

  String get _initials {
    final parts = me.user.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _SideColors(context);
    final avatar = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.bgHi,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Text(
        _initials,
        style: TextStyle(
            color: c.fg, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );

    void logout() =>
        ref.read(sessionControllerProvider.notifier).logout();

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          children: [
            Tooltip(message: '${me.user.fullName} · ${me.role}', child: avatar),
            const SizedBox(height: 10),
            _GhostIconButton(
              icon: Icons.logout_rounded,
              tooltip: 'Sair',
              color: c.fgMuted,
              onTap: logout,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me.user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(me.role,
                    style: TextStyle(color: c.fgMuted, fontSize: 11.5)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sair',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.logout_rounded, size: 19, color: c.fgMuted),
            onPressed: logout,
          ),
        ],
      ),
    );
  }
}
