import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../dashboard_providers.dart';
import 'metric_card.dart';

/// Estoque (`inventory.read`): abaixo do mínimo (contagem + lista curta),
/// produtos/serviços ativos e, quando [showValue] (usuário com `report.read`),
/// o valor em estoque. Point-in-time (ignora o período).
class InventoryWidget extends ConsumerWidget {
  const InventoryWidget({super.key, this.showValue = true});

  /// Exibe a métrica monetária "Valor em estoque". Falso para papéis sem
  /// visibilidade gerencial (mecânico/caixa): mostra o que repor, não o quanto vale.
  final bool showValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inventoryMetricsProvider);
    final scheme = Theme.of(context).colorScheme;
    return MetricCard(
      title: 'Estoque',
      icon: Icons.inventory_2_outlined,
      accent: AppColors.info,
      child: async.when(
        loading: () => const MetricLoading(),
        error: (_, _) => MetricError(
          onRetry: () => ref.invalidate(inventoryMetricsProvider),
        ),
        data: (m) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  MetricStat(
                    label: 'Abaixo do mínimo',
                    value: '${m.belowMin}',
                    valueColor: m.belowMin > 0 ? AppColors.warning : null,
                  ),
                  if (showValue)
                    MetricStat(
                      label: 'Valor em estoque',
                      value: formatMoney(m.stockValue),
                      valueColor: AppColors.success,
                    ),
                  MetricStat(label: 'Produtos', value: '${m.products}'),
                  MetricStat(label: 'Serviços', value: '${m.services}'),
                ],
              ),
              if (m.lowStockSample.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Repor em breve',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final item in m.lowStockSample.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 15, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${formatQty(item.currentStock)}/${formatQty(item.minStock)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
