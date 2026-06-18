import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/messages_models.dart';
import 'messages_providers.dart';

/// Inbox do staff: lista de conversas (título + prévia da última mensagem +
/// bolha de não-lidos). Tocar abre o thread. Corpo apenas — moldura é do shell.
class MessagesInboxScreen extends ConsumerWidget {
  const MessagesInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsProvider);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is AppException ? e.message : 'Erro ao carregar conversas.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => ref.invalidate(conversationsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Nenhuma conversa ainda.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _ConversationTile(conversation: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = conversation.staffUnread;
    final title = (conversation.title?.trim().isNotEmpty ?? false)
        ? conversation.title!
        : 'Conversa';
    final preview = conversation.lastMessage;

    return InkWell(
      onTap: () => context.go('/mensagens/${conversation.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.forum_outlined,
                  color: AppColors.brandDeep, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          unread > 0 ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                  if (preview != null && preview.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight:
                            unread > 0 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 10),
              _UnreadBubble(count: unread),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Bolha tangerina com a contagem de não-lidos (>99 vira "99+").
class _UnreadBubble extends StatelessWidget {
  const _UnreadBubble({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
