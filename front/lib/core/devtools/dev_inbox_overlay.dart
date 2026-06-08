import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/navigator_key.dart';
import '../../di.dart';
import 'dev_flag.dart';
import 'dev_inbox_modal.dart';

/// Global top-right controls painted over EVERY screen:
/// - a theme toggle (always) that flips light <-> dark and swaps its icon;
/// - a "beetle" button (only when [kDevTools]) that opens the dev inbox.
///
/// The app [child] is wrapped with `Positioned.fill` so the underlying
/// Navigator/Overlay is laid out with tight constraints (a loose-width wrap was
/// breaking focus traversal and forcing infinite width on focus-heavy screens).
/// The dev modal is opened through the root navigator's overlay context, since
/// this widget sits ABOVE the Navigator (via MaterialApp.builder).
class GlobalOverlay extends ConsumerWidget {
  const GlobalOverlay({super.key, required this.child});

  final Widget child;

  void _openInbox() {
    final ctx = rootNavigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => const DevInboxModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeControllerProvider);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleButton(
                    icon: isDark ? Icons.light_mode : Icons.dark_mode,
                    tooltip: isDark ? 'Tema claro' : 'Tema escuro',
                    bg: scheme.surfaceContainerHighest,
                    fg: scheme.onSurface,
                    onTap: () => ref
                        .read(themeControllerProvider.notifier)
                        .set(isDark ? ThemeMode.light : ThemeMode.dark),
                  ),
                  if (kDevTools) ...[
                    const SizedBox(width: 8),
                    _CircleButton(
                      icon: Icons.bug_report,
                      tooltip: 'Dev inbox',
                      bg: scheme.primary,
                      fg: scheme.onPrimary,
                      onTap: _openInbox,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // NB: no Tooltip here — this widget is painted ABOVE the Navigator (via
    // MaterialApp.builder), so there is no Overlay ancestor for a Tooltip to use.
    return Semantics(
      label: tooltip,
      button: true,
      child: Material(
        color: bg,
        elevation: 3,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}
