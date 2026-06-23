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
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final spec in specs) _widgetFor(spec.kind),
          ],
        ),
      ],
    );
  }

  Widget _widgetFor(DashboardWidgetKind kind) {
    switch (kind) {
      case DashboardWidgetKind.osManagement:
        return const OsManagementWidget();
      case DashboardWidgetKind.osOperational:
        return const OsOperationalWidget();
      case DashboardWidgetKind.inventory:
        return const InventoryWidget();
      case DashboardWidgetKind.customers:
        return const CustomersWidget();
    }
  }
}
