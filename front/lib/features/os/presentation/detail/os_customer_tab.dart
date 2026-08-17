import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/ui/ui.dart';
import '../../../messages/domain/messages_models.dart';
import '../../domain/os_models.dart';
import '../os_providers.dart';
import '../tracking_link_share.dart';
import 'os_detail_shared.dart';

/// Aba **Cliente**: os dois canais com quem está do outro lado — a conversa da
/// OS e o link público de acompanhamento.
class OsCustomerTab extends StatelessWidget {
  const OsCustomerTab({super.key, required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context) {
    final conversationId = order.conversationId;
    final token = order.publicToken;
    final temConversa = conversationId != null && conversationId.isNotEmpty;
    final temTracking = token != null && token.isNotEmpty;
    if (!temConversa && !temTracking) {
      return const OsInlineEmpty(
        icon: Icons.person_outline,
        text: 'Nada para o cliente ainda.',
        hint: 'A conversa e o link de acompanhamento aparecem aqui.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (temConversa) _MessagesSection(conversationId: conversationId),
        if (temConversa && temTracking) const SizedBox(height: 20),
        if (temTracking) _TrackingLinkCard(order: order),
      ],
    );
  }
}

// ===================== Mensagens da OS (prévia) =====================

/// Caixinha compacta com as últimas mensagens DESTA OS (cliente ↔ equipe).
/// Prévia somente-leitura: usa `before` no futuro para NÃO zerar o contador de
/// não-lidas do inbox; a conversa completa abre em /mensagens/:id.
class _MessagesSection extends ConsumerWidget {
  const _MessagesSection({required this.conversationId});

  final String conversationId;

  void _open(BuildContext context) => context.go('/mensagens/$conversationId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final async = ref.watch(osConversationPreviewProvider(conversationId));
    return OsSectionCard(
      icon: Icons.forum_rounded,
      title: 'Mensagens',
      glyphIndex: 1,
      action: OsHeaderAction(
        icon: Icons.open_in_new_rounded,
        label: 'Abrir',
        onTap: () => _open(context),
      ),
      child: async.when(
        skipLoadingOnReload: true,
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
        error: (e, _) => Text(
          e is AppException ? e.message : 'Erro ao carregar as mensagens.',
          style: TextStyle(color: neu.inkMuted, fontSize: 13, height: 1.35),
        ),
        data: (thread) {
          final unread = thread.conversation.staffUnread;
          final messages = thread.messages;
          if (messages.isEmpty) {
            return Text(
              'Nenhuma mensagem ainda. O cliente pode escrever pelo link de '
              'acompanhamento — a conversa aparece aqui.',
              style: TextStyle(color: neu.inkMuted, fontSize: 13, height: 1.35),
            );
          }
          // As 3 mais recentes (a página vem em ordem cronológica).
          final recent = messages.length > 3
              ? messages.sublist(messages.length - 3)
              : messages;
          final older = thread.hasMore
              ? '${messages.length}+'
              : '${messages.length}';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (unread > 0) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: NeuStatusChip(
                    label: unread == 1
                        ? '1 mensagem não lida'
                        : '$unread mensagens não lidas',
                    color: neu.accent,
                    tint: neu.accentTint,
                    icon: Icons.mark_chat_unread_outlined,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _MessagePreviewTile(
                  message: recent[i],
                  onTap: () => _open(context),
                ),
              ],
              if (messages.length > recent.length || thread.hasMore) ...[
                const SizedBox(height: 8),
                Text(
                  'Mostrando as ${recent.length} mais recentes de $older — '
                  'toque em "Abrir" para ver tudo.',
                  style: TextStyle(color: neu.inkFaint, fontSize: 11.5),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Uma mensagem na prévia: remetente + hora numa linha, corpo em até 2 linhas.
class _MessagePreviewTile extends StatelessWidget {
  const _MessagePreviewTile({required this.message, required this.onTap});

  final Message message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final fromCustomer = message.sender == 'customer';
    final who = (message.authorName?.trim().isNotEmpty ?? false)
        ? message.authorName!.trim()
        : (fromCustomer ? 'Cliente' : 'Equipe');
    final hasPhoto = message.photoUrl != null && message.photoUrl!.isNotEmpty;
    final body = message.body.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      child: NeuSurface(
        elevation: NeuElevation.inset,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  fromCustomer
                      ? Icons.person_rounded
                      : Icons.support_agent_rounded,
                  size: 14,
                  color: fromCustomer ? neu.accent : neu.inkFaint,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    who,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fromCustomer ? neu.accent : neu.inkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _fmtMsgDate(message.createdAt),
                  style: TextStyle(color: neu.inkFaint, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPhoto) ...[
                  Icon(Icons.photo_outlined, size: 14, color: neu.inkFaint),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    body.isNotEmpty ? body : (hasPhoto ? 'Foto' : ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: neu.ink, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card com o link público de acompanhamento da OS. As ações (copiar/WhatsApp/
/// e-mail) vivem em [OsTrackingLinkActions] — as mesmas que o diálogo mostrado
/// logo depois de criar a OS oferece.
class _TrackingLinkCard extends StatelessWidget {
  const _TrackingLinkCard({required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return OsSectionCard(
      icon: Icons.link_rounded,
      title: 'Link de acompanhamento',
      glyphIndex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compartilhe com o cliente para ele acompanhar a OS em tempo real.',
            style: TextStyle(color: neu.inkMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          OsTrackingLinkActions(order: order),
        ],
      ),
    );
  }
}

/// Data curta de uma mensagem na prévia ("14:32" hoje, "12/08" antes disso).
String _fmtMsgDate(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  final agora = DateTime.now();
  final hoje = d.year == agora.year && d.month == agora.month && d.day == agora.day;
  return hoje ? '${two(d.hour)}:${two(d.minute)}' : '${two(d.day)}/${two(d.month)}';
}
