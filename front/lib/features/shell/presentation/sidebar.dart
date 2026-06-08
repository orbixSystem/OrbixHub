import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import 'nav_items.dart';

/// The graphite navigation rail content, shared by the persistent desktop
/// sidebar and the mobile drawer. Bounded layout (Column + Expanded list) — no
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
    return Container(
      width: 272,
      color: AppColors.graphite,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BrandMark(size: 26, onDark: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _WorkspaceChip(name: me.activeTenant?.name ?? 'Oficina'),
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: Text(
                'MENU',
                style: TextStyle(
                  color: AppColors.onGraphiteMuted,
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
                      onTap: () => onNavigate(items[i].route),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.graphiteLine, height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _ThemeToggle(),
            ),
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
  const _WorkspaceChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.graphiteHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.graphiteLine),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandBright, AppColors.brandDeep],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.garage_rounded,
                size: 17, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onGraphite,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const Text(
                  'Workspace',
                  style: TextStyle(
                    color: AppColors.onGraphiteMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatefulWidget {
  const _SideNavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final bg = active
        ? AppColors.brand.withValues(alpha: 0.16)
        : _hover
            ? AppColors.graphiteHi
            : Colors.transparent;
    final fg = active ? AppColors.brandBright : AppColors.onGraphiteMuted;

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
              borderRadius: BorderRadius.circular(11),
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
                      color: active ? AppColors.onGraphite : fg,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
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

/// Compact light/dark/system theme selector for the sidebar footer. Reads the
/// current mode and writes via [themeControllerProvider]. Styled for the
/// graphite rail (legible on dark), the segments use on-graphite tones.
class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    final notifier = ref.read(themeControllerProvider.notifier);

    Widget segment(ThemeMode value, IconData icon, String tooltip) {
      final selected = mode == value;
      return Expanded(
        child: Tooltip(
          message: tooltip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => notifier.set(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brand.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color:
                    selected ? AppColors.brandBright : AppColors.onGraphiteMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.graphiteHi,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.graphiteLine),
      ),
      child: Row(
        children: [
          segment(ThemeMode.light, Icons.light_mode_outlined, 'Claro'),
          segment(ThemeMode.dark, Icons.dark_mode_outlined, 'Escuro'),
          segment(ThemeMode.system, Icons.brightness_auto_outlined, 'Sistema'),
        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.graphiteHi,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.graphiteLine),
            ),
            child: Text(
              _initials,
              style: const TextStyle(
                color: AppColors.onGraphite,
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
                  style: const TextStyle(
                    color: AppColors.onGraphite,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  me.role,
                  style: const TextStyle(
                    color: AppColors.onGraphiteMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sair',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.logout_rounded,
                size: 19, color: AppColors.onGraphiteMuted),
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
