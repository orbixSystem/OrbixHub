import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/realtime/realtime_chat.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/read_ticks.dart';
import '../../../di.dart';
import '../domain/messages_models.dart';
import 'messages_providers.dart';

/// Inbox do staff: lista de conversas (título + prévia da última mensagem +
/// bolha de não-lidos). Tocar abre o thread. Corpo apenas — moldura é do shell.
///
/// Pagina por INFINITE SCROLL nos dois layouts (exceção consciente ao molde:
/// inbox tem semântica de chat — o usuário espera rolar, não paginar).
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
    // A LISTA de conversas é lida do cache local (SQLite) offline; só o ENVIO de
    // mensagem (na tela do thread) exige conexão. O tempo real, quando há rede,
    // segue atualizando os badges/prévia.
    final async = ref.watch(conversationsProvider);
    final queryNotifier = ref.read(conversationQueryProvider.notifier);
    final isMobile = context.isMobile;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: isMobile ? double.infinity : 420),
              child: NeuSearchBar(
                hint: 'Buscar conversa',
                controller: _search,
                onChanged: queryNotifier.setQuery,
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                    NeuButton(
                      label: 'Tentar de novo',
                      kind: NeuButtonKind.secondary,
                      icon: Icons.refresh,
                      onPressed: () => ref.invalidate(conversationsProvider),
                    ),
                  ],
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const NeuEmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Nenhuma conversa ainda',
                    message:
                        'Quando um cliente mandar mensagem pelo link de acompanhamento da OS, a conversa aparece aqui.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(conversationsProvider),
                  // +1 slot para o rodapé (loader do próximo lote / fim).
                  child: ListView.separated(
                    controller: _scroll,
                    itemCount: page.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i >= page.items.length) {
                        return NeuListFooter(
                          loading: page.loadingMore,
                          hasMore: page.hasMore,
                          total: page.total,
                        );
                      }
                      return _ConversationTile(conversation: page.items[i]);
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
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
    final showTicks =
        hasPreview && showTicksFor(conversation.lastMessageSender);
    // Avatar colorido estável pela inicial do nome.
    final initial = name.characters.first.toUpperCase();
    final color = neu.glyphs[initial.codeUnitAt(0) % neu.glyphs.length];

    return NeuListTile(
      onTap: () => context.go('/mensagens/${conversation.id}'),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
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
                  color: neu.inkMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: hasPreview
          ? Row(
              children: [
                if (showTicks) ...[
                  ReadTicks(read: conversation.lastMessageRead),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  // Prévia em 1 linha com reticências; o texto completo fica no
                  // tooltip para ler mensagens longas sem abrir a conversa.
                  child: Tooltip(
                    message: preview,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neu.inkMuted,
                        fontSize: 13,
                        fontWeight:
                            unread > 0 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (time.isNotEmpty)
            Text(
              time,
              style: TextStyle(
                color: unread > 0 ? neu.accent : neu.inkMuted,
                fontSize: 11.5,
                fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            NeuBadge(count: unread),
          ],
        ],
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
