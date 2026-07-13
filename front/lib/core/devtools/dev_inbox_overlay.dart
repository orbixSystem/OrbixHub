import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
import '../router/navigator_key.dart';
import '../../di.dart';
import '../../features/auth/presentation/session_state.dart';
import '../../features/notifications/presentation/notifications_bell.dart';
import 'dev_flag.dart';
import 'dev_inbox_modal.dart';

/// `true` quando estamos na página PÚBLICA de acompanhamento (`/t/:token`). O
/// cliente não pode ver NENHUM chrome de staff (sino, toggle de tema, besouro).
bool _isPublicTrackingRoute(WidgetRef ref) {
  final path = ref
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;
  return path.startsWith('/t/');
}

/// Global top-right controls, inserted as an [OverlayEntry] into the root
/// Navigator's overlay (NOT by wrapping the app in a Stack — that broke web
/// focus traversal and left an unlaid-out `_RenderTheater`). Shows a theme
/// toggle (always) and, only when [kDevTools], a "beetle" dev-inbox button.
class GlobalControls extends ConsumerWidget {
  const GlobalControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // O routerDelegate é um ChangeNotifier — rebuilda a cada navegação para que
    // o chrome de staff suma na rota pública `/t/:token`.
    return ListenableBuilder(
      listenable: ref.read(routerProvider).routerDelegate,
      builder: (context, _) {
        if (_isPublicTrackingRoute(ref)) return const SizedBox.shrink();
        return _buildControls(context, ref);
      },
    );
  }

  Widget _buildControls(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeControllerProvider);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    // Topo-direita: sino de notificações (só quando logado) + toggle de tema,
    // LADO A LADO num Row — antes o toggle (overlay) cobria o sino (header).
    // O "besouro" (dev inbox) fica no canto inferior-direito ([DevBeetleControl]).
    final authed = ref.watch(sessionControllerProvider).isSignedIn;
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (authed) ...[
                const NotificationsBell(),
                const SizedBox(width: 8),
              ],
              _CircleButton(
                icon: isDark ? Icons.light_mode : Icons.dark_mode,
                label: isDark ? 'Tema claro' : 'Tema escuro',
                bg: scheme.surfaceContainerHighest,
                fg: scheme.onSurface,
                onTap: () => ref
                    .read(themeControllerProvider.notifier)
                    .set(isDark ? ThemeMode.light : ThemeMode.dark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O botão "besouro" do dev inbox, inserido como [OverlayEntry] próprio no canto
/// **inferior-direito** (longe do sino de notificações do header). Visível só
/// quando [kDevTools]. Mantém clique/posicionamento como antes — só mudou o
/// canto. Como cada filho do overlay é um [Positioned], não bloqueia o input.
class DevBeetleControl extends ConsumerWidget {
  const DevBeetleControl({super.key});

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
    if (!kDevTools) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: ref.read(routerProvider).routerDelegate,
      builder: (context, _) {
        if (_isPublicTrackingRoute(ref)) return const SizedBox.shrink();
        return _buildBeetle(context, ref);
      },
    );
  }

  Widget _buildBeetle(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      right: 16,
      bottom: 16,
      child: SafeArea(
        child: _CircleButton(
          icon: Icons.bug_report,
          label: 'Dev inbox',
          bg: scheme.primary,
          fg: scheme.onPrimary,
          onTap: _openInbox,
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
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
