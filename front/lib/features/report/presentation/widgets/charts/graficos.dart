import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/ui/ui.dart';
import '../../../../cashier/domain/cashier_format.dart';
import '../motion.dart';

/// O conjunto de gráficos do painel.
///
/// Todos partem das mesmas decisões: eixo Y discreto (três linhas de grade, sem
/// moldura), rótulo de dia no eixo X a cada N dias, tooltip com o valor escrito
/// e nenhuma cor fora dos tokens do design system. Gráficos que decidem isso
/// cada um por si viram sete estilos diferentes na mesma página.

/// "2026-09-17" → "17".
String diaCurto(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? p[2] : iso;
}

/// Valor em milhares para o eixo: "R$ 4,5 mil".
String _eixoDinheiro(double v) {
  if (v >= 1000) {
    final mil = v / 1000;
    return 'R\$ ${mil.toStringAsFixed(mil >= 10 ? 0 : 1).replaceAll('.', ',')} mil';
  }
  return 'R\$ ${v.toStringAsFixed(0)}';
}

FlGridData _grade(Color cor) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: null,
      getDrawingHorizontalLine: (_) => FlLine(color: cor, strokeWidth: 1),
    );

AxisTitles _eixoX(List<String> dias, Color cor) {
  final passo = (dias.length / 7).ceil().clamp(1, 31);
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 24,
      interval: passo.toDouble(),
      getTitlesWidget: (v, _) {
        final i = v.round();
        if (i < 0 || i >= dias.length) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            diaCurto(dias[i]),
            style: TextStyle(color: cor, fontSize: 12),
          ),
        );
      },
    ),
  );
}

/// O eixo de dinheiro.
///
/// [minimo] só é diferente de zero quando a série tem valores negativos — um
/// saldo diário, por exemplo. Nesse caso o intervalo precisa cobrir a faixa
/// inteira: calculado só sobre o máximo, os rótulos se amontoariam numa faixa
/// cinza ilegível na parte de cima do gráfico.
AxisTitles _eixoYDinheiro(double maximo, Color cor, {double minimo = 0}) =>
    AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 56,
        interval: (maximo - minimo) <= 0 ? 1 : (maximo - minimo) / 3,
        getTitlesWidget: (v, _) => v == 0 || (minimo >= 0 && v < 0)
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  _eixoDinheiro(v),
                  style: TextStyle(color: cor, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
              ),
      ),
    );

/// As cores de duas séries que precisam ser distinguidas uma da outra.
///
/// Não são `navy` e `accent`: no tema atual as duas são o mesmo roxo a dois
/// pontos de distância — ótimas como cor de marca, inúteis como par de
/// séries, porque o gráfico vira uma linha só com dois traços. A paleta de
/// glyphs existe justamente para distinguir categorias, e é dela que o par sai.
({Color principal, Color secundaria}) coresDeSerie(BuildContext context) {
  final g = context.neu.glyphs;
  return (principal: g[0], secundaria: g[2]);
}

/// Uma série nomeada para os gráficos de várias linhas.
class SerieNomeada {
  const SerieNomeada({
    required this.nome,
    required this.valores,
    required this.cor,
    this.preenchida = false,
    this.acumulada = false,
  });

  final String nome;
  final List<double> valores;
  final Color cor;

  /// Preenche a área sob a linha — só a série PRINCIPAL; duas áreas
  /// sobrepostas viram uma mancha onde não se lê nenhuma das duas.
  final bool preenchida;

  /// Os valores já são uma soma corrente.
  ///
  /// Muda o número da legenda: somar uma série acumulada daria a soma de todas
  /// as somas parciais — um número que não existe em lugar nenhum e que, na
  /// tela, discordaria do total escrito logo abaixo.
  final bool acumulada;
}

/// Duas (ou mais) séries por dia, em linha.
///
/// É o gráfico que responde "entrou mais do que saiu?" dia a dia — a pergunta
/// que um total mensal esconde: o mês pode fechar positivo tendo passado três
/// semanas no vermelho.
class LinhasPorDia extends StatelessWidget {
  const LinhasPorDia({
    super.key,
    required this.dias,
    required this.series,
    this.dinheiro = true,
  });

  final List<String> dias;
  final List<SerieNomeada> series;
  final bool dinheiro;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (dias.isEmpty || series.isEmpty) return const SizedBox.shrink();
    final maximo = series
        .expand((s) => s.valores)
        .fold<double>(0, (a, b) => b > a ? b : a);

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maximo <= 0 ? 1 : maximo * 1.18,
              gridData: _grade(neu.line),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: dinheiro
                    ? _eixoYDinheiro(maximo * 1.18, neu.inkFaint)
                    : const AxisTitles(),
                bottomTitles: _eixoX(dias, neu.inkFaint),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (pontos) => [
                    for (final p in pontos)
                      LineTooltipItem(
                        '${series[p.barIndex].nome}: '
                        '${dinheiro ? formatMoney(p.y) : p.y.toStringAsFixed(0)}',
                        TextStyle(
                          color: series[p.barIndex].cor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                for (final s in series)
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < s.valores.length; i++)
                        FlSpot(i.toDouble(), s.valores[i]),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.22,
                    barWidth: s.preenchida ? 2.6 : 2,
                    color: s.cor,
                    dotData: const FlDotData(show: false),
                    // Tracejada na série secundária: distingue as duas sem
                    // depender só da cor, que some para quem não distingue
                    // vermelho de verde.
                    dashArray: s.preenchida ? null : [5, 4],
                    belowBarData: BarAreaData(
                      show: s.preenchida,
                      color: s.cor.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        NeuChartLegend(
          items: [
            for (final s in series)
              NeuLegendItem(
                color: s.cor,
                label: s.nome,
                value: dinheiro
                    ? formatMoney(_totalDaSerie(s))
                    : _totalDaSerie(s).toStringAsFixed(0),
              ),
          ],
        ),
      ],
    );
  }
}

/// Barras por dia, com o valor em dinheiro no eixo.
class ColunasPorDia extends StatelessWidget {
  const ColunasPorDia({
    super.key,
    required this.dias,
    required this.valores,
    this.cor,
    this.dinheiro = true,
  });

  final List<String> dias;
  final List<double> valores;
  final Color? cor;
  final bool dinheiro;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (dias.isEmpty) return const SizedBox.shrink();
    final maximo = valores.fold<double>(0, (a, b) => b > a ? b : a);
    // Série com valores negativos — um saldo diário, por exemplo — precisa de
    // espaço abaixo do zero. Sem isso a barra de um dia no vermelho cresceria
    // para CIMA, e o gráfico diria o contrário do que aconteceu.
    final minimo = valores.fold<double>(0, (a, b) => b < a ? b : a);
    final temNegativo = minimo < 0;
    final destaque = cor ?? neu.navy;

    return BarChart(
      BarChartData(
        maxY: maximo <= 0 ? 1 : maximo * 1.18,
        minY: temNegativo ? minimo * 1.18 : 0,
        gridData: _grade(neu.line),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: dinheiro
              ? _eixoYDinheiro(
                  maximo * 1.18,
                  neu.inkFaint,
                  minimo: temNegativo ? minimo * 1.18 : 0,
                )
              : const AxisTitles(),
          bottomTitles: _eixoX(dias, neu.inkFaint),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
              '${diaCurto(dias[gi])} · '
              '${dinheiro ? formatMoney(valores[gi]) : valores[gi].toStringAsFixed(0)}',
              TextStyle(
                color: neu.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < valores.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: valores[i],
                  width: (260 / dias.length).clamp(3.0, 16.0),
                  borderRadius: valores[i] < 0
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(3),
                        )
                      : const BorderRadius.vertical(top: Radius.circular(3)),
                  // Dia negativo em vermelho — ele não concorre pelo destaque
                  // de "melhor dia", concorre pela atenção. O maior dia fica em
                  // cor cheia e o resto esmaecido: é o pico que a pergunta
                  // procura, e ele deixa de precisar ser caçado com o olho.
                  color: valores[i] < 0
                      ? neu.danger.withValues(alpha: 0.75)
                      : valores[i] >= maximo && maximo > 0
                          ? neu.accent
                          : destaque.withValues(alpha: 0.5),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Duas barras lado a lado por categoria — comparação direta.
///
/// Existe para perguntas de PAR: previsto × pago, entrada × saída. Duas barras
/// encostadas comparam melhor que duas linhas separadas, porque a diferença
/// vira um degrau visível em vez de uma distância a estimar.
class BarrasComparadas extends StatelessWidget {
  const BarrasComparadas({
    super.key,
    required this.categorias,
    required this.primeira,
    required this.segunda,
    required this.rotuloPrimeira,
    required this.rotuloSegunda,
  });

  final List<String> categorias;
  final List<double> primeira;
  final List<double> segunda;
  final String rotuloPrimeira;
  final String rotuloSegunda;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (categorias.isEmpty) return const SizedBox.shrink();
    final cores = coresDeSerie(context);
    final maximo = [...primeira, ...segunda]
        .fold<double>(0, (a, b) => b > a ? b : a);

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maximo <= 0 ? 1 : maximo * 1.18,
              gridData: _grade(neu.line),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: _eixoYDinheiro(maximo * 1.18, neu.inkFaint),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= categorias.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          categorias[i].length > 10
                              ? '${categorias[i].substring(0, 9)}…'
                              : categorias[i],
                          style: TextStyle(color: neu.inkFaint, fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                    '${categorias[gi]}\n'
                    '$rotuloPrimeira: ${formatMoney(primeira[gi])}\n'
                    '$rotuloSegunda: ${formatMoney(segunda[gi])}',
                    TextStyle(
                      color: neu.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < categorias.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      BarChartRodData(
                        toY: primeira[i],
                        width: 11,
                        color: cores.principal,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                      BarChartRodData(
                        toY: segunda[i],
                        width: 11,
                        color: cores.secundaria,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        NeuChartLegend(
          items: [
            NeuLegendItem(color: cores.principal, label: rotuloPrimeira),
            NeuLegendItem(color: cores.secundaria, label: rotuloSegunda),
          ],
        ),
      ],
    );
  }
}

/// Rosca com um número no miolo.
///
/// O miolo vazio de um donut é espaço que já está lá: colocar o total nele
/// poupa uma linha de texto e ancora as fatias — a proporção passa a ser lida
/// contra um número, não contra a lembrança de um número.
class RoscaComCentro extends StatelessWidget {
  const RoscaComCentro({
    super.key,
    required this.fatias,
    required this.centroValor,
    required this.centroRotulo,
    this.mostrarLegenda = true,
  });

  final List<({String rotulo, double valor, String texto, Color cor})> fatias;
  final String centroValor;
  final String centroRotulo;
  final bool mostrarLegenda;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final comValor = fatias.where((f) => f.valor > 0).toList();
    if (comValor.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        // A rosca cede largura para a legenda, não o contrário: um donut
        // perfeito ao lado de "Ferramen… R$ 1.2…" não informa nada. Abaixo de
        // 260px não há espaço para as duas coisas e a legenda sai.
        // 96px é a menor rosca que ainda se lê; abaixo de rosca + respiro +
        // legenda inteira, a legenda sai em vez de ficar espremida.
        final cabeLegenda =
            mostrarLegenda && c.maxWidth >= 96 + 20 + _larguraDaLegenda;
        final espacoDaRosca =
            cabeLegenda ? c.maxWidth - 20 - _larguraDaLegenda : c.maxWidth;
        final lado =
            (c.maxHeight < espacoDaRosca ? c.maxHeight : espacoDaRosca)
                .clamp(96.0, 230.0);
        final rosca = Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: lado,
              height: lado,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: lado * 0.30,
                  sections: [
                    for (final f in comValor)
                      PieChartSectionData(
                        value: f.valor,
                        color: f.cor,
                        radius: lado * 0.18,
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
                  centroValor,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: lado > 180 ? 19 : 16,
                    fontWeight: FontWeight.w800,
                    fontFeatures: kTabular,
                  ),
                ),
                Text(
                  centroRotulo,
                  style: TextStyle(color: neu.inkFaint, fontSize: 12),
                ),
              ],
            ),
          ],
        );

        if (!cabeLegenda) return Center(child: rosca);
        return Row(
          children: [
            rosca,
            const SizedBox(width: 20),
            Expanded(child: _LegendaDaRosca(fatias: comValor)),
          ],
        );
      },
    );
  }
}


/// O número que representa a série inteira: o último ponto, se ela já é uma
/// soma corrente; a soma dos pontos, se cada um é um dia solto.
double _totalDaSerie(SerieNomeada s) {
  if (s.valores.isEmpty) return 0;
  return s.acumulada ? s.valores.last : s.valores.fold(0, (a, b) => a + b);
}

/// Largura mínima reservada para a legenda da rosca — o bastante para
/// "Ferramentas" e "R$ 1.200,00" na mesma linha sem reticências.
const double _larguraDaLegenda = 168;

/// A legenda da rosca, em COLUNA — rótulo à esquerda, valor à direita.
///
/// Em coluna ela vira uma tabelinha: os valores alinham e as fatias podem ser
/// comparadas sem voltar ao desenho. A legenda horizontal do design system
/// serve a gráficos de duas ou três séries; com seis categorias ela quebra em
/// linhas irregulares e para de ser lida.
class _LegendaDaRosca extends StatelessWidget {
  const _LegendaDaRosca({required this.fatias});

  final List<({String rotulo, double valor, String texto, Color cor})> fatias;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    // Cinco linhas é o que cabe na altura de um card sem apertar. O que passa
    // disso já está no desenho como fatia — e uma legenda com barra de rolagem
    // escondida é pior do que uma legenda curta.
    final mostrar = fatias.take(5).toList();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in mostrar)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: f.cor,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f.rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                // O valor encolhe antes de estourar: num card estreito é
                // preferível um "R$ 16.400,00" um ponto menor a uma faixa
                // listrada de overflow.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      f.texto,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: kTabular,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (fatias.length > mostrar.length)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+${fatias.length - mostrar.length} no gráfico',
              style: TextStyle(color: neu.inkFaint, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
