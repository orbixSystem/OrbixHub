import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'neu_card.dart';
import 'neu_tokens.dart';

/// Cartão de gráfico do design system: título + área do gráfico (altura fixa)
/// dentro de um [NeuCard]. Padroniza o enquadramento de qualquer chart.
class NeuChartCard extends StatelessWidget {
  const NeuChartCard({
    super.key,
    required this.title,
    required this.child,
    this.height = 220,
    this.trailing,
  });

  final String title;
  final Widget child;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: neu.ink),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

/// Barra vertical temática (gradiente do acento) para séries — usada em todos
/// os BarChart do app, mantendo cor/raio/gradiente consistentes.
BarChartRodData neuBarRod(
  BuildContext context,
  double value, {
  double width = 12,
  Color? color,
}) {
  final neu = context.neu;
  final c = color ?? neu.accent;
  return BarChartRodData(
    toY: value,
    width: width,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
    gradient: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [c.withValues(alpha: .55), c],
    ),
  );
}

/// Tooltip padrão (superfície neu, texto claro) para os gráficos de barra.
BarTouchData neuBarTouch(
  BuildContext context, {
  required String Function(int index, double value) label,
}) {
  final neu = context.neu;
  return BarTouchData(
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => neu.navy,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
        label(group.x, rod.toY),
        TextStyle(
          color: neu.onNavy,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    ),
  );
}
