import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/offline/widgets/offline_notices.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/os_models.dart';
import '../os_providers.dart';
import '../os_status.dart';
import 'os_detail_shared.dart';

/// Aba **Histórico**: o que aconteceu com esta OS, em ordem — mudanças de
/// status, notas da equipe e o que foi compartilhado com o cliente.
class OsTimelineTab extends ConsumerWidget {
  const OsTimelineTab({super.key, required this.order, required this.canWrite});

  final ServiceOrder order;
  final bool canWrite;

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final draft = await _NoteDialog.show(context);
    if (draft == null) return;
    try {
      await ref
          .read(osRepositoryProvider)
          .createNote(
            order.id,
            message: draft.message,
            visiblePublic: draft.visiblePublic,
          );
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = order.events;
    return OsSectionCard(
      icon: Icons.timeline_rounded,
      title: 'Linha do tempo',
      glyphIndex: 4,
      // Notas criadas offline ficam no aparelho até a conexão voltar.
      notice: const OfflinePendingNotice(
        message:
            'Notas criadas agora só serão enviadas ao sistema quando a '
            'conexão voltar',
      ),
      action: canWrite
          ? OsHeaderAction(
              icon: Icons.add_comment_outlined,
              // "Nota" soava a rascunho interno e ninguém achava. É a porta
              // do mecânico para registrar o que fez em TEXTO — a irmã do
              // anexar foto, e como ela vai para o acompanhamento do cliente.
              label: 'Registrar evento',
              onTap: () => _addNote(context, ref),
            )
          : null,
      child: events.isEmpty
          ? OsInlineEmpty(
              icon: Icons.history_rounded,
              text: 'Nenhum evento ainda.',
              hint: 'As mudanças de status e notas aparecem aqui.',
            )
          : Column(
              children: [
                for (var i = 0; i < events.length; i++)
                  _EventRow(
                    event: events[i],
                    isFirst: i == 0,
                    isLast: i == events.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final OrderEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final dotColor = _dotColor(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trilho vertical com o ponto/ícone.
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : neu.base,
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_kindIcon(), size: 16, color: dotColor),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : neu.base,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _label(),
                          style: TextStyle(
                            color: neu.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: event.visiblePublic
                            ? 'Visível ao cliente'
                            : 'Interno (não visível ao cliente)',
                        child: Icon(
                          event.visiblePublic
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 16,
                          color: event.visiblePublic ? neu.navy : neu.inkFaint,
                        ),
                      ),
                    ],
                  ),
                  if (event.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _fmtTimestamp(event.createdAt!),
                      style: TextStyle(color: neu.inkMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rótulo do evento: usa a `message` quando há; senão deriva de `status_change`
  /// (rótulo PT-BR do status) ou do `kind`.
  String _label() {
    final msg = event.message?.trim();
    if (msg != null && msg.isNotEmpty) return msg;
    switch (event.kind) {
      case 'status_change':
        final snap = event.statusSnapshot;
        return snap == null
            ? 'Status alterado'
            : 'Status: ${osStatusLabel(snap)}';
      case 'created':
        return 'OS criada';
      case 'photo':
        return 'Foto adicionada';
      default:
        return 'Nota';
    }
  }

  Color _dotColor(BuildContext context) {
    final neu = context.neu;
    switch (event.kind) {
      case 'status_change':
        return event.statusSnapshot == null
            ? neu.navy
            : osStatusInk(
                event.statusSnapshot!, Theme.of(context).brightness);
      case 'created':
        return neu.success;
      case 'photo':
        return neu.glyphs[1];
      default:
        return neu.inkMuted;
    }
  }

  IconData _kindIcon() {
    switch (event.kind) {
      case 'created':
        return Icons.flag_outlined;
      case 'status_change':
        return Icons.swap_horiz;
      case 'photo':
        return Icons.photo_outlined;
      case 'note':
      default:
        return Icons.chat_bubble_outline;
    }
  }

  /// Timestamp curto a partir de um ISO-8601. Mostra `dd/MM HH:mm`; se não
  /// parsear, devolve o original.
  String _fmtTimestamp(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// Resultado do dialog de nova nota.
class _NoteDraft {
  const _NoteDraft({required this.message, required this.visiblePublic});
  final String message;
  final bool visiblePublic;
}

/// Dialog para adicionar uma nota à linha do tempo (mensagem + visibilidade).
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  static Future<_NoteDraft?> show(BuildContext context) {
    return showDialog<_NoteDraft>(
      context: context,
      builder: (_) => const _NoteDialog(),
    );
  }

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _message = TextEditingController();

  /// Nasce LIGADO: registrar evento existe para o cliente acompanhar, e é o
  /// mesmo contrato do anexo de foto (que sempre vai para o link). Deixar
  /// desligado por padrão fazia o mecânico escrever achando que informou o
  /// cliente — e não informou. Quem quer nota interna desliga aqui.
  bool _visiblePublic = true;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_NoteDraft(message: text, visiblePublic: _visiblePublic));
  }

  @override
  Widget build(BuildContext context) {
    return NeuDialog(
      title: 'Registrar evento',
      maxWidth: context.isMobile ? 560 : 420,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: 'Registrar',
          icon: Icons.check_rounded,
          onPressed: _submit,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _message,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'O que aconteceu?',
              hintText: 'Ex.: troquei a correia dentada; peça pedida ao '
                  'fornecedor, chega quinta',
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _visiblePublic,
            onChanged: (v) => setState(() => _visiblePublic = v),
            title: const Text('Mostrar ao cliente'),
            subtitle: Text(
              _visiblePublic
                  ? 'Aparece no link de acompanhamento, com data e hora.'
                  : 'Fica só para a equipe — o cliente não vê.',
            ),
          ),
        ],
      ),
    );
  }
}
