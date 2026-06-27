import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/realtime/realtime_chat.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/read_ticks.dart';
import '../../../di.dart';
import '../domain/messages_models.dart';
import 'messages_providers.dart';

/// Thread de conversa (chat): bolhas do cliente à esquerda, do staff à direita,
/// com autor + hora; campo de resposta + enviar. Ao abrir, marca como lido e
/// invalida o inbox para zerar o badge. Corpo apenas — moldura é do shell.
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

  /// Leva a conversa para o final, acompanhando a última mensagem. Agendado
  /// após o frame para que o ListView já tenha medido a nova extensão.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      // Ao abrir, pula direto para o fim (sem animação visível). Depois disso,
      // anima suavemente ao chegar/enviar mensagens.
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
                  OutlinedButton.icon(
                    style:
                        OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () => ref
                        .invalidate(threadProvider(widget.conversationId)),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Tentar de novo'),
                  ),
                ],
              ),
            ),
            data: (thread) {
              // Sempre que a thread renderiza (abrir, nova mensagem enviada
              // ou recebida no refresh), acompanha a última mensagem.
              _scrollToBottom();
              return _ThreadBody(thread: thread, controller: _scroll);
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
  const _ThreadBody({required this.thread, required this.controller});
  final ConversationThread thread;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final messages = thread.messages;
    return _ChatBackground(
      child: messages.isEmpty
          ? const Center(child: Text('Nenhuma mensagem ainda.'))
          : ListView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              itemCount: messages.length,
              itemBuilder: (_, i) => _Bubble(message: messages[i]),
            ),
    );
  }
}

/// Fundo decorativo da conversa: um leve degradê on-brand com uma trama de
/// pontos sutil por cima, para a tela não ficar "sem graça". O padrão é
/// discreto o bastante para não competir com as bolhas de mensagem.
class _ChatBackground extends StatelessWidget {
  const _ChatBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface,
            Color.alphaBlend(
              AppColors.brand.withValues(alpha: dark ? 0.06 : 0.04),
              scheme.surface,
            ),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _DotGridPainter(
          color: AppColors.brand.withValues(alpha: dark ? 0.10 : 0.07),
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
    final scheme = Theme.of(context).colorScheme;
    final isStaff = message.sender == 'staff';
    final time = _time(message.createdAt);
    final bg = isStaff ? AppColors.brand : scheme.surfaceContainerHigh;
    final fg = isStaff ? Colors.white : scheme.onSurface;
    final metaColor = isStaff
        ? Colors.white.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;

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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Escreva uma resposta…',
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: sending ? null : onSend,
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
