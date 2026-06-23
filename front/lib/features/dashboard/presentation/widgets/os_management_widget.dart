import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../dashboard_providers.dart';
import 'metric_card.dart';
import 'status_donut.dart';

/// OS — visão gerencial (owner/gerente, `report.read`): faturamento do período,
/// OS por status (donut), ticket médio, em execução, atrasadas, ciclo médio.
class OsManagementWidget extends ConsumerWidget {
  const OsManagementWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(osManagementMetricsProvider);
    return MetricCard(
      title: 'Ordens de Serviço',
      icon: Icons.build_outlined,
      accent: AppColors.brand,
      child: async.when(
        loading: () => const MetricLoading(),
        error: (_, _) => MetricError(
          onRetry: () => ref.invalidate(osManagementMetricsProvider),
        ),
        data: (m) {
          if (m.totalOrders == 0) {
            return const MetricEmpty();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusDonut(byStatus: m.byStatus),
              const SizedBox(height: 18),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  MetricStat(
                    label: 'Faturamento',
                    value: formatMoney(m.revenue),
                    valueColor: AppColors.success,
                  ),
                  MetricStat(
                    label: 'Ticket médio',
                    value: formatMoney(m.avgTicket),
                  ),
                  MetricStat(
                    label: 'Em execução',
                    value: '${m.inExecution}',
                  ),
                  MetricStat(
                    label: 'Atrasadas',
                    value: '${m.overdue}',
                    valueColor:
                        m.overdue > 0 ? AppColors.danger : null,
                  ),
                  MetricStat(
                    label: 'Tempo médio de ciclo',
                    value: formatCycle(m.avgCycleMs),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
