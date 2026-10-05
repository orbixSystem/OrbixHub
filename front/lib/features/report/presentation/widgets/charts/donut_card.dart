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


    Color corDe(int i) => itens[i].cor ?? paleta[i % paleta.length];

    // A ROSCA ACOMPANHA O ESPAÇO.
    //
    // Antes o raio era fixo (68px) e o card media 460px de altura: sobrava
    // metade do card vazia com uma rosquinha perdida no canto. Agora o
    // diâmetro sai do lado disponível, e o card pede só a altura que a rosca
    // precisa — o gráfico passa a ocupar o espaço que tem, em vez de o espaço
    // mandar nele.
    Widget roscaCom(double lado) {
      final raioExterno = lado / 2;
      final furo = raioExterno * 0.52;
      return PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: furo,
          sections: [
            for (var i = 0; i < itens.length; i++)
              PieChartSectionData(
                value: itens[i].valor,
                color: corDe(i),
                radius: raioExterno - furo,
                showTitle: false,
              ),
          ],
        ),
      );
    }

    final legenda = NeuChartLegend(
      items: [
        for (var i = 0; i < itens.length; i++)
          NeuLegendItem(
            color: corDe(i),
            label: itens[i].rotulo,
            value: itens[i].texto,
          ),
      ],
    );

    final lado = compacto ? 148.0 : 208.0;

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (total != null)
                Text(
                  total!,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              // Estreito: rosca em cima, legenda embaixo. Lado a lado a legenda
              // fica com menos de 150px e "Ferramentas R$ 1.200,00" não cabe —
              // espremer rótulo e valor é perder a única coisa que ela faz.
              if (c.maxWidth < 460) {
                return Column(
                  children: [
                    SizedBox(height: lado, child: roscaCom(lado)),
                    const SizedBox(height: 18),
                    legenda,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: lado, height: lado, child: roscaCom(lado)),
                  const SizedBox(width: 30),
                  Expanded(child: legenda),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
