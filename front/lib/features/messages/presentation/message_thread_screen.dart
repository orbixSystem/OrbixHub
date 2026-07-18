import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/realtime/realtime_chat.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/read_ticks.dart';
import '../../../di.dart';
import '../../os/domain/os_models.dart';
import '../../os/presentation/os_providers.dart';
import '../domain/messages_models.dart';
import 'messages_providers.dart';

/// Thread de conversa (chat): bolhas do cliente à esquerda, do staff à direita,
/// com autor + hora; campo de resposta + enviar. PAGINADA: carrega as 50 mais
/// recentes; "Carregar anteriores" busca páginas antigas por cursor (as antigas
/// ficam acumuladas em estado local — o provider só cuida da página corrente).
/// Ao abrir, marca como lido e invalida o inbox. Corpo apenas — moldura do shell.
///
/// Citação estilo WhatsApp: responder a uma mensagem (mostra a citação acima do
/// campo e, ao enviar, dentro da bolha) e citar uma foto da OS desta conversa.
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

  /// Mensagem que está sendo respondida (citação estilo WhatsApp), ou null.
  Message? _replyTo;

  /// Foto da OS citada junto da próxima mensagem (id + url), ou null.
  String? _photoId;
  String? _photoUrl;

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

  void _startReply(Message message) {
    setState(() => _replyTo = message);
  }

  void _cancelReply() {
    setState(() => _replyTo = null);
  }

  void _cancelPhoto() {
    setState(() {
      _photoId = null;
      _photoUrl = null;
    });
  }

  /// Abre o seletor de fotos da OS desta conversa (`refType=='os'`,
  /// `refId==orderId`) e cita a escolhida na próxima mensagem. "Aponta, não
  /// invade": lê a OS via serviço público (`osRepositoryProvider`).
  Future<void> _pickOsPhoto() async {
    final conv = ref
        .read(threadProvider(widget.conversationId))
        .asData
        ?.value
        .conversation;
    final orderId = conv?.refType == 'os' ? conv?.refId : null;
    if (orderId == null || orderId.isEmpty) {
      _snack('Fotos disponíveis apenas em conversas de OS.');
      return;
    }
    ServiceOrder order;
    try {
      order = await ref.read(osRepositoryProvider).getOrder(orderId);
    } on AppException catch (e) {
      _snack(e.message);
      return;
    }
    if (!mounted) return;
    if (order.photos.isEmpty) {
      _snack('Esta OS ainda não tem fotos.');
      return;
    }
    final chosen = await showNeuDialog<OrderPhoto>(
      context,
      dialog: NeuDialog(
        title: 'Citar foto da OS',
        maxWidth: 560,
        child: _OsPhotoPicker(photos: order.photos),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _photoId = chosen.id;
      _photoUrl = chosen.url;
    });
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    // Permite enviar só com foto citada (sem texto), como o WhatsApp.
    if ((body.isEmpty && _photoId == null) || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagesRepositoryProvider).sendMessage(
            widget.conversationId,
            body,
            replyToId: _replyTo?.id,
            photoId: _photoId,
            photoUrl: _photoUrl,
          );
      _reply.clear();
      setState(() {
        _replyTo = null;
        _photoId = null;
        _photoUrl = null;
      });
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
    // O thread é LIDO do cache local (SQLite) offline; só o compositor (enviar
    // resposta / citar foto) exige conexão — envolto em [RequiresConnection].
    final async = ref.watch(threadProvider(widget.conversationId));
    return Column(
      children: [
        _ThreadHeader(conversation: async.asData?.value.conversation),
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
                onReply: _startReply,
              );
            },
          ),
        ),
        // Enviar mensagem é online-only (chat/tempo real): offline o compositor
        // fica inerte com o aviso "Requer conexão" (a leitura acima continua).
        RequiresConnection(
          reason: 'enviar mensagens exige conexão',
          child: _Composer(
            controller: _reply,
            sending: _sending,
            replyTo: _replyTo,
            photoUrl: _photoUrl,
            onSend: _send,
            onPickPhoto: _pickOsPhoto,
            onCancelReply: _cancelReply,
            onCancelPhoto: _cancelPhoto,
          ),
        ),
      ],
    );
  }
}

/// Header da conversa: voltar para a lista + com quem se está falando.
class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.conversation});

  final Conversation? conversation;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final title = conversation?.title?.trim();
    final subtitle = conversation?.refLabel?.trim();
    return Container(
      decoration: BoxDecoration(
        color: neu.surface,
        border: Border(
          bottom: BorderSide(color: neu.ink.withValues(alpha: 0.14)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          NeuIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Voltar para as conversas',
            size: 42,
            onPressed: () => context.go('/mensagens'),
          ),
          const SizedBox(width: 10),
          NeuIconChip.glyph(
            context,
            icon: Icons.person_rounded,
            index: 3,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (title == null || title.isEmpty) ? 'Conversa' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                  ),
              ],
            ),
          ),
        ],
      ),
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
    required this.onReply,
  });

  final List<Message> messages;
  final ScrollController controller;
  final bool hasMore;
  final bool loadingOlder;
  final VoidCallback onLoadOlder;
  final void Function(Message) onReply;

  @override
  Widget build(BuildContext context) {
    return _ChatBackground(
      // As mensagens ocupam a largura toda (cliente à esquerda, staff à
      // direita), com uma margem lateral pequena para não grudarem nas bordas.
      child: messages.isEmpty
          ? const Center(child: Text('Nenhuma mensagem ainda.'))
          : ListView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                return _Bubble(
                  message: messages[index],
                  onReply: onReply,
                );
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

/// Rótulo de autor de uma citação (fallback por remetente).
String _quoteAuthor(MessageQuote q) {
  final name = q.authorName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return q.sender == 'staff' ? 'Equipe' : 'Cliente';
}

class _Bubble extends StatefulWidget {
  const _Bubble({required this.message, required this.onReply});
  final Message message;
  final void Function(Message) onReply;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final message = widget.message;
    final isStaff = message.sender == 'staff';
    final time = _time(message.createdAt);
    final bg = isStaff ? neu.navy : neu.surfaceHi;
    final fg = isStaff ? neu.onNavy : neu.ink;
    final metaColor =
        isStaff ? neu.onNavy.withValues(alpha: 0.8) : neu.inkMuted;
    final hasPhoto =
        message.photoUrl != null && message.photoUrl!.trim().isNotEmpty;

    final bubble = Container(
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: metaColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (message.replyTo != null) ...[
            const SizedBox(height: 4),
            _QuoteBlock(quote: message.replyTo!, onStaffBubble: isStaff),
          ],
          if (hasPhoto) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _openPhotoFullscreen(context, message.photoUrl!),
              child: NeuNetworkImage(
                url: message.photoUrl,
                width: 200,
                height: 150,
                radius: 10,
              ),
            ),
          ],
          if (message.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(message.body, style: TextStyle(color: fg, fontSize: 14.5)),
          ],
          if (time.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: TextStyle(color: metaColor, fontSize: 10.5)),
                if (isStaff) ...[
                  const SizedBox(width: 4),
                  ReadTicks(read: message.readAt != null, onBrand: true),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    final replyButton = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _hover ? 1 : 0.45,
        child: Tooltip(
          message: 'Responder',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => widget.onReply(message),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Icon(Icons.reply_rounded, size: 18, color: neu.inkMuted),
            ),
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onLongPress: () => widget.onReply(message),
        child: Align(
          alignment: isStaff ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                isStaff ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: isStaff
                ? [replyButton, Flexible(child: bubble)]
                : [Flexible(child: bubble), replyButton],
          ),
        ),
      ),
    );
  }
}

/// Mini-bloco de citação (barra colorida à esquerda + autor + trecho). Usado
/// dentro da bolha (acima do texto) e no preview do compositor.
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({
    required this.quote,
    this.onStaffBubble = false,
  });

  final MessageQuote quote;

  /// Quando desenhado dentro de uma bolha do staff (fundo navy), inverte as
  /// cores para manter contraste.
  final bool onStaffBubble;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final barColor = quote.sender == 'staff' ? neu.navy : neu.accent;
    final bg = onStaffBubble ? neu.onNavy.withValues(alpha: 0.14) : neu.base;
    final authorColor = onStaffBubble ? neu.onNavy : neu.navy;
    final bodyColor =
        onStaffBubble ? neu.onNavy.withValues(alpha: 0.85) : neu.inkMuted;
    final body = quote.body.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, color: onStaffBubble ? neu.onNavy : barColor),
            Container(
              color: bg,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _quoteAuthor(quote),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: authorColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: bodyColor, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre a foto em tela cheia com zoom (pinça/scroll) sobre um fundo escuro.
void _openPhotoFullscreen(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (ctx) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: NeuNetworkImage(url: url, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Grade de fotos da OS para escolher qual citar. Toque devolve a foto (pop).
class _OsPhotoPicker extends StatelessWidget {
  const _OsPhotoPicker({required this.photos});
  final List<OrderPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final p in photos)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pop(p),
            child: NeuNetworkImage(
              url: p.url,
              width: 120,
              height: 120,
              radius: 12,
            ),
          ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.replyTo,
    required this.photoUrl,
    required this.onSend,
    required this.onPickPhoto,
    required this.onCancelReply,
    required this.onCancelPhoto,
  });

  final TextEditingController controller;
  final bool sending;
  final Message? replyTo;
  final String? photoUrl;
  final VoidCallback onSend;
  final VoidCallback onPickPhoto;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelPhoto;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      color: neu.base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (replyTo != null) ...[
            _ComposerPreview(
              onCancel: onCancelReply,
              child: _QuoteBlock(
                quote: MessageQuote(
                  sender: replyTo!.sender,
                  authorName: replyTo!.authorName,
                  body: replyTo!.body,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (photoUrl != null) ...[
            _ComposerPreview(
              onCancel: onCancelPhoto,
              child: Row(
                children: [
                  NeuNetworkImage(
                    url: photoUrl,
                    width: 48,
                    height: 48,
                    radius: 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Foto da OS anexada',
                      style: TextStyle(
                        color: neu.inkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              NeuIconButton(
                icon: Icons.add_photo_alternate_outlined,
                tooltip: 'Citar foto da OS',
                color: neu.navy,
                onPressed: sending ? null : onPickPhoto,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeuSurface(
                  elevation: NeuElevation.inset,
                  radius: NeuTokens.rField,
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(color: neu.ink, fontSize: 14.5),
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
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
        ],
      ),
    );
  }
}

/// Faixa de preview acima do compositor (citação ou foto) com um X para
/// cancelar. Superfície levemente elevada para destacar do fundo.
class _ComposerPreview extends StatelessWidget {
  const _ComposerPreview({required this.child, required this.onCancel});

  final Widget child;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          Expanded(child: child),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: neu.inkMuted),
            tooltip: 'Cancelar',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
