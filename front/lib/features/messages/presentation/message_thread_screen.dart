import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/realtime/realtime_chat.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/read_ticks.dart';
import '../../../di.dart';
import '../domain/messages_models.dart';
import 'messages_providers.dart';

/// Thread de conversa (chat): bolhas do cliente à esquerda, do staff à direita,
/// com autor + hora; campo de resposta + enviar. PAGINADA: carrega as 50 mais
/// recentes; "Carregar anteriores" busca páginas antigas por cursor (as antigas
/// ficam acumuladas em estado local — o provider só cuida da página corrente).
/// Ao abrir, marca como lido e invalida o inbox. Corpo apenas — moldura do shell.
class MessageThreadScreen extends ConsumerStatefulWidget {
  const MessageThreadScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<MessageThreadScreen> createState() =>
      _MessageThreadScreenState();
}

class _MessageThreadScreenState extends ConsumerState<MessageThreadScreen> {
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _didInitialJump = false;
  final RealtimeChat _rt = RealtimeChat();

  /// Mensagens ANTERIORES às da página corrente (acumuladas via cursor).
  List<Message> _older = const [];

  /// Há páginas anteriores além das já puxadas para [_older]?
  bool? _olderHasMore;
  bool _loadingOlder = false;

  /// Última mensagem exibida — auto-scroll só quando ELA muda (mensagem nova
  /// no fim), nunca ao prepender antigas.
  String? _lastMessageId;

  @override
  void initState() {
    super.initState();
    // Abrir reseta o não-lido no servidor (via getThread). Após o primeiro
    // frame, invalida o inbox para o badge refletir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(conversationsProvider);
    });
    // Tempo real: mensagem nova do cliente aparece na hora (push via WebSocket).
    final accessToken = ref.read(accessTokenStoreProvider).token;
    if (accessToken != null) {
      _rt.connectStaff(
        accessToken: accessToken,
        conversationId: widget.conversationId,
        onMessage: (_) {
          if (!mounted) return;
          ref.invalidate(threadProvider(widget.conversationId));
          ref.invalidate(conversationsProvider);
        },
      );
    }
  }

  @override
  void dispose() {
    _rt.dispose();
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Leva a conversa para o final quando chega mensagem nova no fim.
  void _maybeScrollToBottom(List<Message> visible) {
    final lastId = visible.isEmpty ? null : visible.last.id;
    if (lastId == _lastMessageId) return;
    _lastMessageId = lastId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (!_didInitialJump) {
        _didInitialJump = true;
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(messagesRepositoryProvider)
          .sendMessage(widget.conversationId, body);
      _reply.clear();
      ref.invalidate(threadProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Puxa a página ANTERIOR (cursor = createdAt da mensagem mais antiga
  /// visível) e prepende ao acumulado local.
  Future<void> _loadOlder(ConversationThread thread) async {
    if (_loadingOlder) return;
    final oldest = _older.isNotEmpty
        ? _older.first
        : (thread.messages.isNotEmpty ? thread.messages.first : null);
    final cursor = oldest?.createdAt;
    if (cursor == null) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await ref
          .read(messagesRepositoryProvider)
          .getThread(widget.conversationId, before: cursor);
      setState(() {
        _older = [...page.messages, ..._older];
        _olderHasMore = page.hasMore;
      });
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  /// Antigas acumuladas + página corrente, sem duplicar (o realtime pode
  /// re-buscar a página corrente com sobreposição).
  List<Message> _visible(ConversationThread thread) {
    if (_older.isEmpty) return thread.messages;
    final seen = _older.map((m) => m.id).toSet();
    return [
      ..._older,
      ...thread.messages.where((m) => !seen.contains(m.id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(threadProvider(widget.conversationId));
    return Column(
      children: [
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e is AppException
                      ? e.message
                      : 'Erro ao carregar a conversa.'),
                  const SizedBox(height: 12),
                  NeuButton(
                    label: 'Tentar de novo',
                    kind: NeuButtonKind.secondary,
                    icon: Icons.refresh,
                    onPressed: () =>
                        ref.invalidate(threadProvider(widget.conversationId)),
                  ),
                ],
              ),
            ),
            data: (thread) {
              final visible = _visible(thread);
              _maybeScrollToBottom(visible);
              final hasMore = _olderHasMore ?? thread.hasMore;
              return _ThreadBody(
                messages: visible,
                controller: _scroll,
                hasMore: hasMore,
                loadingOlder: _loadingOlder,
                onLoadOlder: () => _loadOlder(thread),
              );
            },
          ),
        ),
        _Composer(
          controller: _reply,
          sending: _sending,
          onSend: _send,
        ),
      ],
    );
  }
}

class _ThreadBody extends StatelessWidget {
  const _ThreadBody({
    required this.messages,
    required this.controller,
    required this.hasMore,
    required this.loadingOlder,
    required this.onLoadOlder,
  });

  final List<Message> messages;
  final ScrollController controller;
  final bool hasMore;
  final bool loadingOlder;
  final VoidCallback onLoadOlder;

  @override
  Widget build(BuildContext context) {
    return _ChatBackground(
      child: messages.isEmpty
          ? const Center(child: Text('Nenhuma mensagem ainda.'))
          : ListView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              itemCount: messages.length + (hasMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (hasMore && i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Center(
                      child: NeuButton(
                        label: 'Carregar mensagens anteriores',
                        kind: NeuButtonKind.secondary,
                        icon: Icons.history_rounded,
                        loading: loadingOlder,
                        onPressed: onLoadOlder,
                      ),
                    ),
                  );
                }
                final index = hasMore ? i - 1 : i;
                return _Bubble(message: messages[index]);
              },
            ),
    );
  }
}

/// Fundo decorativo da conversa: um leve degradê lavanda com uma trama de
/// pontos sutil por cima. Discreto o bastante para não competir com as bolhas.
class _ChatBackground extends StatelessWidget {
  const _ChatBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            neu.base,
            Color.alphaBlend(
              neu.accent.withValues(alpha: dark ? 0.06 : 0.05),
              neu.base,
            ),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _DotGridPainter(
          color: neu.accent.withValues(alpha: dark ? 0.12 : 0.10),
        ),
        child: child,
      ),
    );
  }
}

/// Trama de pontos espaçados — barata de pintar e agradável como textura.
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});
  final Color color;

  static const double _gap = 26;
  static const double _radius = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = _gap / 2; y < size.height; y += _gap) {
      for (double x = _gap / 2; x < size.width; x += _gap) {
        canvas.drawCircle(Offset(x, y), _radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

/// Formata um ISO-8601 em "HH:mm". Falha → string vazia.
String _time(String? iso) {
  if (iso == null) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isStaff = message.sender == 'staff';
    final time = _time(message.createdAt);
    final bg = isStaff ? neu.navy : neu.surfaceHi;
    final fg = isStaff ? neu.onNavy : neu.ink;
    final metaColor =
        isStaff ? neu.onNavy.withValues(alpha: 0.8) : neu.inkMuted;

    return Align(
      alignment: isStaff ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isStaff ? 16 : 4),
            bottomRight: Radius.circular(isStaff ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: neu.shadowDark.withValues(alpha: .35),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isStaff ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.authorName != null &&
                message.authorName!.trim().isNotEmpty)
              Text(
                message.authorName!,
                style: TextStyle(
                  color: metaColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (message.body.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(message.body, style: TextStyle(color: fg, fontSize: 14.5)),
            ],
            if (time.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time,
                      style: TextStyle(color: metaColor, fontSize: 10.5)),
                  if (isStaff) ...[
                    const SizedBox(width: 4),
                    ReadTicks(read: message.readAt != null, onBrand: true),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      color: neu.base,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: NeuSurface(
              elevation: NeuElevation.inset,
              radius: NeuTokens.rField,
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                style: TextStyle(color: neu.ink, fontSize: 14.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Escreva uma resposta…',
                  hintStyle: TextStyle(color: neu.inkFaint),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          NeuIconButton(
            icon: Icons.send_rounded,
            tooltip: 'Enviar',
            color: neu.navy,
            onPressed: sending ? null : onSend,
          ),
        ],
      ),
    );
  }
}
