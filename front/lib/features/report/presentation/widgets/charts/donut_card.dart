import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/ui/ui.dart';

/// Uma fatia: rótulo, valor e o texto já formatado para a legenda.
class FatiaDonut {
  const FatiaDonut({
    required this.rotulo,
    required this.valor,
    required this.texto,
    this.cor,
  });

  final String rotulo;
  final double valor;

  /// O valor escrito ("R$ 16.400,00", "12 clientes") — a legenda mostra este.
  final String texto;

  /// Cor própria, quando a categoria já tem uma no produto (status da OS,
  /// categoria de despesa). Sem ela, entra a paleta do design system.
  final Color? cor;
}

/// Donut com legenda — a forma de responder "de que é feito este total".
///
/// Um donut só se justifica quando a pergunta é de COMPOSIÇÃO e as partes são
/// poucas. Por isso ele agrupa o excedente em "Outras": quinze fatias não são
/// um gráfico, são uma lista colorida ilegível — e nesse caso uma tabela
/// ordenada responde melhor.
///
/// Em tela estreita a legenda desce para baixo da rosca. Lado a lado ela fica
/// com menos de 150px, e "Ferramentas R$ 1.200,00" não cabe — espremer rótulo
/// e valor é perder a única coisa que a legenda faz.
class DonutCard extends StatelessWidget {
  const DonutCard({
    super.key,
    required this.titulo,
    required this.fatias,
    this.total,
    this.vazio = 'Sem dados no período.',
    this.maximoDeFatias = 6,
    this.compacto = false,
  });

  final String titulo;
  final List<FatiaDonut> fatias;

  /// Texto do total, mostrado ao lado do título.
  final String? total;
  final String vazio;
  final int maximoDeFatias;

  /// Versão pequena: rosca menor e legenda enxuta, para quando o gráfico é um
  /// detalhe da página e não o assunto dela.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final comValor = fatias.where((f) => f.valor > 0).toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));

    if (comValor.isEmpty) {
      return NeuChartCard(
        title: titulo,
        minHeight: compacto ? 150 : 220,
        child: Center(
          child: Text(
            vazio,
            textAlign: TextAlign.center,
            style: TextStyle(color: neu.inkFaint, fontSize: 13.5),
          ),
        ),
      );
    }

    final principais = comValor.take(maximoDeFatias).toList();
    final resto = comValor.skip(maximoDeFatias).fold<double>(
          0,
          (a, f) => a + f.valor,
        );
    final itens = [
      ...principais,
      if (resto > 0)
        FatiaDonut(rotulo: 'Outras', valor: resto, texto: '${comValor.length - maximoDeFatias} itens'),
    ];
    final paleta = neu.glyphs;

    Color cor(int i) => itens[i].cor ?? paleta[i % paleta.length];

    final rosca = PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: compacto ? 30 : 42,
        sections: [
          for (var i = 0; i < itens.length; i++)
            PieChartSectionData(
              value: itens[i].valor,
              color: cor(i),
              radius: compacto ? 18 : 26,
              showTitle: false,
            ),
        ],
      ),
    );
    final legenda = NeuChartLegend(
      items: [
        for (var i = 0; i < itens.length; i++)
          NeuLegendItem(
            color: cor(i),
            label: itens[i].rotulo,
            value: itens[i].texto,
          ),
      ],
    );

    return NeuChartCard(
      title: titulo,
      aspect: compacto ? 2.4 : 1.6,
      minHeight: compacto ? 150 : 220,
      maxHeight: compacto ? 220 : 460,
      trailing: total == null
          ? null
          : Text(
              total!,
              style: TextStyle(
                color: neu.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
      child: LayoutBuilder(
        builder: (context, c) {
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
