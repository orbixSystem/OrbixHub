import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/notifications_models.dart';
import 'notifications_providers.dart';

/// Sino de notificações para a barra superior do AppShell: badge tangerina com
/// a contagem de não-lidas (some quando 0), ícone destacado quando há não-lidas,
/// um menu suspenso com as recentes, e um toast quando o não-lido aumenta.
class NotificationsBell extends ConsumerStatefulWidget {
  const NotificationsBell({super.key});

  @override
  ConsumerState<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends ConsumerState<NotificationsBell> {
  int? _lastUnread;

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider);

    // Toast só no AUMENTO do não-lido (não-spammy). Agendado fora do build.
    if (_lastUnread != null && unread > _lastUnread!) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toast());
    }
    _lastUnread = unread;

    final hasUnread = unread > 0;
    final color = hasUnread ? AppColors.brand : null;

    return Stack(
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
          onPressed: _openPanel,
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
    );
  }

  void _toast() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nova mensagem do cliente'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openPanel() async {
    // Atualiza ao abrir.
    unawaited(ref.read(notificationsProvider.notifier).refresh());
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final button = context.findRenderObject() as RenderBox?;
    if (overlay == null || button == null) return;
    final topRight = button.localToGlobal(
      button.size.topRight(Offset.zero),
      ancestor: overlay,
    );
    final position = RelativeRect.fromLTRB(
      topRight.dx - 360,
      topRight.dy + 8,
      overlay.size.width - topRight.dx,
      0,
    );

    final selected = await showMenu<_PanelAction>(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 360, maxWidth: 360),
      items: [
        PopupMenuItem<_PanelAction>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 360,
            child: _PanelContent(
              onTapItem: (n) =>
                  Navigator.of(context).pop(_PanelAction.open(n)),
              onMarkAll: () =>
                  Navigator.of(context).pop(const _PanelAction.markAll()),
            ),
          ),
        ),
      ],
    );

    if (selected == null || !mounted) return;
    await selected.when(
      open: (n) async {
        await ref.read(notificationsProvider.notifier).markRead(n.id);
        if (!mounted) return;
        if (n.refType == 'message' && (n.refId?.isNotEmpty ?? false)) {
          context.go('/mensagens/${n.refId}');
        }
      },
      markAll: () => ref.read(notificationsProvider.notifier).markAllRead(),
    );
  }
}

/// Ação selecionada no painel (selado, à mão — sem freezed para um helper local).
class _PanelAction {
  const _PanelAction.open(this.notification) : _isMarkAll = false;
  const _PanelAction.markAll()
      : notification = null,
        _isMarkAll = true;

  final AppNotification? notification;
  final bool _isMarkAll;

  Future<void> when({
    required Future<void> Function(AppNotification n) open,
    required Future<void> Function() markAll,
  }) {
    if (_isMarkAll) return markAll();
    return open(notification!);
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text('Notificações',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: onMarkAll,
                  child: const Text('Marcar todas como lidas'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Não foi possível carregar.'),
              ),
              data: (r) {
                if (r.items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhuma notificação.'),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: r.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? AppColors.brandTint.withValues(alpha: 0.4) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: unread ? AppColors.brand : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title.isEmpty ? 'Notificação' : n.title,
                    style: TextStyle(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  if (n.body != null && n.body!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    relativeTime(n.createdAt),
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
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
