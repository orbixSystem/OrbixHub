import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_common.dart';

/// Uma fatia do donut (categoria → valor + cor).
class OrbixDonutSlice {
  const OrbixDonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// Donut (pizza com furo) + legenda lateral, para distribuições por categoria
/// (ex.: OS por status). Mostra um total no centro e a legenda com valor por
/// fatia. Tema-aware (cores vêm das fatias; texto via `colorScheme`),
/// responsivo (a legenda ocupa o espaço restante) e com tooltip ao tocar/passar
/// (categoria + valor). Estado vazio é tratado fora.
class OrbixDonutChart extends StatelessWidget {
  const OrbixDonutChart({
    super.key,
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
  });

  final List<OrbixDonutSlice> slices;
  final String centerValue;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = slices.where((s) => s.value > 0).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A legenda ao lado lista categoria e valor em texto real: o
              // desenho é redundante e sai da árvore de acessibilidade.
              ChartSemantics(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    pieTouchData: PieTouchData(enabled: true),
                    sections: [
                      for (final s in visible)
                        PieChartSectionData(
                          value: s.value.toDouble(),
                          color: s.color,
                          radius: 18,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerValue,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    centerLabel,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
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
              for (final s in visible)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.label,
                          style: const TextStyle(fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${s.value}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
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
