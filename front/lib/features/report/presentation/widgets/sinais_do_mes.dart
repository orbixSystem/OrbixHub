import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../domain/monthly_models.dart';
import 'motion.dart';

/// O que saiu da curva.
///
/// Cada item carrega um fio vertical na cor da gravidade, à esquerda. A
/// estrutura passa a dizer o que uma bolinha não diz: a altura do fio marca
/// onde o item começa e termina, e a cor ordena a urgência antes de qualquer
/// palavra ser lida. É o mesmo gesto da margem marcada a lápis num relatório
/// impresso.
///
/// Aparece mesmo quando o texto do mês ainda não existe: o dono não deveria
/// esperar o dia 1º para descobrir que o fiado dobrou.
class SinaisDoMes extends StatelessWidget {
  const SinaisDoMes({super.key, required this.sinais});

  final List<SinalMensal> sinais;

  @override
  Widget build(BuildContext context) {
    if (sinais.isEmpty) return const SizedBox.shrink();
    final neu = context.neu;

    return NeuCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sinais.length == 1
                ? 'Um ponto merece atenção'
                : '${sinais.length} pontos merecem atenção',
            style: TextStyle(
              color: neu.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < sinais.length; i++)
            Padding(
              padding:
                  EdgeInsets.only(bottom: i == sinais.length - 1 ? 0 : 16),
              child: _Sinal(sinal: sinais[i]),
            ),
        ],
      ),
    );
  }
}

class _Sinal extends StatelessWidget {
  const _Sinal({required this.sinal});

  final SinalMensal sinal;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cor = sinal.ehCritico
        ? neu.danger
        : sinal.ehAlerta
            ? neu.warning
            : neu.info;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // O fio da margem: 2px, cheio no crítico e esmaecido no informativo.
          Container(
            width: 2.5,
            decoration: BoxDecoration(
              color: sinal.ehCritico ? cor : cor.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sinal.titulo,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sinal.detalhe,
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                if (_evidencia != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    _evidencia!,
                    style: TextStyle(
                      color: cor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFeatures: kTabular,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// O número que sustenta o sinal, dito em uma linha.
  ///
  /// Vem dos valores que a regra apurou — o mesmo material que o texto do mês
  /// usa. Sem ele o alerta é uma opinião; com ele, o dono sabe exatamente o
  /// tamanho do problema sem abrir outra tela.
  String? get _evidencia {
    final n = sinal.numeros;
    String pct(String chave) {
      final v = n[chave];
      return v == null ? '' : '${v.abs().toStringAsFixed(v.abs() >= 100 ? 0 : 1)}%';
    }

    switch (sinal.chave) {
      case 'fiado_crescendo':
        final f = pct('pctFiado');
        final fat = pct('pctFaturado');
        if (f.isEmpty) return null;
        return 'Fiado $f contra $fat do faturamento';
      case 'despesa_subindo':
        final d = pct('pctDespesa');
        final fat = pct('pctFaturado');
        if (d.isEmpty) return null;
        return 'Despesas $d contra $fat do faturamento';
      case 'vencido_alto':
        final p = pct('pctVencido');
        return p.isEmpty ? null : '$p do que há para receber já venceu';
      case 'cancelamento_alto':
        final canceladas = n['canceladas'];
        final concluidas = n['concluidas'];
        if (canceladas == null || concluidas == null) return null;
        return '${canceladas.toStringAsFixed(0)} canceladas para '
            '${concluidas.toStringAsFixed(0)} concluídas';
      case 'ticket_caindo':
        final p = pct('pct');
        return p.isEmpty ? null : 'Queda de $p no valor médio por atendimento';
      default:
        return null;
    }
  }
}
