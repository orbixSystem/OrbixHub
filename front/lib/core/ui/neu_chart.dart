import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'neu_card.dart';
import 'neu_tokens.dart';

/// Cartão de gráfico do design system: título + área do gráfico dentro de um
/// [NeuCard].
///
/// A área do gráfico **acompanha o espaço disponível**, em dois modos:
///
/// - Quando o pai dá ALTURA LIMITADA (uma `Column` com `Expanded`, um painel de
///   altura fixa), o gráfico preenche o que sobrou — o card ocupa a área toda.
/// - Quando a altura é livre (dentro de uma rolagem, o caso comum), a altura é
///   PROPORCIONAL à largura, entre [minHeight] e [maxHeight]. Assim o gráfico
///   cresce numa tela larga em vez de ficar numa tira de 220px com metade do
///   cartão vazio ao lado.
///
/// A largura sempre foi total (o `NeuCard` estica); o que faltava era a altura
/// reagir a alguma coisa.
class NeuChartCard extends StatelessWidget {
  const NeuChartCard({
    super.key,
    required this.title,
    required this.child,
    this.minHeight = 220,
    this.maxHeight = 460,
    this.aspect = 2.2,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// Piso da área do gráfico quando a altura é livre.
  final double minHeight;

  /// Teto quando a altura é livre — sem ele, num monitor ultrawide o gráfico
  /// viraria um paredão e empurraria o resto da página para fora da vista.
  final double maxHeight;

  /// Largura ÷ altura desejada quando a altura é livre.
  final double aspect;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return LayoutBuilder(
      builder: (context, constraints) {
        final alturaLivre = !constraints.maxHeight.isFinite;
        final proporcional = constraints.maxWidth.isFinite
            ? (constraints.maxWidth / aspect).clamp(minHeight, maxHeight)
            : minHeight;
        return NeuCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // `min` quando a altura é livre: o card não pode tentar esticar
            // dentro de uma rolagem (altura infinita).
            mainAxisSize: alturaLivre ? MainAxisSize.min : MainAxisSize.max,
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
              if (alturaLivre)
                SizedBox(height: proporcional, child: child)
              else
                Expanded(child: child),
            ],
          ),
        );
      },
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

/// Tooltip de toque para gráficos de linha (superfície navy, texto claro).
LineTouchData neuLineTouch(
  BuildContext context, {
  required String Function(int index, double value) label,
}) {
  final neu = context.neu;
  return LineTouchData(
    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (_) => neu.navy,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      getTooltipItems: (spots) => [
        for (final s in spots)
          LineTooltipItem(
            label(s.x.round(), s.y),
            TextStyle(
              color: neu.onNavy,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Formatação curta para rótulos de eixo (mantém o eixo enxuto).
// ---------------------------------------------------------------------------

String _neuShort(double x) {
  final r = x.abs() < 10 ? (x * 10).roundToDouble() / 10 : x.roundToDouble();
  final s = r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
  return s.replaceAll('.', ',');
}

/// Moeda curta para eixos: "R\$ 850", "R\$ 1,2k", "R\$ 3,4M".
String neuShortMoney(num value) {
  final a = value.abs();
  if (a >= 1000000) return 'R\$ ${_neuShort(value / 1000000)}M';
  if (a >= 1000) return 'R\$ ${_neuShort(value / 1000)}k';
  return 'R\$ ${value.toStringAsFixed(0)}';
}

/// Contagem curta para eixos: "12", "1,2k".
String neuShortCount(num value) {
  final a = value.abs();
  if (a >= 1000) return '${_neuShort(value / 1000)}k';
  return value.toStringAsFixed(0);
}

// ---------------------------------------------------------------------------
// Eixos e grid recessivos (padrão do design system para BarChart/LineChart).
// ---------------------------------------------------------------------------

/// Eixos sem título — para os lados não usados (topo/direita).
const AxisTitles neuNoAxis =
    AxisTitles(sideTitles: SideTitles(showTitles: false));

/// Grid horizontal recessivo (linhas sutis em `neu.line`; sem verticais).
FlGridData neuGrid(BuildContext context, {required double interval}) {
  final neu = context.neu;
  return FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: interval <= 0 ? 1 : interval,
    getDrawingHorizontalLine: (_) => FlLine(color: neu.line, strokeWidth: 1),
  );
}

/// Eixo Y à esquerda com valores formatados (recessivo). Esconde o rótulo do
/// topo (colado no título) para não poluir.
AxisTitles neuLeftTitles(
  BuildContext context, {
  required String Function(double) format,
  double reservedSize = 48,
  double? interval,
}) {
  final neu = context.neu;
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: reservedSize,
      interval: interval,
      getTitlesWidget: (value, meta) {
        // O topo (maxY, acima do dado) fica sem rótulo para não colar no título.
        if (value >= meta.max) return const SizedBox.shrink();
        return SideTitleWidget(
          meta: meta,
          space: 6,
          child: Text(
            format(value),
            style: TextStyle(fontSize: 12, color: neu.inkFaint),
          ),
        );
      },
    ),
  );
}

/// Eixo X inferior por índice→rótulo. Enxuga rótulos quando há muitos pontos
/// (mostra ~[maxLabels] no máximo) e permite rotacionar textos longos.
AxisTitles neuBottomTitles(
  BuildContext context, {
  required int count,
  required String Function(int) label,
  double reservedSize = 34,
  int maxLabels = 8,
  double angle = 0,
}) {
  final neu = context.neu;
  final step = count <= maxLabels ? 1 : (count / maxLabels).ceil();
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: reservedSize,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final i = value.round();
        if (i < 0 || i >= count) return const SizedBox.shrink();
        // Mostra 1 a cada [step] (e sempre o último) para não sobrepor.
        if (i % step != 0 && i != count - 1) return const SizedBox.shrink();
        return SideTitleWidget(
          meta: meta,
          space: 6,
          angle: angle,
          child: Text(
            label(i),
            style: TextStyle(fontSize: 12, color: neu.inkMuted),
          ),
        );
      },
    ),
  );
}

/// Item da legenda categórica: cor da série + rótulo (+ valor opcional).
class NeuLegendItem {
  const NeuLegendItem({required this.color, required this.label, this.value});
  final Color color;
  final String label;
  final String? value;
}

/// Legenda categórica horizontal (quebra em várias linhas). Texto sempre em
/// ink/inkMuted; só o marcador usa a cor da série. Use para ≥2 séries.
class NeuChartLegend extends StatelessWidget {
  const NeuChartLegend({super.key, required this.items});

  final List<NeuLegendItem> items;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final it in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: it.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                it.label,
                style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
              ),
              if (it.value != null) ...[
                const SizedBox(width: 4),
                Text(
                  it.value!,
                  style: TextStyle(
                    color: neu.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
