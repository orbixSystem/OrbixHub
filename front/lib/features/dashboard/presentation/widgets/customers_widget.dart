import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../dashboard_providers.dart';
import 'metric_card.dart';

/// Clientes (`customer.read`): total ativo + novos no período.
class CustomersWidget extends ConsumerWidget {
  const CustomersWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customersMetricsProvider);
    return MetricCard(
      title: 'Clientes',
      icon: Icons.people_alt_outlined,
      accent: AppColors.success,
      child: async.when(
        loading: () => const MetricLoading(),
        error: (_, _) => MetricError(
          onRetry: () => ref.invalidate(customersMetricsProvider),
        ),
        data: (m) {
          return Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              MetricStat(label: 'Clientes ativos', value: '${m.active}'),
              MetricStat(
                label: 'Novos no período',
                value: '${m.newInRange}',
                valueColor: m.newInRange > 0 ? AppColors.success : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
