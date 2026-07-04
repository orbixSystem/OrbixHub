import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import '../../messages/presentation/messages_providers.dart';
import 'nav_items.dart';

/// Cores da sidebar derivadas dos tokens neumórficos: painel navy no tema
/// claro (bloco de contraste, como na referência visual); painel escuro
/// levemente distinto do fundo no tema escuro.
class _SideColors {
  _SideColors(BuildContext context)
      : _neu = context.neu,
        _light = Theme.of(context).brightness == Brightness.light;

  final NeuTokens _neu;
  final bool _light;

  Color get bg => _light ? _neu.navy : const Color(0xFF222639);
  Color get bgHi => _light ? _neu.navyHover : _neu.surfaceHi;
  Color get line => _light ? const Color(0xFF3D4360) : _neu.line;
  Color get fg => _light ? _neu.onNavy : _neu.ink;
  Color get fgMuted => _light ? _neu.onNavyMuted : _neu.inkMuted;
  Color get accent => _neu.accent;
  Color get badge => _neu.danger;
}

/// The navy navigation sidebar content, shared by the persistent desktop
/// sidebar and the tablet drawer. Bounded layout (Column + Expanded list) — no
/// unbounded-constraint traps.
class SidebarContent extends ConsumerWidget {
  const SidebarContent({
    super.key,
    required this.me,
    required this.items,
    required this.selectedIndex,
    required this.onNavigate,
  });

  final Me me;
  final List<NavItem> items;
  final int selectedIndex;
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _SideColors(context);
    // Badge ao vivo no item Mensagens (soma de não-lidos do staff).
    final unreadMessages = ref.watch(unreadConversationsCountProvider);
    // Logo do tenant para o workspace chip.
    final logoUrl = ref
        .watch(settingsControllerProvider)
        .whenOrNull(data: (b) => b.company['logoUrl'] as String?);
    return Container(
      width: 272,
      color: c.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Topo: sempre o wordmark/glifo do OrbixHub.
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 24, 22, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BrandMark(size: 26, onDark: true),
              ),
            ),
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (var i = 0; i < items.length; i++)
                    _SideNavItem(
                      item: items[i],
                      active: i == selectedIndex,
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
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: _SideNavItem(
                  item: const NavItem(
                    'Trocar oficina',
                    Icons.swap_horiz_rounded,
                    '/picker',
                  ),
                  active: false,
                  onTap: () => onNavigate('/picker'),
                ),
              ),
            _UserFooter(me: me),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({required this.name, this.logoUrl});
  final String name;
  final String? logoUrl;

  /// Abre dialog ampliado com a logo do cliente.
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
                constraints: const BoxConstraints(
                  maxWidth: 320,
                  maxHeight: 240,
                ),
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
                Text(
                  'Workspace',
                  style: TextStyle(color: c.fgMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar genérico quando não há logo cadastrada.
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
    this.badge = 0,
  });

  final NavItem item;
  final bool active;
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(NeuTokens.rChip),
            ),
            child: Row(
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
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserFooter extends ConsumerWidget {
  const _UserFooter({required this.me});
  final Me me;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      child: Row(
        children: [
          Container(
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
                color: c.fg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
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
                Text(
                  me.role,
                  style: TextStyle(color: c.fgMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sair',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.logout_rounded, size: 19, color: c.fgMuted),
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
