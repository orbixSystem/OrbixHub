import 'package:flutter/material.dart';

import '../../../features/dashboard/presentation/widgets/metric_card.dart'
    show formatMoney;
import 'chart_common.dart';

/// Uma barra do gráfico de barras (categoria → valor).
class OrbixBar {
  const OrbixBar({required this.label, required this.value, this.color});

  final String label;
  final double value;

  /// Cor opcional da barra; default = cor primária da oficina.
  final Color? color;
}

/// Gráfico de barras HORIZONTAIS para rankings de categorias (ex.: top
/// produtos/serviços, faturamento por responsável). Barras horizontais lidam bem
/// com rótulos longos e qualquer quantidade de categorias — diferente de barras
/// verticais, cujos rótulos se atropelam. Cada linha tem rótulo, trilho de
/// referência (proporção ao máximo) e valor formatado (moeda/quantidade pt-BR).
/// Tema-aware, responsivo (preenche a largura) e com tooltip ao passar/tocar.
///
/// Estado vazio é tratado fora (via [ChartEmptyState]); aqui assume-se ao menos
/// uma barra — uma barra única ainda tem contexto (rótulo + trilho + valor), ao
/// contrário de uma barra "solta" sem eixo.
class OrbixBarChart extends StatelessWidget {
  const OrbixBarChart({
    super.key,
    required this.bars,
    this.currency = true,
  });

  final List<OrbixBar> bars;

  /// Formata o valor como moeda (R$); senão, quantidade.
  final bool currency;

  String _format(double v) => currency ? formatMoney(v) : compactNumber(v);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue =
        bars.fold<double>(0, (a, b) => b.value > a ? b.value : a);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    // Largura reservada para o rótulo da categoria, proporcional à largura
    // disponível (responsivo) e limitada a uma faixa legível.
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth =
            (constraints.maxWidth * 0.28).clamp(72.0, 160.0).toDouble();
        return ListView.separated(
          // Rola só se houver muitas categorias; poucas cabem sem rolagem.
          physics: const ClampingScrollPhysics(),
          itemCount: bars.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _BarRow(
            bar: bars[i],
            fraction: (bars[i].value / safeMax).clamp(0.0, 1.0),
            labelWidth: labelWidth,
            valueText: _format(bars[i].value),
            color: bars[i].color ?? scheme.primary,
          ),
        );
      },
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.bar,
    required this.fraction,
    required this.labelWidth,
    required this.valueText,
    required this.color,
  });

  final OrbixBar bar;
  final double fraction;
  final double labelWidth;
  final String valueText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: '${bar.label}: $valueText',
      waitDuration: const Duration(milliseconds: 250),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              bar.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  // Trilho de referência (escala completa).
                  Container(
                    height: 22,
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  ),
                  // Barra preenchida proporcional ao máximo.
                  FractionallySizedBox(
                    widthFactor: fraction == 0 ? 0.015 : fraction,
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.85),
                            color,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: Text(
              valueText,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
