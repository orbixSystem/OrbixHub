import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../os/presentation/payment_status.dart';
import '../../sale/presentation/sale_detail_dialog.dart';
import '../domain/cashier_format.dart';
import '../domain/sale_summary.dart';
import '../domain/cashier_timeline.dart';

/// Histórico do caixa: UMA lista com tudo que aconteceu, cada linha detalhada.
///
/// Sem abas e sem escolher lente — venda, despesa, sangria, suprimento e
/// recebimento convivem na mesma ordem cronológica, porque é assim que o dia
/// aconteceu. Venda em fiado aparece aqui mesmo não tendo movido o caixa: era
/// justamente o que um extrato de lançamentos escondia.
class CashierTimelineList extends ConsumerWidget {
  const CashierTimelineList({super.key, required this.events});

  final List<CashierEvent> events;

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
            child: _EventCard(event: ev),
          ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final CashierEvent event;

  @override
  Widget build(BuildContext context) {
    return event.ehVenda ? _venda(context) : _lancamento(context);
  }

  // ---------------------------------------------------------------- venda
  Widget _venda(BuildContext context) {
    final neu = context.neu;
    final s = event.sale!;
    final cancelada = s.status == 'canceled';
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
                          fontSize: 11.5,
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
  Widget _lancamento(BuildContext context) {
    final neu = context.neu;
    final e = event.entry!;
    final entrada = e.direction == 'in';
    final estornado = e.reversedAt != null;
    final cor = estornado ? neu.inkMuted : (entrada ? neu.success : neu.danger);
    final risco = estornado ? TextDecoration.lineThrough : null;
    final descricao = e.description?.trim() ?? '';
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
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
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    ?fmtDataHora(e.createdAt),
                    methodLabel(e.method),
                    if (descricao.isNotEmpty) descricao,
                  ].join(' · '),
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
