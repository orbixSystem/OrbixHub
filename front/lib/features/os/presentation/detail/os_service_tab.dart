import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/offline/widgets/offline_notices.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/os_models.dart';
import '../os_providers.dart';
import 'os_detail_shared.dart';

/// Aba **Serviço**: o problema e a conclusão — o que o cliente relatou e o que
/// a oficina diagnosticou. São pergunta e resposta, e por isso ficam juntos;
/// o relato vivia solto entre os "fatos" do cabeçalho, longe da conclusão
/// técnica que responde a ele.
///
/// O que se COBRA saiu daqui para a aba Itens: lançar peça é outra tarefa, com
/// outro ritmo, e misturá-la com o texto do diagnóstico fazia a aba inicial
/// carregar duas coisas que nunca se fazem ao mesmo tempo.
class OsServiceTab extends StatelessWidget {
  const OsServiceTab({super.key, required this.order, required this.canWrite});

  final ServiceOrder order;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ComplaintCard(order: order),
        const SizedBox(height: 20),
        _DiagnosisSection(order: order, canWrite: canWrite),
      ],
    );
  }
}

/// O relato do cliente (somente leitura aqui — edita-se na ficha da OS).
class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final relato = order.complaint?.trim() ?? '';
    return OsSectionCard(
      icon: Icons.record_voice_over_outlined,
      title: 'Relato do cliente',
      glyphIndex: 3,
      child: Text(
        relato.isEmpty ? 'Sem relato registrado.' : relato,
        style: TextStyle(
          color: relato.isEmpty ? neu.inkFaint : neu.ink,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Diagnóstico editável inline na ficha (não mais no dialog de edição). Mostra o
/// texto atual; ao tocar em "Editar" vira um campo de texto com "Salvar". Salvar
/// chama o PATCH da OS (`diagnosis`) e atualiza a ficha. Aparece também ao
/// cliente na página pública de acompanhamento.
class _DiagnosisSection extends ConsumerStatefulWidget {
  const _DiagnosisSection({required this.order, required this.canWrite});

  final ServiceOrder order;
  final bool canWrite;

  @override
  ConsumerState<_DiagnosisSection> createState() => _DiagnosisSectionState();
}

class _DiagnosisSectionState extends ConsumerState<_DiagnosisSection> {
  late final TextEditingController _controller;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.order.diagnosis ?? '');
  }

  @override
  void didUpdateWidget(covariant _DiagnosisSection old) {
    super.didUpdateWidget(old);
    // Reflete mudanças vindas de fora (ex.: após refresh) quando não editando.
    if (!_editing && old.order.diagnosis != widget.order.diagnosis) {
      _controller.text = widget.order.diagnosis ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final text = _controller.text.trim();
    try {
      await ref
          .read(osRepositoryProvider)
          .updateOrder(
            widget.order.id,
            OrderPatch(diagnosis: text.isEmpty ? '' : text),
          );
      ref.invalidate(orderProvider(widget.order.id));
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Diagnóstico salvo.')));
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final diagnosis = widget.order.diagnosis?.trim() ?? '';
    return OsSectionCard(
      icon: Icons.search_rounded,
      title: 'Diagnóstico',
      glyphIndex: 1,
      action: widget.canWrite && !_editing
          ? OsHeaderAction(
              icon: Icons.edit_outlined,
              label: diagnosis.isEmpty ? 'Adicionar' : 'Editar',
              onTap: () => setState(() => _editing = true),
            )
          : null,
      // Offline o diagnóstico é salvo no aparelho e sobe no replay do outbox.
      notice: const OfflinePendingNotice(),
      child: _editing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeuTextField(
                  controller: _controller,
                  label: 'Diagnóstico técnico (visível ao cliente)',
                  hint: 'Descreva o que foi identificado no veículo.',
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 500,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeuButton(
                      label: 'Cancelar',
                      kind: NeuButtonKind.secondary,
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _editing = false;
                              _controller.text = widget.order.diagnosis ?? '';
                            }),
                    ),
                    const SizedBox(width: 10),
                    NeuButton(
                      label: 'Salvar',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ],
            )
          : Text(
              diagnosis.isEmpty ? 'Sem diagnóstico ainda.' : diagnosis,
              style: TextStyle(
                color: diagnosis.isEmpty ? neu.inkFaint : neu.ink,
                fontSize: 15,
                height: 1.4,
              ),
            ),
    );
  }
}

