import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
import '../router/navigator_key.dart';
import '../../di.dart';
import '../../features/auth/presentation/session_state.dart';
import '../../features/notifications/presentation/notifications_bell.dart';
import '../ui/ui.dart';
import '../../features/shell/presentation/screen_tutorials.dart';
import '../../features/support/presentation/support_button.dart';
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
        // Esconde enquanto um modal (diálogo/sheet) estiver aberto — como este
        // chrome vive no topo do overlay do root navigator, senão flutuaria
        // acima da barreira do modal.
        return ValueListenableBuilder<int>(
          valueListenable: modalRouteObserver.depth,
          builder: (context, modals, _) => ValueListenableBuilder<bool>(
            // Tutorial ativo esconde este chrome pelo MESMO motivo que um modal:
            // ele vive acima de tudo e cobriria o cartão do tutorial.
            valueListenable: CoachMark.ativo,
            builder: (context, tutorial, _) => modals > 0 || tutorial
                ? const SizedBox.shrink()
                : _buildControls(context, ref),
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeControllerProvider);
    final isDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    // Topo-direita: sino de notificações (só quando logado) + toggle de tema,
    // LADO A LADO num Row — antes o toggle (overlay) cobria o sino (header).
    // O "besouro" (dev inbox) fica no canto inferior-direito ([DevBeetleControl]).
    final authed = ref.watch(sessionControllerProvider).isSignedIn;
    // No CELULAR o grupo da direita já é longo (sino + sair + tema) e crescia por
    // cima do "+", que é centralizado no berço do header. Lá o "?" do tutorial
    // muda de lado: fica espelhado, do outro lado do "+", com o mesmo tratamento
    // do sino. No desktop/tablet sobra espaço e agrupar a ajuda com o sino lê
    // melhor — então continua junto.
    final isMobile = context.isMobile;
    final direita = Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (authed) ...[
                // "?" do tutorial À ESQUERDA do sino: ajuda mora sempre no mesmo
                // canto, em todas as telas, em vez de um botão diferente por
                // tela. Some sozinho onde a rota não tem tutorial.
                if (!isMobile) ...[
                  const _BotaoTutorial(),
                  // Suporte ao lado do sino: as duas coisas que CHEGAM até você
                  // ficam juntas, no mesmo canto. No CELULAR ele muda de lado
                  // (vai com o "?", à esquerda do "+") — quatro botões deste
                  // lado passariam por cima do "+".
                  const SupportButton(),
                ],
                const NotificationsBell(),
                const SizedBox(width: 8),
                // Sair só aparece no CELULAR: lá não há sidebar nem drawer
                // (a navegação é a barra de baixo), então este era o único
                // lugar sem saída para encerrar a sessão. No desktop/tablet o
                // botão já existe no rodapé da sidebar — duplicar poluiria.
                if (context.isMobile) ...[
                  _CircleButton(
                    icon: Icons.logout_rounded,
                    label: 'Sair',
                    bg: scheme.surfaceContainerHighest,
                    fg: scheme.onSurface,
                    onTap: () => _confirmLogout(context, ref),
                  ),
                  const SizedBox(width: 8),
                ],
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
    if (!isMobile || !authed) return direita;
    return Stack(
      children: [
        direita,
        // Espelho do sino, do outro lado do "+". O header reserva este canto no
        // mobile (ver `_ContentHeader`) para o chip de conexão não vir para cá.
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 8),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // No celular a ajuda mora toda deste lado: o "?" da tela e o
                  // suporte da Orbix, um ao lado do outro.
                  _BotaoTutorial(),
                  SupportButton(),
                ],
              ),
            ),
          ),
        ),
      ],
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
        return ValueListenableBuilder<int>(
          valueListenable: modalRouteObserver.depth,
          builder: (context, modals, _) =>
              modals > 0 ? const SizedBox.shrink() : _buildBeetle(context, ref),
        );
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

/// Confirma antes de encerrar a sessão: o botão fica no topo da tela, ao lado
/// do sino, e um toque acidental derrubaria o trabalho em andamento.
Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final ok = await showNeuConfirm(
    context,
    title: 'Sair da conta?',
    message: 'Você precisará entrar de novo para continuar usando o OrbixHub.',
    confirmLabel: 'Sair',
  );
  if (ok) await ref.read(sessionControllerProvider.notifier).logout();
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

/// "?" que reabre o tutorial da tela atual, ignorando o "já visto" — quem
/// esqueceu como o fiado funciona não deveria ter de limpar dados do app.
///
/// Vive no chrome global (e não em cada tela) para a ajuda ficar sempre no mesmo
/// lugar, em desktop e mobile.
class _BotaoTutorial extends ConsumerWidget {
  const _BotaoTutorial();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delegate = ref.read(routerProvider).routerDelegate;
    // `ListenableBuilder` no delegate: sem ele o botão guardava o tutorial da
    // PRIMEIRA rota em que foi construído. Como o widget é `const`, o rebuild do
    // pai não o alcançava — então numa tela sem tutorial ele continuava
    // oferecendo o tutorial anterior, e navegar não trocava o conteúdo.
    return ListenableBuilder(
      listenable: delegate,
      builder: (context, _) {
        final tut = tutorialForRoute(delegate.currentConfiguration.uri.path);
        // Tela sem tutorial: o botão SOME (não mostra o de outra tela).
        if (tut == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          // Folga à direita para separar do vizinho (o suporte, e depois o sino).
          padding: const EdgeInsets.only(right: 8),
          child: _CircleButton(
            icon: Icons.help_outline_rounded,
            label: 'Como funciona: ${tut.titulo}',
            bg: scheme.surfaceContainerHighest,
            fg: scheme.onSurface,
            onTap: () => CoachMark.start(context, id: tut.id, steps: tut.steps),
          ),
        );
      },
    );
  }
}
