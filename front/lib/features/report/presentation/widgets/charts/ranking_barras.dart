import 'package:flutter/material.dart';

import '../../../../../core/ui/ui.dart';
import '../motion.dart';

/// Uma linha do ranking.
class BarraRanking {
  const BarraRanking({
    required this.rotulo,
    required this.valor,
    required this.texto,
    this.detalhe,
  });

  final String rotulo;
  final double valor;

  /// O valor já escrito — a barra mostra proporção, o texto mostra quanto.
  final String texto;

  /// Linha secundária (ex.: "12 vendas"), quando ajuda.
  final String? detalhe;
}

/// Ranking em barras HORIZONTAIS.
///
/// Barra deitada, e não em pé, porque o rótulo é um nome — "Pastilha de freio
/// dianteira", "João Mecânico". Na vertical esse texto vira diagonal ou
/// reticências, e o gráfico passa a exigir uma legenda para dizer o que já
/// estava escrito.
///
/// Desenhado à mão: aqui não há eixo, escala nem toque, só proporção. Uma
/// biblioteca de gráficos cobraria layout e hit-test por uma barra de largura
/// percentual.
class RankingBarras extends StatelessWidget {
  const RankingBarras({
    super.key,
    required this.titulo,
    required this.itens,
    this.total,
    this.vazio = 'Sem dados no período.',
    this.limite = 8,
    this.cor,
  });

  final String titulo;
  final List<BarraRanking> itens;
  final String? total;
  final String vazio;
  final int limite;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ordenados = [...itens.where((i) => i.valor > 0)]
      ..sort((a, b) => b.valor.compareTo(a.valor));
    final mostrar = ordenados.take(limite).toList();

    if (mostrar.isEmpty) {
      return NeuCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Titulo(titulo: titulo, total: null),
            const SizedBox(height: 20),
            Center(
              child: Text(
                vazio,
                style: TextStyle(color: neu.inkFaint, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    }

    final maior = mostrar.first.valor;
    final corBarra = cor ?? neu.accent;

    return NeuCard(
      padding: const EdgeInsets.all(20),
      // Barra de 1240px é tinta demais para comparar quatro itens: a diferença
      // entre 60% e 70% de uma barra enorme some, e o olho ainda percorre a
      // tela inteira de volta até o rótulo. Num traço de ~820px a proporção
      // continua clara e a leitura cabe num golpe de vista.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Titulo(titulo: titulo, total: total),
          const SizedBox(height: 16),
          for (var i = 0; i < mostrar.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == mostrar.length - 1 ? 0 : 14),
              child: _Linha(
                item: mostrar[i],
                proporcao: maior <= 0 ? 0 : mostrar[i].valor / maior,
                cor: corBarra,
                // A primeira barra é cheia; as seguintes esmaecem um pouco.
                // Sem isso o ranking é uma lista de retângulos iguais e a
                // ordem precisa ser lida, em vez de vista.
                opacidade: 1 - (i / (mostrar.length + 2)) * 0.55,
              ),
            ),
        ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo({required this.titulo, required this.total});
  final String titulo;
  final String? total;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      children: [
        Expanded(
          child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (total != null)
          Text(
            total!,
            style: TextStyle(
              color: neu.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: kTabular,
            ),
          ),
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.item,
    required this.proporcao,
    required this.cor,
    required this.opacidade,
  });

  final BarraRanking item;
  final double proporcao;
  final Color cor;
  final double opacidade;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final semMovimento = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.texto,
              style: TextStyle(
                color: neu.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFeatures: kTabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // A barra cresce da esquerda quando a página abre — é o mesmo gesto do
        // fio do documento, e aqui ele mostra a proporção sendo medida.
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            color: neu.line,
            child: Align(
              alignment: Alignment.centerLeft,
              child: semMovimento
                  ? FractionallySizedBox(
                      widthFactor: proporcao,
                      child: Container(color: cor.withValues(alpha: opacidade)),
                    )
                  : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: proporcao),
                      duration: kAberturaLonga,
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => FractionallySizedBox(
                        widthFactor: t,
                        child: Container(
                          color: cor.withValues(alpha: opacidade),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        if (item.detalhe != null) ...[
          const SizedBox(height: 4),
          Text(
            item.detalhe!,
            style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}
