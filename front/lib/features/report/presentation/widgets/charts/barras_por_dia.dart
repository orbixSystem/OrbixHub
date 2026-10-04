import 'package:flutter/material.dart';

import '../../../../../core/ui/ui.dart';
import '../motion.dart';

/// Um dia da série.
class DiaDaSerie {
  const DiaDaSerie({required this.dia, required this.valor, required this.texto});

  /// "2026-09-17".
  final String dia;
  final double valor;

  /// O valor escrito, para o rótulo sobre a barra.
  final String texto;
}

/// Série por dia, em barras verticais e em ORDEM CRONOLÓGICA.
///
/// Um ranking ordenado por valor não serve aqui: quando todos os dias têm o
/// mesmo número — doze dias com um cliente novo cada — ele vira doze barras
/// idênticas e não informa nada. O que a pergunta "quando chegaram?" pede é a
/// linha do tempo: onde houve pico, onde houve silêncio, se o movimento é
/// constante ou veio de um dia só.
///
/// Desenhado à mão porque é um gráfico simples e de altura fixa: trazer uma
/// biblioteca inteira para desenhar retângulos custaria mais do que entrega.
class BarrasPorDia extends StatelessWidget {
  const BarrasPorDia({
    super.key,
    required this.titulo,
    required this.dias,
    this.total,
    this.vazio = 'Sem movimento no período.',
    this.altura = 180,
  });

  final String titulo;
  final List<DiaDaSerie> dias;
  final String? total;
  final String vazio;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;

    if (dias.isEmpty) {
      return NeuCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            Center(
              child: Text(
                vazio,
                style: TextStyle(color: neu.inkFaint, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    final maior = dias.map((d) => d.valor).reduce((a, b) => a > b ? a : b);
    // Um dia a cada N ganha rótulo: num mês de 30 dias, trinta rótulos de dois
    // dígitos viram uma faixa cinza ilegível.
    final passo = (dias.length / 10).ceil().clamp(1, 31);

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: altura,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < dias.length; i++)
                  Expanded(
                    child: _Barra(
                      dia: dias[i],
                      proporcao: maior <= 0 ? 0 : dias[i].valor / maior,
                      mostraRotulo: i % passo == 0 || i == dias.length - 1,
                      // O maior dia do mês ganha a cor cheia; os outros
                      // esmaecem. É o pico que a pergunta procura.
                      destaque: dias[i].valor >= maior,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.dia,
    required this.proporcao,
    required this.mostraRotulo,
    required this.destaque,
  });

  final DiaDaSerie dia;
  final double proporcao;
  final bool mostraRotulo;
  final bool destaque;

  /// "2026-09-17" → "17".
  String get _rotulo {
    final p = dia.dia.split('-');
    return p.length == 3 ? p[2] : dia.dia;
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final semMovimento = MediaQuery.disableAnimationsOf(context);
    final cor = destaque ? neu.accent : neu.navy.withValues(alpha: 0.45);

    final barra = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      child: Container(color: cor),
    );

    return Tooltip(
      message: '$_rotulo · ${dia.texto}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: semMovimento
                    ? FractionallySizedBox(heightFactor: proporcao, child: barra)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: proporcao),
                        duration: kAberturaLonga,
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) => FractionallySizedBox(
                          heightFactor: t.clamp(0.0, 1.0),
                          child: barra,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 14,
              child: mostraRotulo
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _rotulo,
                        style: TextStyle(
                          color: neu.inkFaint,
                          fontSize: 12,
                          fontFeatures: kTabular,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
