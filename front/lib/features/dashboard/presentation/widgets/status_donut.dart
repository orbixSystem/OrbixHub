import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../os/presentation/os_status.dart';

/// Donut de "OS por status" + legenda. Usa as cores/rótulos do módulo OS.
class StatusDonut extends StatelessWidget {
  const StatusDonut({super.key, required this.byStatus});

  final Map<String, int> byStatus;

  @override
  Widget build(BuildContext context) {
    final entries = byStatus.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    if (total == 0) {
      final scheme = Theme.of(context).colorScheme;
      return SizedBox(
        height: 120,
        child: Center(
          child: Text('Nenhuma OS no período.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value.toDouble(),
                        color: osStatusColor(e.key),
                        radius: 18,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$total',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('OS',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: osStatusColor(e.key),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          osStatusLabel(e.key),
                          style: const TextStyle(fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${e.value}',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
