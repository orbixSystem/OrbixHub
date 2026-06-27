import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/realtime/realtime_chat.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/read_ticks.dart';
import '../../../di.dart';
import '../domain/messages_models.dart';
import 'messages_providers.dart';

/// Inbox do staff: lista de conversas (título + prévia da última mensagem +
/// bolha de não-lidos). Tocar abre o thread. Corpo apenas — moldura é do shell.
///
/// Em tempo real: assina a sala do tenant (WebSocket); a cada mensagem nova em
/// qualquer conversa, recarrega a lista (badges/prévia atualizam na hora).
class MessagesInboxScreen extends ConsumerStatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  ConsumerState<MessagesInboxScreen> createState() =>
      _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends ConsumerState<MessagesInboxScreen> {
  final RealtimeChat _rt = RealtimeChat();
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final accessToken = ref.read(accessTokenStoreProvider).token;
    if (accessToken != null) {
      _rt.connectStaff(
        accessToken: accessToken,
        onMessage: (_) {
          if (mounted) ref.invalidate(conversationsProvider);
        },
      );
    }
  }

  @override
  void dispose() {
    _rt.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Dispara o próximo lote ao chegar perto do fim do scroll (300px antes do
  /// fundo) — o notifier ignora chamadas redundantes.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(conversationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationsProvider);
    final queryNotifier = ref.read(conversationQueryProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: 'Buscar conversa',
            ),
            onChanged: queryNotifier.setQuery,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e is AppException
                        ? e.message
                        : 'Erro ao carregar conversas.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40)),
                      onPressed: () => ref.invalidate(conversationsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tentar de novo'),
                    ),
                  ],
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const Center(child: Text('Nenhuma conversa ainda.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(conversationsProvider),
                  // +1 slot para o rodapé (loader do próximo lote / fim da lista).
                  child: ListView.separated(
                    controller: _scroll,
                    itemCount: page.items.length + 1,
                    separatorBuilder: (_, i) => i >= page.items.length - 1
                        ? const SizedBox.shrink()
                        : const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (i < page.items.length) {
                        return _ConversationTile(conversation: page.items[i]);
                      }
                      return _ListFooter(
                        loadingMore: page.loadingMore,
                        hasMore: page.hasMore,
                        total: page.total,
                      );
                    },
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

/// Rodapé da lista: spinner enquanto busca o próximo lote; convite a rolar quando
/// há mais; contagem total quando tudo foi carregado.
class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.loadingMore,
    required this.hasMore,
    required this.total,
  });

  final bool loadingMore;
  final bool hasMore;
  final int total;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13,
    );
    final Widget child;
    if (loadingMore) {
      child = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (hasMore) {
      child = Text('Role para carregar mais', style: style);
    } else {
      child = Text(
        '$total ${total == 1 ? 'conversa' : 'conversas'} no total',
        style: style,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(child: child),
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
    final name = (conversation.title?.trim().isNotEmpty ?? false)
        ? conversation.title!.trim()
        : 'Conversa';
    // Rótulo da origem (ex.: 'OS-0001') — distingue clientes de mesmo nome.
    final refLabel = conversation.refLabel?.trim();
    final preview = conversation.lastMessage;
    final hasPreview = preview != null && preview.trim().isNotEmpty;
    final time = _hhmm(conversation.lastMessageAt);
    // Tracinhos só na prévia quando a última mensagem é resposta do staff.
    final showTicks = hasPreview && showTicksFor(conversation.lastMessageSender);

    return InkWell(
      onTap: () => context.go('/mensagens/${conversation.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: unread > 0
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (refLabel != null && refLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '· $refLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: TextStyle(
                            color: unread > 0
                                ? AppColors.brand
                                : scheme.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight:
                                unread > 0 ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasPreview) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (showTicks) ...[
                          ReadTicks(read: conversation.lastMessageRead),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          // Prévia em 1 linha com reticências; o texto completo
                          // fica no tooltip (passar o mouse / segurar) para o
                          // usuário poder ler mensagens longas sem abrir a conversa.
                          child: Tooltip(
                            message: preview,
                            waitDuration: const Duration(milliseconds: 400),
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ],
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

/// Formata um ISO-8601 em "HH:mm" (hora local). Falha/nulo → string vazia.
String _hhmm(String? iso) {
  if (iso == null) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
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
