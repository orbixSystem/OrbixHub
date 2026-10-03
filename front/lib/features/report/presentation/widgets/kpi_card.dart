import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../domain/monthly_models.dart';

/// Um número do mês, com a comparação contra o mês anterior.
///
/// A seta é COLORIDA PELO NEGÓCIO, não pela direção: despesa subindo e fiado
/// subindo aparecem em vermelho mesmo tendo subido. Pintar toda alta de verde
/// faria a tela comemorar exatamente o que o dono precisa cortar — e é o tipo
/// de detalhe que destrói a confiança no painel inteiro quando alguém percebe.
///
/// Sem comparação (primeiro mês de uso, ou categoria que não existia antes) não
/// há seta nenhuma. O servidor manda `variacao: null` nesse caso, e inventar um
/// "+100%" seria afirmar algo que ninguém pode conferir.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.kpi, this.destaque = false});

  final KpiMensal kpi;

  /// Card maior, para o número que abre a leitura do mês.
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final variacao = kpi.variacao;
    final boa = kpi.variacaoEhBoa;
    final cor = boa == null
        ? neu.inkFaint
        : boa
            ? neu.success
            : neu.danger;

    return NeuCard(
      padding: EdgeInsets.all(destaque ? 18 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kpi.rotulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.ehDinheiro
                  ? formatMoney(kpi.valor)
                  : kpi.valor.toStringAsFixed(0),
              style: TextStyle(
                color: neu.ink,
                fontSize: destaque ? 28 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (variacao == null)
            Text(
              'sem mês anterior',
              style: TextStyle(color: neu.inkFaint, fontSize: 12),
            )
          else
            Row(
              children: [
                Icon(
                  variacao.pct > 0
                      ? Icons.arrow_upward_rounded
                      : variacao.pct < 0
                          ? Icons.arrow_downward_rounded
                          : Icons.remove_rounded,
                  size: 14,
                  color: cor,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${variacao.pct.abs().toStringAsFixed(variacao.pct.abs() >= 100 ? 0 : 1)}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'vs. mês anterior',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: neu.inkFaint, fontSize: 12),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
