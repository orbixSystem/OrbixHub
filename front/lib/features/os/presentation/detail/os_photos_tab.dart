import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/offline/widgets/offline_notices.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/os_models.dart';
import '../os_providers.dart';
import 'os_detail_shared.dart';

/// Aba **Fotos**: a evidência visual do serviço — antes, durante e depois.
///
/// Numa aba própria as miniaturas viram GRADE (quebram em linhas conforme a
/// largura) em vez da tira horizontal que existia quando isto dividia espaço
/// com outras seções: rolar de lado para procurar uma foto é pior que ver
/// todas de uma vez, e o espaço de uma aba inteira comporta isso.
class OsPhotosTab extends ConsumerStatefulWidget {
  const OsPhotosTab({super.key, required this.order, required this.canWrite});

  final ServiceOrder order;
  final bool canWrite;

  @override
  ConsumerState<OsPhotosTab> createState() => _OsPhotosTabState();
}

class _OsPhotosTabState extends ConsumerState<OsPhotosTab> {
  bool _busy = false;

  ServiceOrder get order => widget.order;

  /// Anexar foto É registrar um evento: escolhe a imagem e diz, em uma linha,
  /// o que foi feito. Essa legenda vira o texto do evento na linha do tempo —
  /// no app e no link do cliente. Antes ela nunca era coletada (ia `null`
  /// fixo), então o cliente lia "Foto adicionada" e tinha de adivinhar o
  /// serviço pela imagem; registrar "troquei a correia" exigia uma segunda
  /// ação, numa outra aba.
  Future<void> _add() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.bytes == null || !mounted) return;

    final legenda = await _pedirLegenda(file.name);
    // `null` = desistiu no diálogo; string vazia = anexou sem descrever.
    if (legenda == null || !mounted) return;

    final ext = (file.extension ?? 'jpeg').toLowerCase();
    setState(() => _busy = true);
    try {
      await ref
          .read(osRepositoryProvider)
          .addPhoto(
            order.id,
            bytes: file.bytes!,
            filename: file.name,
            contentType: 'image/$ext',
            caption: legenda.isEmpty ? null : legenda,
          );
      // Guard depois do await: o widget pode ter sido descartado enquanto a
      // chamada estava em voo (sair da tela, fechar o diálogo, trocar de OS).
      if (!mounted) return;
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pergunta o que a foto mostra. Opcional de propósito: obrigar a escrever
  /// faria o mecânico com as mãos sujas desistir de documentar.
  Future<String?> _pedirLegenda(String arquivo) async {
    final ctrl = TextEditingController();
    final ok = await showNeuDialog<bool>(
      context,
      dialog: NeuDialog(
        title: 'O que esta foto mostra?',
        maxWidth: 440,
        actions: [
          Builder(
            builder: (ctx) => NeuButton(
              label: 'Cancelar',
              kind: NeuButtonKind.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ),
          Builder(
            builder: (ctx) => NeuButton(
              label: 'Anexar',
              icon: Icons.add_a_photo_outlined,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              arquivo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.neu.inkFaint, fontSize: 12),
            ),
            const SizedBox(height: 12),
            NeuTextField(
              label: 'Descrição (opcional)',
              controller: ctrl,
              hint: 'Ex.: Troquei a correia dentada',
              maxLength: 200,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 14, color: context.neu.inkFaint),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'A foto e esta descrição aparecem no link de '
                    'acompanhamento do cliente, com data e hora.',
                    style: TextStyle(
                      color: context.neu.inkFaint,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return ok == true ? ctrl.text.trim() : null;
  }

  Future<void> _remove(OrderPhoto photo) async {
    final confirmed = await showNeuConfirm(
      context,
      title: 'Remover foto?',
      message: 'Esta foto será removida da OS. Não é possível desfazer.',
      confirmLabel: 'Remover',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(osRepositoryProvider).deletePhoto(order.id, photo.id);
      // Guard depois do await: o widget pode ter sido descartado enquanto a
      // chamada estava em voo (sair da tela, fechar o diálogo, trocar de OS).
      if (!mounted) return;
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Abre a thread de comentários da foto (staff lê e adiciona).
  Future<void> _openComments(OrderPhoto photo) async {
    await showNeuDialog<void>(
      context,
      dialog: NeuDialog(
        title: 'Comentários da foto',
        maxWidth: 520,
        child: _PhotoCommentsPanel(orderId: order.id, photo: photo),
      ),
    );
    // Recarrega o detalhe ao fechar: o badge de comentários da miniatura
    // reflete o que a thread mostrou (inclui comentários novos do cliente).
    if (mounted) ref.invalidate(orderProvider(order.id));
  }

  @override
  Widget build(BuildContext context) {
    final photos = order.photos;
    // Offline: a foto fica guardada no aparelho (blob) e sobe no replay; abrir
    // comentários e remover foto exigem a foto existir no servidor.
    final offline = ref.watch(isOfflineProvider);
    return OsSectionCard(
      icon: Icons.photo_library_rounded,
      title: 'Fotos',
      glyphIndex: 5,
      notice: const OfflinePendingNotice(
        message:
            'As fotos adicionadas agora só serão enviadas ao sistema '
            'quando a conexão voltar',
      ),
      action: widget.canWrite
          ? OsHeaderAction(
              icon: _busy
                  ? Icons.hourglass_top_rounded
                  : Icons.add_a_photo_outlined,
              label: _busy ? 'Enviando…' : 'Adicionar',
              onTap: _busy ? () {} : _add,
            )
          : null,
      child: photos.isEmpty
          ? OsInlineEmpty(
              icon: Icons.image_outlined,
              text: 'Sem fotos.',
              hint: 'Registre o estado do veículo antes e depois do serviço.',
            )
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final p in photos)
                  _PhotoThumb(
                    photo: p,
                    canWrite: widget.canWrite,
                    offline: offline,
                    onRemove: () => _remove(p),
                    onTap: () => _openComments(p),
                  ),
              ],
            ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.photo,
    required this.canWrite,
    required this.onRemove,
    required this.onTap,
    this.offline = false,
  });

  final OrderPhoto photo;
  final bool canWrite;

  /// Offline: comentários e remoção da foto exigem servidor (B8) — o toque é
  /// bloqueado e a miniatura ganha tooltip "Requer conexão".
  final bool offline;
  final VoidCallback onRemove;

  /// Toque na miniatura abre a thread de comentários da foto.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final legenda = photo.caption?.trim() ?? '';
    final Widget image = NeuNetworkImage(
      url: photo.url,
      width: 96,
      height: 96,
      radius: 12,
    );
    final miniatura = Stack(
      children: [
        if (offline)
          Tooltip(
            message: '$kRequiresConnectionTooltip — comentários da foto',
            child: Opacity(opacity: 0.75, child: image),
          )
        else
          GestureDetector(onTap: onTap, child: image),
        // Selo de comentários: só aparece quando a foto TEM comentários, com a
        // contagem — assim a equipe sabe sem precisar abrir a foto.
        if (photo.commentCount > 0)
          Positioned(
            bottom: 2,
            left: 2,
            child: Material(
              color: Colors.black54,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: offline ? null : onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mode_comment_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${photo.commentCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Remover foto exige a foto NO SERVIDOR (não há op de sync p/ remoção):
        // offline o botão continua VISÍVEL, mas inerte e explicado — some ≠
        // explicar.
        if (canWrite)
          Positioned(
            top: 2,
            right: 2,
            child: RequiresConnection(
              reason: 'remover foto',
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    // A LEGENDA embaixo da miniatura. Ela já era pedida no anexo e já aparecia
    // para o cliente no link de acompanhamento — só a própria oficina não via,
    // e ficava com uma grade de fotos sem contexto ("qual delas era a correia?").
    if (legenda.isEmpty) return miniatura;
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          miniatura,
          const SizedBox(height: 5),
          Tooltip(
            // Duas linhas cobrem a maioria; o texto inteiro fica no tooltip
            // em vez de esticar a célula da grade.
            message: legenda,
            child: Text(
              legenda,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formata um ISO-8601 para "dd/MM HH:mm" (pt-BR); vazio se não parsear.
String _fmtCommentDate(String? iso) {
  if (iso == null) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
}

/// Painel da thread de comentários de uma foto da OS (lado staff): preview da
/// foto, lista de comentários (equipe/cliente + data) e campo para adicionar.
/// Carrega via [OsRepository.listPhotoComments]; adiciona via
/// [OsRepository.addPhotoComment].
class _PhotoCommentsPanel extends ConsumerStatefulWidget {
  const _PhotoCommentsPanel({required this.orderId, required this.photo});

  final String orderId;
  final OrderPhoto photo;

  @override
  ConsumerState<_PhotoCommentsPanel> createState() =>
      _PhotoCommentsPanelState();
}

class _PhotoCommentsPanelState extends ConsumerState<_PhotoCommentsPanel> {
  final _input = TextEditingController();
  late Future<List<PhotoComment>> _future;
  List<PhotoComment> _comments = const [];
  bool _loaded = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PhotoComment>> _load() async {
    final list = await ref
        .read(osRepositoryProvider)
        .listPhotoComments(widget.orderId, widget.photo.id);
    _comments = list;
    _loaded = true;
    return list;
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final created = await ref
          .read(osRepositoryProvider)
          .addPhotoComment(widget.orderId, widget.photo.id, body);
      // Guard depois do await: o widget pode ter sido descartado enquanto a
      // chamada estava em voo (sair da tela, fechar o diálogo, trocar de OS).
      if (!mounted) return;
      _input.clear();
      setState(() => _comments = [..._comments, created]);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: NeuNetworkImage(
            url: widget.photo.url,
            width: 220,
            height: 160,
            radius: 12,
          ),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<PhotoComment>>(
          future: _future,
          builder: (context, snap) {
            if (!_loaded && snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!_loaded && snap.hasError) {
              final e = snap.error;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  e is AppException
                      ? e.message
                      : 'Erro ao carregar comentários.',
                  style: TextStyle(color: neu.inkMuted),
                ),
              );
            }
            if (_comments.isEmpty) {
              return OsInlineEmpty(
                icon: Icons.mode_comment_outlined,
                text: 'Nenhum comentário ainda.',
                hint: 'Escreva o primeiro comentário sobre esta foto.',
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _comments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _CommentTile(comment: _comments[i]),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: NeuSurface(
                elevation: NeuElevation.inset,
                radius: NeuTokens.rField,
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  style: TextStyle(color: neu.ink, fontSize: 14.5),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: 'Adicionar comentário…',
                    hintStyle: TextStyle(color: neu.inkFaint),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            NeuIconButton(
              icon: Icons.send_rounded,
              tooltip: 'Enviar comentário',
              color: neu.navy,
              onPressed: _sending ? null : _add,
            ),
          ],
        ),
      ],
    );
  }
}

/// Cartão de um comentário: autor (Equipe/cliente) + data + texto.
class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final PhotoComment comment;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isStaff = comment.authorKind == 'staff';
    final who = (comment.authorName?.trim().isNotEmpty ?? false)
        ? comment.authorName!.trim()
        : (isStaff ? 'Equipe' : 'Cliente');
    final date = _fmtCommentDate(comment.createdAt);
    final accent = isStaff ? neu.navy : neu.inkMuted;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isStaff ? Icons.engineering_outlined : Icons.person_outline,
                size: 15,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                who,
                style: TextStyle(
                  color: accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: TextStyle(color: neu.inkFaint, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            comment.body,
            style: TextStyle(color: neu.ink, fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }
}
