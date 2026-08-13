import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../features/dashboard/presentation/widgets/metric_card.dart'
    show formatMoney;
import 'chart_common.dart';

/// Um ponto de uma série temporal (eixo X = data, eixo Y = valor).
class OrbixTimePoint {
  const OrbixTimePoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// Gráfico de linha/área para séries temporais (ex.: evolução do faturamento por
/// dia). Eixos com grid, rótulos de moeda/quantidade (pt-BR) no Y e datas
/// "dd/MM" no X, área preenchida com a cor primária e tooltip ao tocar/passar
/// (data + valor exato). Responsivo (preenche a largura do pai).
///
/// Trate os estados degenerados FORA daqui: 0 pontos → [ChartEmptyState]; 1
/// ponto → [ChartSinglePoint] (uma linha solta não tem contexto). Este widget
/// assume `points.length >= 2`.
class OrbixLineChart extends StatelessWidget {
  const OrbixLineChart({
    super.key,
    required this.points,
    this.currency = true,
  });

  final List<OrbixTimePoint> points;

  /// Formata Y como moeda (R$) no eixo e no tooltip; senão, quantidade.
  final bool currency;

  String _formatValue(double v) =>
      currency ? formatMoney(v) : compactNumber(v);

  String _formatAxis(double v) =>
      currency ? compactMoney(v) : compactNumber(v);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = points.fold<double>(0, (a, p) => p.value > a ? p.value : a);
    // Headroom de 20% para a série não encostar no topo; nunca 0 (eixo precisa
    // de uma escala).
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final yInterval = maxY / 4;

    // Quantos rótulos de data cabem sem se atropelar (alvo ~6).
    final labelEvery = (points.length / 6).ceil().clamp(1, points.length);

    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].value),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                // Evita duplicar o rótulo do topo (encavalado na borda).
                if (value > maxY - yInterval / 2) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _formatAxis(value),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                // Só desenha 1 a cada [labelEvery], garantindo o último.
                final isLast = i == points.length - 1;
                if (i % labelEvery != 0 && !isLast) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    axisDayMonth(points[i].date),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (barData, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: scheme.primary, strokeWidth: 1.5),
                FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: scheme.surface,
                    strokeWidth: 2.5,
                    strokeColor: scheme.primary,
                  ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${tooltipDate(points[s.x.toInt()].date)}\n',
                  TextStyle(
                    color: scheme.onInverseSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: _formatValue(s.y),
                      style: TextStyle(
                        color: scheme.onInverseSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            preventCurveOverShooting: true,
            color: scheme.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: points.length <= 14,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: scheme.surface,
                strokeWidth: 2,
                strokeColor: scheme.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: 0.28),
                  scheme.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
