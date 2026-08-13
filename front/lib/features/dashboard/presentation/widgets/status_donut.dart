import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../os/presentation/os_status.dart';

/// Donut de "OS por status" + legenda. Usa as cores/rótulos do módulo OS
/// (paleta violeta/azul/verde do redesign — sem laranja).
class StatusDonut extends StatelessWidget {
  const StatusDonut({super.key, required this.byStatus});

  final Map<String, int> byStatus;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final entries = byStatus.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    if (total == 0) {
      return SizedBox(
        height: 130,
        child: Center(
          child: Text('Nenhuma OS no período.',
              style: TextStyle(color: neu.inkMuted)),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 42,
                  startDegreeOffset: -90,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value.toDouble(),
                        color: osStatusColor(e.key),
                        radius: 16,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: neu.ink),
                  ),
                  Text('OS',
                      style: TextStyle(color: neu.inkMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          // Swatch de 10px é identificador (piso 3:1), não a
                          // área grande da fatia — daí a variante legível.
                          color: osStatusInk(
                              e.key, Theme.of(context).brightness),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          osStatusLabel(e.key),
                          style:
                              TextStyle(fontSize: 12.5, color: neu.inkMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${e.value}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: neu.ink,
                        ),
                      ),
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
