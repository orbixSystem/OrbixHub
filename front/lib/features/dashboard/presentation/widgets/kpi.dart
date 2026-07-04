import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../dashboard_providers.dart';
import 'metric_card.dart' show formatMoney;

/// Tile de KPI no estilo dos dashboards de apps grandes: glyph colorido, valor
/// grande, rótulo e uma legenda opcional (delta/sub). Altura consistente.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.icon,
    required this.glyphIndex,
    required this.label,
    required this.value,
    this.sub,
    this.valueColor,
    this.loading = false,
  });

  final IconData icon;
  final int glyphIndex;
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context, icon: icon, index: glyphIndex,
                  size: 38),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          if (loading)
            _Skeleton(neu: neu)
          else
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? neu.ink,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: neu.inkMuted, fontSize: 13),
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub!,
              style: TextStyle(
                color: neu.inkFaint,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.neu});
  final NeuTokens neu;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 26,
      decoration: BoxDecoration(
        color: neu.base,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Faixa de KPIs GERENCIAL: faturamento, ticket, em execução, atrasadas,
/// clientes ativos, valor em estoque. Grid responsivo de altura igual.
class ManagementKpiStrip extends ConsumerWidget {
  const ManagementKpiStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final os = ref.watch(osManagementMetricsProvider);
    final inv = ref.watch(inventoryMetricsProvider);
    final cust = ref.watch(customersMetricsProvider);
    final neu = context.neu;

    final tiles = <Widget>[
      KpiTile(
        icon: Icons.payments_outlined,
        glyphIndex: 2, // teal
        label: 'Faturamento',
        loading: os.isLoading,
        value: formatMoney(os.asData?.value.revenue ?? 0),
        valueColor: neu.success,
      ),
      KpiTile(
        icon: Icons.receipt_long_outlined,
        glyphIndex: 1,
        label: 'Ticket médio',
        loading: os.isLoading,
        value: formatMoney(os.asData?.value.avgTicket ?? 0),
      ),
      KpiTile(
        icon: Icons.build_circle_outlined,
        glyphIndex: 0,
        label: 'OS em execução',
        loading: os.isLoading,
        value: '${os.asData?.value.inExecution ?? 0}',
      ),
      KpiTile(
        icon: Icons.warning_amber_rounded,
        glyphIndex: 4,
        label: 'OS atrasadas',
        loading: os.isLoading,
        value: '${os.asData?.value.overdue ?? 0}',
        valueColor:
            (os.asData?.value.overdue ?? 0) > 0 ? neu.danger : null,
      ),
      KpiTile(
        icon: Icons.people_alt_outlined,
        glyphIndex: 3,
        label: 'Clientes ativos',
        loading: cust.isLoading,
        value: '${cust.asData?.value.active ?? 0}',
        sub: cust.asData != null && cust.asData!.value.newInRange > 0
            ? '+${cust.asData!.value.newInRange} novos'
            : null,
      ),
      KpiTile(
        icon: Icons.inventory_2_outlined,
        glyphIndex: 5,
        label: 'Valor em estoque',
        loading: inv.isLoading,
        value: formatMoney(inv.asData?.value.stockValue ?? 0),
        sub: inv.asData != null && inv.asData!.value.belowMin > 0
            ? '${inv.asData!.value.belowMin} abaixo do mínimo'
            : null,
      ),
    ];

    return _KpiGrid(tiles: tiles);
  }
}

/// Faixa de KPIs OPERACIONAL (mecânico): minhas em execução / atrasadas +
/// estoque baixo.
class OperationalKpiStrip extends ConsumerWidget {
  const OperationalKpiStrip({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final os = ref.watch(osOperationalMetricsProvider);
    final overdue = ref.watch(myOverdueOrdersProvider(userId));
    final inv = ref.watch(inventoryMetricsProvider);
    final neu = context.neu;

    final tiles = <Widget>[
      KpiTile(
        icon: Icons.build_circle_outlined,
        glyphIndex: 0,
        label: 'Minhas em execução',
        loading: os.isLoading,
        value: '${os.asData?.value.inExecution ?? 0}',
      ),
      KpiTile(
        icon: Icons.warning_amber_rounded,
        glyphIndex: 4,
        label: 'Minhas atrasadas',
        loading: overdue.isLoading,
        value: '${overdue.asData?.value.length ?? 0}',
        valueColor:
            (overdue.asData?.value.length ?? 0) > 0 ? neu.danger : null,
      ),
      KpiTile(
        icon: Icons.inventory_2_outlined,
        glyphIndex: 5,
        label: 'Itens abaixo do mínimo',
        loading: inv.isLoading,
        value: '${inv.asData?.value.belowMin ?? 0}',
      ),
    ];

    return _KpiGrid(tiles: tiles);
  }
}

/// Grid de KPIs: colunas pela largura (mín. ~190px), linhas de altura igual.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 14.0;
        final cols = (c.maxWidth / 210).floor().clamp(2, 4);
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += cols) {
          final slice = tiles.skip(i).take(cols).toList();
          rows.add(Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: gap),
                    Expanded(
                      child: j < slice.length
                          ? slice[j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ));
        }
        return Column(children: rows);
      },
    );
  }
}
