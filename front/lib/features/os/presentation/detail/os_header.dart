import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/offline/widgets/offline_notices.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/vertical/vertical_providers.dart';
import '../../../../di.dart';
import '../../../invoice/presentation/invoice_providers.dart';
import '../../../invoice/presentation/invoice_status.dart';
import '../../domain/os_models.dart';
import '../os_quick_actions.dart';
import '../os_providers.dart';
import '../os_status.dart';
import '../payment_status.dart';

/// Cabeçalho do detalhe da OS: **quem, o quê e em que pé está** — nada mais.
///
/// O timbre da empresa (logo + razão social + CNPJ) saiu daqui: numa tela
/// interna quem está logado já sabe em qual oficina está, e o timbre é o topo
/// do PDF, não da ficha. Os "fatos" que sobraram foram hierarquizados —
/// cliente e veículo IDENTIFICAM a OS (linha forte), responsável e previsão
/// são contexto (linha discreta). O relato do cliente foi para a aba Serviço,
/// ao lado do diagnóstico, porque um é a resposta do outro.
class OsDetailHeader extends StatelessWidget {
  const OsDetailHeader({
    super.key,
    required this.order,
    required this.actions,
  });

  final ServiceOrder order;

  /// Barra de ações — montada pelo chamador (depende de permissões).
  final Widget actions;

  String _fmtCurto(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}';
  }

  /// "10/08 → 15/08", ou só uma das pontas quando a outra não existe.
  String? get _previsao {
    final ini = order.scheduledStart;
    final fim = order.scheduledEnd;
    if (ini == null && fim == null) return null;
    if (ini != null && fim != null) {
      return '${_fmtCurto(ini)} → ${_fmtCurto(fim)}';
    }
    return _fmtCurto((ini ?? fim)!);
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isMobile = context.isMobile;
    // Identificação: cliente e veículo numa linha só, separados por ponto —
    // juntos eles respondem "que OS é essa" antes de qualquer outra coisa.
    final identidade = [
      ?order.customerName,
      if ((order.subjectLabel ?? '').isNotEmpty) order.subjectLabel!,
    ].join(' · ');
    // Contexto: quem toca e para quando. Importa, mas não é o que identifica.
    final contexto = [
      if ((order.assignedToName ?? '').isNotEmpty) order.assignedToName!,
      if (_previsao != null) 'Previsão $_previsao',
    ].join(' · ');

    return NeuCard(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuIconChip.glyph(
                context,
                icon: Icons.build_rounded,
                index: 0,
                size: isMobile ? 44 : 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Situação ANTES do número, na mesma linha: lê-se "esta OS
                    // em andamento é a OS-0042". Antes os selos ficavam soltos
                    // na outra ponta do card, desligados do que qualificavam.
                    // `Wrap` para o número descer de linha em vez de estourar
                    // quando os selos comem a largura no celular.
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusSelect(order: order),
                        if (order.payment != null && order.payment!.total > 0)
                          PaymentTag(status: order.paymentStatus, dense: true),
                        if (isPendingOsNumber(order.number))
                          SyncRowBadge(entity: 'service_order', id: order.id),
                        Text(
                          order.number,
                          maxLines: 1,
                          style: TextStyle(
                            color: neu.ink,
                            fontSize: isMobile ? 20 : 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    if (identidade.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        identidade,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (contexto.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contexto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              // O TOTAL ocupa o canto que era dos selos soltos. Era a única
              // informação do antigo card "Resumo financeiro" que se consulta
              // o tempo todo — aqui está sempre à vista, sem custar uma seção.
              //
              // Só no DESKTOP, porém: em 360px ele e o chip de status disputam
              // a mesma linha e o chip é quem perde (ficava espremido até
              // estourar). No celular o total desce para uma linha própria,
              // onde tem a largura toda.
              if (!isMobile) ...[
                const SizedBox(width: 10),
                _Total(order: order, grande: true),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            _Total(order: order, grande: false),
          ],
          const SizedBox(height: 16),
          actions,
        ],
      ),
    );
  }
}

/// O total da OS. No desktop é uma coluna à direita da identidade; no celular,
/// uma faixa de largura inteira logo abaixo dela.
class _Total extends StatelessWidget {
  const _Total({required this.order, required this.grande});

  final ServiceOrder order;
  final bool grande;

  /// Recebeu parte, ainda deve o resto.
  bool get _parcial {
    final p = order.payment;
    return p != null && p.paid > 0 && p.balance > 0;
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final rotulo = Text(
      'Total',
      style: TextStyle(
        color: neu.inkFaint,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
    final numero = Text(
      money(order.total),
      maxLines: 1,
      style: TextStyle(
        color: neu.navy,
        fontSize: grande ? 21 : 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    );
    // Quanto ainda falta — o número que se procura para cobrar. Fica junto do
    // total (não numa seção à parte) porque só faz sentido em relação a ele.
    final falta = !_parcial
        ? null
        : Text(
            'Falta ${money(order.payment!.balance.toString())} · '
            'pago ${money(order.payment!.paid.toString())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: neu.warning,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          );
    if (grande) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          rotulo,
          const SizedBox(height: 2),
          numero,
          if (falta != null) ...[const SizedBox(height: 2), falta],
        ],
      );
    }
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [rotulo, const Spacer(), numero]),
          if (falta != null) ...[
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: falta),
          ],
        ],
      ),
    );
  }
}

/// Seletor de status da OS: chip com o status REAL (não o simplificado) e
/// dropdown para trocar. `sem_conserto` só aparece se a vertical não for
/// `veiculos` (não se aplica a carros). Transições inválidas não aparecem.
class _StatusSelect extends ConsumerStatefulWidget {
  const _StatusSelect({required this.order});
  final ServiceOrder order;

  @override
  ConsumerState<_StatusSelect> createState() => _StatusSelectState();
}

class _StatusSelectState extends ConsumerState<_StatusSelect> {
  bool _busy = false;

  Future<void> _changeStatus(String newStatus) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(osRepositoryProvider).changeStatus(
            widget.order.id,
            newStatus,
          );
      if (!mounted) return;
      ref.invalidate(orderProvider(widget.order.id));
      ref.invalidate(orderListProvider);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order.status;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = osStatusColor(status);
    final ink = osStatusInk(status, Theme.of(context).brightness);
    final vertical = ref.watch(verticalProvider);

    // Transições válidas, filtrando sem_conserto para veículos.
    var targets = osTransitions[status] ?? const <String>[];
    if (vertical == 'veiculos') {
      targets = targets.where((s) => s != 'sem_conserto').toList();
    }
    final canChange = targets.isNotEmpty && !_busy;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? .22 : .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: ink),
            )
          else
            Icon(osStatusIcon(status), size: 13, color: ink),
          const SizedBox(width: 5),
          Text(
            osStatusLabel(status),
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (canChange) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 16, color: ink),
          ],
        ],
      ),
    );

    if (!canChange) return chip;

    final neu = context.neu;
    return PopupMenuButton<String>(
      tooltip: 'Alterar status',
      color: neu.surface,
      position: PopupMenuPosition.under,
      onSelected: _changeStatus,
      itemBuilder: (_) => [
        // Status atual (desabilitado, para contexto).
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              Icon(osStatusIcon(status), size: 16,
                  color: osStatusColor(status)),
              const SizedBox(width: 10),
              Text(
                osStatusLabel(status),
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(Icons.check_rounded, size: 16, color: neu.inkMuted),
            ],
          ),
        ),
        const PopupMenuDivider(),
        // Destinos válidos.
        for (final target in targets)
          PopupMenuItem(
            value: target,
            child: Row(
              children: [
                Icon(osStatusIcon(target), size: 16,
                    color: osStatusColor(target)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    osStatusLabel(target),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: target == 'cancelada' ? neu.danger : neu.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: chip,
    );
  }
}

/// Barra de ações da OS: **uma ação primária, rotulada, e o resto num menu**.
///
/// Antes eram até oito botões concorrendo em pé de igualdade (Finalizar,
/// Cancelar, Receber, Pagamentos, PDF, Editar, Mensagens, Emitir NF) e, no
/// celular, todos viravam ícones sem rótulo — "o que faz esse ✓?" é uma
/// pergunta cara quando a resposta é "encerra a OS". Aqui a ação do momento
/// (finalizar, ou reabrir) fica em destaque e escrita por extenso; receber
/// pagamento acompanha quando há saldo, porque é a outra coisa que se faz com
/// o cliente na frente; todo o resto — inclusive as destrutivas — mora atrás
/// de "Mais", onde não se toca por engano.
class OsActionBar extends ConsumerStatefulWidget {
  const OsActionBar({
    super.key,
    required this.order,
    required this.canWrite,
    required this.canApprove,
    required this.canEdit,
    required this.canRead,
    required this.canIssueInvoice,
    required this.onEdit,
    required this.onExport,
  });

  final ServiceOrder order;
  final bool canWrite;
  final bool canApprove;

  /// `os.write` E a OS não está em estado terminal.
  final bool canEdit;
  final bool canRead;
  final bool canIssueInvoice;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  @override
  ConsumerState<OsActionBar> createState() => _OsActionBarState();
}

class _OsActionBarState extends ConsumerState<OsActionBar> {
  bool _busy = false;

  ServiceOrder get order => widget.order;

  bool _habilitado(OsSimpleStatus destino) {
    if (_busy) return false;
    return osSimpleTransitionEnabled(
      order,
      destino,
      canWrite: widget.canWrite,
      canApprove: widget.canApprove,
    );
  }

  Future<void> _transicao(OsSimpleStatus destino) async {
    if (!_habilitado(destino)) return;
    await runOsSimpleTransition(
      context,
      ref,
      order,
      destino,
      onWillApply: () => setState(() => _busy = true),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _emitirNota() async {
    if (_busy) return;
    // Já existe nota ativa? Então o caminho é VER, não emitir de novo (e bater
    // no 409 do servidor).
    final ativa = _notaAtiva();
    if (ativa != null) {
      context.go('/m/invoice/${ativa.id}');
      return;
    }
    setState(() => _busy = true);
    try {
      final invoice =
          await ref.read(invoiceRepositoryProvider).issue(orderId: order.id);
      // Guard depois do await: o widget pode ter sido descartado enquanto a
      // chamada estava em voo (sair da tela, fechar o diálogo, trocar de OS).
      if (!mounted) return;
      ref.invalidate(orderInvoicesProvider(order.id));
      context.go('/m/invoice/${invoice.id}');
    } on AppException catch (e) {
      if (mounted) showNeuErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Nota fiscal em estado que impede emitir outra (rascunho/processando/
  /// autorizada), se houver.
  dynamic _notaAtiva() {
    final page = ref.watch(orderInvoicesProvider(order.id)).asData?.value;
    final ativas = (page?.items ?? const []).where(
      (i) =>
          i.status == 'draft' ||
          i.status == 'processing' ||
          i.status == 'authorized',
    );
    return ativas.isEmpty ? null : ativas.first;
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (_busy) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: neu.inkMuted),
          ),
          const SizedBox(width: 10),
          Text(
            'Atualizando…',
            style: TextStyle(color: neu.inkMuted, fontSize: 14),
          ),
        ],
      );
    }

    // --- ação primária: o verbo do momento ---
    ({String label, IconData icon, VoidCallback onTap})? primaria;
    if (order.status == 'cancelada') {
      if (_habilitado(OsSimpleStatus.emAndamento)) {
        primaria = (
          label: 'Reabrir OS',
          icon: Icons.undo_rounded,
          onTap: () => _transicao(OsSimpleStatus.emAndamento),
        );
      }
    } else if (order.status != 'entregue' &&
        _habilitado(OsSimpleStatus.finalizada)) {
      primaria = (
        label: 'Finalizar OS',
        icon: Icons.check_circle_rounded,
        onTap: () => _transicao(OsSimpleStatus.finalizada),
      );
    }

    // Não há botão de RECEBER aqui, de propósito: dinheiro entra pelo Caixa e
    // só por lá (histórico ou fiado). A ficha da OS continua mostrando a
    // situação do pagamento (o `PaymentTag`) e o histórico de lançamentos
    // ("Pagamentos"), que é informação — não uma segunda boca de caixa.

    // --- menu: o resto, sem competir por atenção ---
    final extras = <({String valor, String rotulo, IconData icone, bool perigo})>[
      if (widget.canRead)
        (
          valor: 'pdf',
          rotulo: 'Exportar PDF',
          icone: Icons.picture_as_pdf_outlined,
          perigo: false
        ),
      if (widget.canEdit)
        (
          valor: 'editar',
          rotulo: 'Editar OS',
          icone: Icons.edit_outlined,
          perigo: false
        ),
      if ((order.conversationId ?? '').isNotEmpty)
        (
          valor: 'mensagens',
          rotulo: 'Mensagens',
          icone: Icons.forum_outlined,
          perigo: false
        ),
      if (canViewOsPayments(ref, order))
        (
          valor: 'pagamentos',
          rotulo: 'Pagamentos',
          icone: Icons.receipt_long_outlined,
          perigo: false
        ),
      if (widget.canIssueInvoice)
        (
          valor: 'nota',
          rotulo: _notaAtiva() == null
              ? 'Emitir nota fiscal'
              : 'Nota · '
                  '${invoiceStatusLabel(_notaAtiva()!.status as String)}',
          icone: Icons.receipt_long,
          perigo: false
        ),
      // Destrutiva por último e marcada — nunca ao lado da ação primária.
      if (order.status != 'cancelada' &&
          order.status != 'entregue' &&
          _habilitado(OsSimpleStatus.cancelada))
        (
          valor: 'cancelar',
          rotulo: 'Cancelar OS',
          icone: Icons.close_rounded,
          perigo: true
        ),
    ];

    Future<void> executar(String v) async {
      switch (v) {
        case 'pdf':
          widget.onExport();
        case 'editar':
          widget.onEdit();
        case 'mensagens':
          context.push('/mensagens/${order.conversationId}');
        case 'pagamentos':
          await showOsPaymentsDialog(context, ref, order);
        case 'nota':
          await _emitirNota();
        case 'cancelar':
          await _transicao(OsSimpleStatus.cancelada);
      }
    }

    final isMobile = context.isMobile;

    final botoes = <Widget>[
      if (primaria != null)
        NeuButton(
          label: primaria.label,
          icon: primaria.icon,
          onPressed: primaria.onTap,
        ),
      // No DESKTOP sobra largura: esconder ação atrás de um menu ali só
      // adiciona um clique para descobrir o que existe. No celular a largura é
      // real e o menu volta a valer a pena.
      if (isMobile && extras.isNotEmpty)
        _MenuMais(itens: extras, onSelected: executar),
      if (!isMobile)
        for (final e in extras)
          NeuButton(
            label: e.rotulo,
            icon: e.icone,
            kind: e.perigo ? NeuButtonKind.danger : NeuButtonKind.secondary,
            onPressed: () => executar(e.valor),
          ),
    ];

    // Estado terminal: dizer POR QUE não há "Finalizar" aqui. A nota acompanha
    // os botões (não os substitui) — mesmo encerrada a OS ainda exporta PDF e
    // mostra pagamentos, então esconder a explicação só porque sobrou um menu
    // deixaria a ausência da ação principal sem resposta.
    final _Nota? nota = switch (order.status) {
      'cancelada' => _Nota(
          icon: Icons.cancel_outlined,
          color: neu.danger,
          text: 'OS cancelada.',
        ),
      'entregue' => _Nota(
          icon: Icons.verified_outlined,
          color: neu.success,
          text: 'OS entregue — somente leitura.',
        ),
      'sem_conserto' => _Nota(
          icon: Icons.block_outlined,
          color: neu.inkMuted,
          text: 'Sem conserto — entregue ou cancele.',
        ),
      _ => null,
    };

    if (botoes.isEmpty) return nota ?? const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: 10, runSpacing: 10, children: botoes),
        if (nota != null) ...[const SizedBox(height: 12), nota],
      ],
    );
  }
}

/// Menu "Mais": tudo que não é a ação do momento. Rótulos por extenso — um
/// menu é onde se procura pelo nome, não pelo desenho do ícone.
class _MenuMais extends StatelessWidget {
  const _MenuMais({required this.itens, required this.onSelected});

  final List<({String valor, String rotulo, IconData icone, bool perigo})> itens;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return PopupMenuButton<String>(
      tooltip: 'Mais ações',
      color: neu.surface,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final i in itens)
          PopupMenuItem(
            value: i.valor,
            child: Row(
              children: [
                Icon(
                  i.icone,
                  size: 18,
                  color: i.perigo ? neu.danger : neu.inkMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    i.rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: i.perigo ? neu.danger : neu.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: NeuSurface(
        elevation: NeuElevation.raised,
        radius: NeuTokens.rChip,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mais',
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 18, color: neu.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// Faixa informativa para estados terminais.
class _Nota extends StatelessWidget {
  const _Nota({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
