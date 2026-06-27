import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/notification_sound.dart';
import '../../../core/realtime/realtime_chat.dart';
import '../../../core/router/navigator_key.dart';
import '../../../core/theme/app_colors.dart';
import '../../../di.dart';
import '../../messages/presentation/messages_providers.dart';
import '../domain/notifications_models.dart';
import 'notifications_providers.dart';

/// Sino de notificações para a barra superior do AppShell: badge tangerina com
/// a contagem de não-lidas (some quando 0), ícone destacado quando há não-lidas,
/// um painel suspenso com as recentes, e um toast no canto superior direito
/// quando o não-lido aumenta.
///
/// O painel usa [OverlayPortal] + um barrier próprio (não [showMenu]): o sino
/// vive num [OverlayEntry] inserido no topo do overlay raiz, então o barrier do
/// `showMenu` ficava ABAIXO do sino e clicar nele de novo reabria o menu em vez
/// de fechar. Com barrier próprio, qualquer clique fora — inclusive no sino —
/// fecha o painel.
class NotificationsBell extends ConsumerStatefulWidget {
  const NotificationsBell({super.key});

  @override
  ConsumerState<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends ConsumerState<NotificationsBell> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  int? _lastUnread;
  final RealtimeChat _rt = RealtimeChat();

  @override
  void initState() {
    super.initState();
    // O sino vive no shell autenticado: assina a sala do tenant (WebSocket) e,
    // a cada mensagem nova em qualquer conversa, atualiza as notificações na hora.
    // Como o não-lido sobe, o bloco do build dispara o toast + o som — em
    // qualquer tela do app, não só na de Mensagens.
    final accessToken = ref.read(accessTokenStoreProvider).token;
    if (accessToken != null) {
      _rt.connectStaff(
        accessToken: accessToken,
        onMessage: (_) {
          if (mounted) {
            unawaited(ref.read(notificationsProvider.notifier).refresh());
            // Push instantâneo do WS: recarrega a lista que alimenta o badge de
            // Mensagens na hora. É um dos DOIS gatilhos — o outro (no build, ao
            // subir o não-lido) cobre o poll de 15s caso o WS não entregue.
            ref.invalidate(conversationsProvider);
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _rt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider);

    // Toast + som só no AUMENTO do não-lido (não-spammy). Agendado fora do build.
    if (_lastUnread != null && unread > _lastUnread!) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toast();
        unawaited(NotificationSound.play());
        // Mesmo sinal do toast: chegou algo novo. Recarrega a lista de conversas
        // que alimenta o badge de Mensagens da sidebar, em QUALQUER tela. O sino é
        // o único ouvinte sempre montado, e este gatilho cobre tanto o push do WS
        // quanto o poll de 15s — sem isto o badge só atualizava após F5.
        if (mounted) ref.invalidate(conversationsProvider);
      });
    }
    _lastUnread = unread;

    final hasUnread = unread > 0;
    final color = hasUnread ? AppColors.brand : null;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildPanelOverlay,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notificações',
              icon: Icon(
                hasUnread
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: color,
              ),
              onPressed: _togglePanel,
            ),
            if (hasUnread)
              Positioned(
                right: 4,
                top: 4,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Alterna o painel. Quando aberto, o barrier cobre tudo (inclusive o sino),
  /// então o caminho de fechar passa por [_buildPanelOverlay]; este toggle cobre
  /// o caso de o painel estar fechado (e o re-clique programático, por garantia).
  void _togglePanel() {
    if (_portal.isShowing) {
      _portal.hide();
      return;
    }
    // Atualiza ao abrir.
    unawaited(ref.read(notificationsProvider.notifier).refresh());
    _portal.show();
  }

  Widget _buildPanelOverlay(BuildContext context) {
    return Stack(
      children: [
        // Barrier transparente em tela cheia: qualquer clique fora fecha.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _portal.hide,
          ),
        ),
        // Painel ancorado logo abaixo do sino, alinhado à direita dele.
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: Material(
            // Cor de superfície explícita + borda: em tema escuro o `surface`
            // default do painel se confundia com o fundo da tela. O container
            // elevado com contorno destaca o painel em ambos os temas.
            elevation: 12,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: 360,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: _PanelContent(
                onTapItem: _onTapItem,
                onMarkAll: () =>
                    ref.read(notificationsProvider.notifier).markAllRead(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onTapItem(AppNotification n) async {
    _portal.hide();
    await ref.read(notificationsProvider.notifier).markRead(n.id);
    if (!mounted) return;
    if (n.refType == 'message' && (n.refId?.isNotEmpty ?? false)) {
      context.go('/mensagens/${n.refId}');
    } else if (n.type == 'inventory_low_stock') {
      context.go('/m/inventory');
    }
  }

  /// Toast no canto superior direito (largura limitada — não ocupa a tela toda),
  /// inserido no overlay raiz, anima entrada/saída e some sozinho. Usa o título
  /// da notificação mais recente (que já carrega o nome do cliente) e o texto da
  /// mensagem como subtítulo.
  void _toast() {
    if (!mounted) return;
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    final latest = ref.read(notificationsProvider).maybeWhen(
          data: (r) => r.items.isNotEmpty ? r.items.first : null,
          orElse: () => null,
        );
    final title = (latest?.title.trim().isNotEmpty ?? false)
        ? latest!.title.trim()
        : 'Nova mensagem do cliente';
    final body = latest?.body?.trim();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NotificationToast(
        message: title,
        body: (body != null && body.isNotEmpty) ? body : null,
        onDismissed: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _PanelContent extends ConsumerWidget {
  const _PanelContent({required this.onTapItem, required this.onMarkAll});

  final void Function(AppNotification) onTapItem;
  final VoidCallback onMarkAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final unread = async.maybeWhen(data: (r) => r.unread, orElse: () => 0);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 440),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Text('Notificações',
                    style: Theme.of(context).textTheme.titleMedium),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: unread > 0 ? onMarkAll : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Marcar todas como lidas'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Flexible(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Text('Não foi possível carregar.',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
              ),
              data: (r) {
                if (r.items.isEmpty) {
                  return _EmptyState(scheme: scheme);
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: r.items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: scheme.outlineVariant),
                  itemBuilder: (_, i) => _NotificationRow(
                    notification: r.items[i],
                    onTap: () => onTapItem(r.items[i]),
                    scheme: scheme,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vazio do painel: ícone discreto + texto centralizado.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            'Nenhuma notificação por aqui.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
    required this.scheme,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.isRead;
    final isMessage = n.type == 'message' || n.refType == 'message';
    final isLowStock = n.type == 'inventory_low_stock';
    final iconData = isMessage
        ? Icons.chat_bubble_outline_rounded
        : isLowStock
            ? Icons.inventory_2_outlined
            : Icons.notifications_none_rounded;
    // Realce do não-lido adaptado ao tema (a wash de marca clara some no escuro):
    // um leve banho do tom de marca por cima da superfície atual.
    final highlight =
        unread ? AppColors.brand.withValues(alpha: 0.10) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: highlight,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de acento à esquerda só no não-lido.
              Container(
                width: 3,
                color: unread ? AppColors.brand : Colors.transparent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar com ícone da origem.
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: unread
                              ? AppColors.brand.withValues(alpha: 0.16)
                              : scheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          iconData,
                          size: 18,
                          color: unread
                              ? AppColors.brand
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title.isEmpty ? 'Notificação' : n.title,
                                    style: TextStyle(
                                      fontWeight: unread
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 13.5,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (unread)
                                  Container(
                                    margin: const EdgeInsets.only(top: 5, left: 6),
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.brand,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            if (n.body != null && n.body!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                n.body!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12.5,
                                    height: 1.25),
                              ),
                            ],
                            const SizedBox(height: 5),
                            Text(
                              relativeTime(n.createdAt),
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.85),
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toast compacto (canto superior direito), com slide+fade de entrada/saída e
/// auto-dismiss. Largura limitada a 320 — ocupa só um pedaço da tela.
class _NotificationToast extends StatefulWidget {
  const _NotificationToast({
    required this.message,
    this.body,
    required this.onDismissed,
  });

  final String message;
  final String? body;
  final VoidCallback onDismissed;

  @override
  State<_NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends State<_NotificationToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide =
      Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(_fade);
  Timer? _dismissTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _dismissTimer?.cancel();
    if (mounted) await _c.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        // Abaixo do sino/toggle (que vivem em top:8, ~48 de altura).
        child: Padding(
          padding: const EdgeInsets.only(top: 64, right: 12),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _dismiss,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: scheme.inverseSurface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notifications_active_rounded,
                              size: 18, color: scheme.onInverseSurface),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: scheme.onInverseSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                if (widget.body != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.body!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: scheme.onInverseSurface
                                          .withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tempo relativo curto em PT-BR a partir de um ISO-8601 ("agora", "5 min",
/// "3 h", "2 d"). Falha/null → "".
String relativeTime(String? iso) {
  if (iso == null) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  return '${diff.inDays} d';
}
