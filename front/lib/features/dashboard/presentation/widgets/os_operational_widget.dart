import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../dashboard_providers.dart';
import 'metric_card.dart';
import 'status_donut.dart';

/// OS — visão operacional (mecânico, sem `report.read`): "Minhas OS" por status
/// (o provider passa `assignedTo = me.user.id`), minhas em execução e atrasadas.
class OsOperationalWidget extends ConsumerWidget {
  const OsOperationalWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(osOperationalMetricsProvider);
    return MetricCard(
      title: 'Minhas OS',
      icon: Icons.assignment_ind_outlined,
      accent: AppColors.brand,
      child: async.when(
        loading: () => const MetricLoading(),
        error: (_, _) => MetricError(
          onRetry: () => ref.invalidate(osOperationalMetricsProvider),
        ),
        data: (m) {
          if (m.totalOrders == 0) {
            return const MetricEmpty(message: 'Você não tem OS no período.');
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
                    label: 'Em execução',
                    value: '${m.inExecution}',
                  ),
                  MetricStat(
                    label: 'Atrasadas',
                    value: '${m.overdue}',
                    valueColor: m.overdue > 0 ? AppColors.danger : null,
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
