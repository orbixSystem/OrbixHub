import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../os/presentation/payment_status.dart';
import '../../sale/domain/sale_models.dart';
import '../../sale/presentation/sale_detail_dialog.dart';
import '../domain/cashier_format.dart';

/// Histórico de VENDAS do período — "o que vendi, para quem, quando".
///
/// É uma lente diferente do extrato: o extrato é o livro-caixa (movimento de
/// dinheiro, inclusive despesas e sangrias), enquanto aqui a unidade é a VENDA.
/// Uma venda em fiado não gera movimento nenhum no caixa e por isso jamais
/// apareceria no extrato — mas aparece aqui, que é o ponto.
///
/// Cada linha abre o detalhe (itens, recebimentos, cancelar-e-refazer).
class SalesHistoryList extends ConsumerWidget {
  const SalesHistoryList({super.key, required this.sales});

  final List<Sale> sales;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sales.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: NeuEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Nenhuma venda no período',
          message: 'Troque o período acima para ver outras datas.',
        ),
      );
    }
    // Mais recente primeiro (o backend já ordena por created_at desc).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResumoVendas(sales: sales),
        const SizedBox(height: 12),
        for (final s in sales)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SaleTile(sale: s),
          ),
      ],
    );
  }
}

/// Quanto foi vendido no período e quantas vendas — distinto do "recebido" do
/// extrato: vender em fiado soma aqui e não entra no caixa.
class _ResumoVendas extends StatelessWidget {
  const _ResumoVendas({required this.sales});

  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ativas = sales.where((s) => s.status != 'canceled').toList();
    final total = ativas.fold<double>(0, (a, s) => a + moneyToDouble(s.total));
    final canceladas = sales.length - ativas.length;
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 28,
        runSpacing: 12,
        children: [
          _stat(neu, 'Vendido', formatMoney(total), neu.ink),
          _stat(
            neu,
            ativas.length == 1 ? 'venda' : 'vendas',
            '${ativas.length}',
            neu.ink,
          ),
          if (canceladas > 0)
            _stat(neu, 'canceladas', '$canceladas', neu.danger),
        ],
      ),
    );
  }

  Widget _stat(NeuTokens neu, String label, String valor, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valor,
          style: TextStyle(color: cor, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(label, style: TextStyle(color: neu.inkMuted, fontSize: 12)),
      ],
    );
  }
}

/// Uma venda: quando, para quem, o que, quanto e situação do pagamento.
class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cancelada = sale.status == 'canceled';
    return NeuCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        onTap: () => showSaleDetailDialog(context, saleId: sale.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      // "para quem": o snapshot do cliente na venda; balcão sem
                      // cliente identificado é a norma, não um erro.
                      sale.customerName?.isNotEmpty == true
                          ? sale.customerName!
                          : 'Venda no balcão',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cancelada ? neu.inkMuted : neu.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration:
                            cancelada ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatMoney(sale.total),
                    style: TextStyle(
                      color: cancelada ? neu.inkMuted : neu.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      decoration: cancelada ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // "quando" + número + "o que" (resumo dos itens).
              Text(
                [
                  ?fmtDataHora(sale.createdAt),
                  sale.number.isEmpty ? null : sale.number,
                  resumoItens(sale.items),
                ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: neu.inkMuted, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 8),
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
                    PaymentTag(status: sale.paymentStatus, dense: true),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: neu.inkFaint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "o que foi vendido" em uma linha: os primeiros itens + "e mais N".
/// Preferido a mostrar só a contagem — "2× Óleo, Alinhamento" diz muito mais que
/// "3 itens" para quem está procurando uma venda no histórico.
String resumoItens(List<SaleItem> items, {int mostrar = 2}) {
  if (items.isEmpty) return '';
  final partes = <String>[];
  for (final i in items.take(mostrar)) {
    final q = _qtd(i.quantity);
    partes.add(q == '1' ? i.name : '$q× ${i.name}');
  }
  final resto = items.length - partes.length;
  if (resto > 0) partes.add('e mais $resto');
  return partes.join(', ');
}

/// "03/08 14:32" (local), ou null se não houver data.
String? fmtDataHora(String? iso) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

/// Quantidade sem casas decimais inúteis ("4" em vez de "4,000").
String _qtd(String raw) {
  final v = double.tryParse(raw.replaceAll(',', '.'));
  if (v == null) return raw;
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
