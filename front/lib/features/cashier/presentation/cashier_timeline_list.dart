import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../expenses/presentation/expense_detail_dialog.dart';
import '../../os/presentation/os_detail_dialog.dart';
import '../../os/presentation/payment_status.dart';
import '../../receivables/domain/receivables_models.dart';
import '../../receivables/presentation/receive_title_dialog.dart';
import '../../sale/domain/sale_models.dart';
import '../../sale/presentation/sale_detail_dialog.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import '../domain/sale_summary.dart';
import '../domain/cashier_timeline.dart';
import 'cashier_providers.dart';
import 'entry_edit_dialogs.dart';

/// Histórico do caixa: UMA lista com tudo que aconteceu, cada linha detalhada.
///
/// Sem abas e sem escolher lente — venda, despesa, sangria, suprimento e
/// recebimento convivem na mesma ordem cronológica, porque é assim que o dia
/// aconteceu. Venda em fiado aparece aqui mesmo não tendo movido o caixa: era
/// justamente o que um extrato de lançamentos escondia.
class CashierTimelineList extends ConsumerWidget {
  const CashierTimelineList({
    super.key,
    required this.events,
    this.canManage = false,
  });

  final List<CashierEvent> events;

  /// `cashier.manage` — libera editar/corrigir/estornar o lançamento na linha.
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: NeuEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Nada aconteceu no período',
          message: 'Vendas, recebimentos e despesas aparecem aqui. '
              'Troque o período acima para ver outras datas.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final ev in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EventCard(event: ev, canManage: canManage),
          ),
      ],
    );
  }
}

/// `ConsumerWidget` e não `StatelessWidget`: o card de despesa abre o detalhe da
/// conta a pagar, e esse diálogo precisa de um `WidgetRef` (fala com o repositório
/// de despesas).
class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event, this.canManage = false});

  final CashierEvent event;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return event.ehVenda ? _venda(context, ref) : _lancamento(context, ref);
  }

  /// Recebimento: abre o MESMO diálogo que a aba Fiado usa — busca o saldo
  /// fresco (a `Sale` do histórico só traz `total`+`paymentStatus`, não o
  /// saldo) e deixa receber parcial ou total, igual em qualquer outra tela.
  Future<void> _receber(BuildContext context, WidgetRef ref, Sale s) async {
    // ESPERA a config (o provider é `autoDispose` e pode estar carregando):
    // ler o valor corrente devolvia `null` e o botão não fazia nada, sem dizer
    // por quê. Mesmo bug que havia no botão "Receber" da aba Fiado.
    final CashierConfig config;
    final PaymentDetail detail;
    try {
      config = (await ref.read(cashierControllerProvider.future)).config;
      detail = await ref.read(cashierRepositoryProvider).paymentSummary(
            saleKind: 'sale',
            saleId: s.id,
            total: moneyToDouble(s.total),
          );
    } on Object catch (e) {
      if (context.mounted) {
        showNeuErrorSnackBar(context, 'Não foi possível abrir o caixa: $e');
      }
      return;
    }
    if (!context.mounted) return;
    await showReceiveTitleDialog(
      context,
      ref,
      config: config,
      title: ReceivableTitle(
        id: s.id,
        origin: 'sale',
        number: s.number,
        total: detail.total,
        paid: detail.paid,
        balance: detail.balance,
        status: detail.status,
      ),
    );
    // A linha que chamou isto pode ter sido desmontada enquanto o diálogo
    // estava aberto (ex.: o histórico recarregou por outro motivo).
    if (!context.mounted) return;
    ref.invalidate(cashierHistoryProvider);
  }

  // ---------------------------------------------------------------- venda
  Widget _venda(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final s = event.sale!;
    final cancelada = s.status == 'canceled';
    final podeReceber =
        canManage && !cancelada && s.paymentStatus != 'pago';
    final risco = cancelada ? TextDecoration.lineThrough : null;
    return NeuCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        onTap: () => showSaleDetailDialog(context, saleId: s.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _glifo(
                neu,
                Icons.shopping_bag_outlined,
                cancelada ? neu.inkMuted : neu.navy,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cashierEventTitle(event),
                            style: TextStyle(
                              color: cancelada ? neu.inkMuted : neu.ink,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              decoration: risco,
                            ),
                          ),
                        ),
                        Text(
                          formatMoney(s.total),
                          style: TextStyle(
                            color: cancelada ? neu.inkMuted : neu.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            decoration: risco,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Para quem · quando · número
                    Text(
                      [
                        s.customerName?.isNotEmpty == true
                            ? s.customerName!
                            : 'Balcão',
                        ?fmtDataHora(s.createdAt),
                        if (s.number.isNotEmpty) s.number,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: neu.inkMuted, fontSize: 12),
                    ),
                    // O que foi vendido
                    if (s.items.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        resumoItens(s.items),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neu.inkFaint,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (cancelada)
                          NeuStatusChip(
                            label: 'Cancelada',
                            color: neu.danger,
                            tint: neu.dangerTint,
                            icon: Icons.block,
                          )
                        else
                          PaymentTag(status: s.paymentStatus, dense: true),
                        const Spacer(),
                        // Receber sem precisar ir até a aba Fiado — o dono
                        // vê a venda parcial rolando o histórico do dia e
                        // quer resolver ali mesmo.
                        if (podeReceber)
                          NeuButton(
                            label: 'Receber',
                            icon: Icons.payments_outlined,
                            kind: NeuButtonKind.secondary,
                            onPressed: () => _receber(context, ref, s),
                          )
                        else
                          Icon(Icons.chevron_right_rounded,
                            size: 18, color: neu.inkFaint),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- lançamento
  Widget _lancamento(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final e = event.entry!;
    final entrada = e.direction == 'in';
    final estornado = e.reversedAt != null;
    final cor = estornado ? neu.inkMuted : (entrada ? neu.success : neu.danger);
    final risco = estornado ? TextDecoration.lineThrough : null;
    // Recebimento de OS abre a ORDEM. Sem isto o card era um beco sem saída:
    // dizia "OS" e não levava a lugar nenhum, e conferir o que foi feito exigia
    // procurar a ordem à mão. A venda já abria pelo card de venda logo acima.
    final daOs = e.saleKind == 'os' && e.saleId != null;
    // Saída de conta a pagar abre a DESPESA. Sem isto o card dizia
    // "Despesa · Aluguel" e era um beco sem saída: a ida (despesa -> lançamento)
    // existia, a volta não.
    final daDespesa = e.saleKind == 'expense' && e.saleId != null;
    final corpo = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _glifo(
            neu,
            entrada ? Icons.south_west_rounded : Icons.north_east_rounded,
            cor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cashierEventTitle(event),
                        style: TextStyle(
                          color: estornado ? neu.inkMuted : neu.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          decoration: risco,
                        ),
                      ),
                    ),
                    Text(
                      '${entrada ? '+' : '−'} ${formatMoney(e.amount)}',
                      style: TextStyle(
                        color: cor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        decoration: risco,
                      ),
                    ),
                    // Despesa lançada errada é o caso mais comum de correção —
                    // e antes o histórico era só leitura, obrigando a voltar ao
                    // extrato do dia (que só mostra hoje).
                    if (canManage && !estornado)
                      EntryActionsMenu(entry: e),
                    // Afordância: sem isto nada indica que a linha de OS/despesa
                    // é clicável (a de venda já tinha o chevron equivalente).
                    if (daOs || daDespesa) ...[
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: neu.inkFaint),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    ?fmtDataHora(e.createdAt),
                    // A CATEGORIA entra aqui porque o título agora é o nome do
                    // lançamento. Sem isto, promover o nome apagava da linha a
                    // informação de que aquilo é despesa, sangria ou suprimento.
                    categoryLabel(e.category),
                    methodLabel(e.method),
                    // A descrição NÃO se repete aqui: quando existe, ela já é
                    // o título da linha.
                  ].where((t) => t.isNotEmpty).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neu.inkMuted, fontSize: 12, height: 1.3),
                ),
                if (estornado) ...[
                  const SizedBox(height: 7),
                  NeuStatusChip(
                    label: 'Estornado',
                    color: neu.inkMuted,
                    tint: neu.line,
                    icon: Icons.undo_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
    );
    if (!daOs && !daDespesa) {
      return NeuCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: corpo,
      );
    }
    return NeuCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        // OS abre em MODAL, como a venda logo acima: o histórico é uma lista
        // de consulta, e navegar para a tela cheia fazia perder o período, o
        // filtro e a posição da rolagem só para conferir o que foi feito. O
        // modal ainda oferece exportar o PDF e ir para a OS completa.
        onTap: daOs
            ? () => showOsDetailDialog(context, orderId: e.saleId!)
            : () => showExpenseDetailDialog(context, ref, id: e.saleId!),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: corpo,
        ),
      ),
    );
  }

  Widget _glifo(NeuTokens neu, IconData icone, Color cor) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .14),
        shape: BoxShape.circle,
      ),
      child: Icon(icone, size: 18, color: cor),
    );
  }
}
