import 'package:flutter/material.dart';

import '../../auth/domain/auth_models.dart';
import 'dashboard_registry.dart';
import 'widgets/customers_widget.dart';
import 'widgets/inventory_widget.dart';
import 'widgets/os_management_widget.dart';
import 'widgets/os_operational_widget.dart';
import 'widgets/period_selector.dart';

/// Bloco de métricas do dashboard: seletor de período + os widgets que `me`
/// pode ver (via `dashboardWidgets`, role-aware). Cada widget tem seu provider
/// (loading/erro/empty próprios). Não renderiza nada se não houver widgets.
class DashboardMetricsSection extends StatelessWidget {
  const DashboardMetricsSection({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    final specs = dashboardWidgets(me);
    if (specs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Visão geral',
                style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 14),
        const PeriodSelector(),
        const SizedBox(height: 18),
        // Grid responsivo: colunas calculadas pela largura disponível
        // (mín. ~330px por card); no mobile vira 1 coluna cheia.
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 16.0;
            const minCol = 330.0;
            final cols = (constraints.maxWidth / (minCol + gap))
                .floor()
                .clamp(1, 3);
            final colW =
                (constraints.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final spec in specs)
                  SizedBox(width: colW, child: _widgetFor(spec)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _widgetFor(DashboardWidgetSpec spec) {
    switch (spec.kind) {
      case DashboardWidgetKind.osManagement:
        return const OsManagementWidget();
      case DashboardWidgetKind.osOperational:
        return const OsOperationalWidget();
      case DashboardWidgetKind.inventory:
        return InventoryWidget(showValue: spec.showValue);
      case DashboardWidgetKind.customers:
        return const CustomersWidget();
    }
  }
}
