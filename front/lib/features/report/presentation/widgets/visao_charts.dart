import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../domain/monthly_models.dart';

/// "dd" a partir de "2026-09-17" — o eixo do mês não precisa repetir o mês.
String _dia(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? p[2] : iso;
}

/// Faturamento dia a dia do mês.
///
/// Mostra o RITMO, que nenhum total mostra: dois meses com o mesmo faturamento
/// são negócios diferentes se um concentrou tudo em três dias e o outro
/// trabalhou parelho. É também onde um buraco de uma semana salta aos olhos.
class FaturamentoDoMesChart extends StatelessWidget {
  const FaturamentoDoMesChart({super.key, required this.serie});

  final List<PontoDiario> serie;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (serie.isEmpty) {
      return NeuChartCard(
        title: 'Faturamento dia a dia',
        child: _Vazio(texto: 'Nenhum faturamento registrado neste mês.'),
      );
    }

    final pontos = [
      for (var i = 0; i < serie.length; i++)
        FlSpot(i.toDouble(), serie[i].valor.toDouble()),
    ];
    final maior = serie
        .map((p) => p.valor.toDouble())
        .reduce((a, b) => a > b ? a : b);
    // Passo do eixo X: num mês de 30 dias, um rótulo por dia vira borrão.
    final passo = (serie.length / 6).ceil().clamp(1, 31);

    return NeuChartCard(
      title: 'Faturamento dia a dia',
      trailing: Text(
        formatMoney(serie.fold<num>(0, (a, p) => a + p.valor)),
        style: TextStyle(
          color: neu.ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maior <= 0 ? 1 : maior * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: neu.line, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: passo.toDouble(),
                getTitlesWidget: (v, _) {
                  final i = v.round();
                  if (i < 0 || i >= serie.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _dia(serie[i].dia),
                      style: TextStyle(color: neu.inkFaint, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final p = serie[s.x.round().clamp(0, serie.length - 1)];
                return LineTooltipItem(
                  '${_dia(p.dia)} · ${formatMoney(p.valor)}',
                  TextStyle(
                    color: neu.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: pontos,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 2.5,
              color: neu.accent,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: neu.accent.withValues(alpha: 0.14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Para onde foi o dinheiro: despesas por categoria.
///
/// Responde a pergunta que o total de despesas não responde. Um mês que gastou
/// 30% a mais é uma informação; saber que foi em peças (e não em aluguel) é o
/// que permite fazer alguma coisa a respeito.
class ParaOndeFoiChart extends StatelessWidget {
  const ParaOndeFoiChart({super.key, required this.fatias});

  final List<FatiaCategoria> fatias;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final comValor = fatias.where((f) => f.total > 0).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    if (comValor.isEmpty) {
      return const NeuChartCard(
        title: 'Para onde foi o dinheiro',
        child: _Vazio(texto: 'Nenhuma despesa registrada neste mês.'),
      );
    }

    // Seis fatias no máximo; o resto vira "Outras". Um donut com quinze
    // categorias não é um gráfico, é uma lista colorida ilegível.
    final principais = comValor.take(6).toList();
    final resto = comValor.skip(6).fold<num>(0, (a, f) => a + f.total);
    final itens = [
      ...principais,
      if (resto > 0) FatiaCategoria(categoria: 'Outras', total: resto),
    ];
    final total = itens.fold<num>(0, (a, f) => a + f.total);
    // Paleta de glyphs do design system — a mesma que já identifica categorias
    // em outras telas, para a mesma cor não significar coisas diferentes.
    final cores = neu.glyphs;

    return NeuChartCard(
      title: 'Para onde foi o dinheiro',
      aspect: 1.6,
      trailing: Text(
        formatMoney(total),
        style: TextStyle(
          color: neu.ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final rosca = PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: [
                for (var i = 0; i < itens.length; i++)
                  PieChartSectionData(
                    value: itens[i].total.toDouble(),
                    color: cores[i % cores.length],
                    radius: 26,
                    showTitle: false,
                  ),
              ],
            ),
          );
          final legenda = NeuChartLegend(
            items: [
              for (var i = 0; i < itens.length; i++)
                NeuLegendItem(
                  color: cores[i % cores.length],
                  label: itens[i].categoria,
                  value: formatMoney(itens[i].total),
                ),
            ],
          );

          // No celular a legenda vai PARA BAIXO da rosca. Lado a lado, ela fica
          // com menos de 150px e "Ferramentas R$ 1.200,00" não cabe em
          // nenhuma — espremer categoria e valor é perder a única coisa que a
          // legenda faz.
          if (c.maxWidth < 460) {
            return Column(
              children: [
                Expanded(child: rosca),
                const SizedBox(height: 14),
                legenda,
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: rosca),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: SingleChildScrollView(child: legenda),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.neu.inkFaint, fontSize: 13.5),
      ),
    );
  }
}
