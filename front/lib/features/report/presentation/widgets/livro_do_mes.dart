import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../domain/monthly_models.dart';
import 'motion.dart';
import 'sparkline.dart';

/// Os números do mês, em LIVRO — não em grade de cartões.
///
/// Dinheiro se lê em coluna: o olho desce pelos valores alinhados na vírgula e
/// compara sem esforço. Seis cartões iguais lado a lado obrigam a saltar de
/// caixa em caixa, e a comparação — que é o ponto inteiro de um relatório
/// mensal — nunca acontece. É também como a oficina já lê as próprias contas.
///
/// O faturamento abre em corpo grande com a linha do mês embaixo; o resto vem
/// em linhas separadas por fio. A hierarquia diz o que ler primeiro sem
/// precisar de rótulo explicando.
class LivroDoMes extends StatelessWidget {
  const LivroDoMes({super.key, required this.kpis, required this.serie});

  final List<KpiMensal> kpis;
  final List<PontoDiario> serie;

  @override
  Widget build(BuildContext context) {
    if (kpis.isEmpty) return const SizedBox.shrink();
    final neu = context.neu;
    final abertura = kpis.first;
    final demais = kpis.skip(1).toList();

    return LayoutBuilder(
      builder: (context, c) {
        // Abaixo de 400px a coluna da variação não cabe junto com o valor e o
        // rótulo. Em vez de deixar o rótulo cortar no meio, o livro encolhe:
        // corpo menor e coluna estreita. O alinhamento da vírgula — a razão de
        // existir a coluna — é o que NÃO pode ser sacrificado.
        final compacto = c.maxWidth < 400;
        return NeuCard(
          padding: EdgeInsets.fromLTRB(compacto ? 16 : 22, 20, compacto ? 16 : 22, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Abertura(kpi: abertura, serie: serie),
              const SizedBox(height: 18),
              for (final k in demais) ...[
                Divider(height: 1, thickness: _fio(context), color: neu.line),
                _Linha(kpi: k, compacto: compacto),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Um fio de UM pixel físico.
///
/// `1.0` em lógico vira 2 ou 3 pixels numa tela densa e o traço engorda — num
/// documento cheio de fios, é a diferença entre régua e cerca.
double _fio(BuildContext context) => 1 / MediaQuery.devicePixelRatioOf(context);

/// O número que abre o mês: corpo grande, com a linha do período embaixo.
class _Abertura extends StatelessWidget {
  const _Abertura({required this.kpi, required this.serie});

  final KpiMensal kpi;
  final List<PontoDiario> serie;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kpi.rotulo,
          style: TextStyle(
            color: neu.inkMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: NumeroQueConta(
                  valor: kpi.valor,
                  formatar: (v) =>
                      kpi.ehDinheiro ? formatMoney(v) : v.toStringAsFixed(0),
                  estilo: Theme.of(context).textTheme.displaySmall!.copyWith(
                        color: neu.ink,
                        fontSize: 38,
                        height: 1,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _Delta(kpi: kpi, grande: true),
            ),
          ],
        ),
        if (serie.length > 2) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: Sparkline(
              valores: [for (final p in serie) p.valor.toDouble()],
              cor: neu.accent,
            ),
          ),
        ],
      ],
    );
  }
}

/// Uma linha do livro: rótulo à esquerda, valor e variação à direita.
class _Linha extends StatelessWidget {
  const _Linha({required this.kpi, this.compacto = false});

  final KpiMensal kpi;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              kpi.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: compacto ? 13.5 : 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: compacto ? 8 : 12),
          Text(
            kpi.ehDinheiro
                ? formatMoney(kpi.valor)
                : kpi.valor.toStringAsFixed(0),
            style: TextStyle(
              color: neu.ink,
              fontSize: compacto ? 15 : 16.5,
              fontWeight: FontWeight.w700,
              fontFeatures: kTabular,
            ),
          ),
          // Largura fixa na coluna da variação: sem ela, "▲310%" empurra o
          // valor ao lado e a coluna de dinheiro deixa de ser uma coluna.
          SizedBox(
            width: compacto ? 62 : 86,
            child: Align(
              alignment: Alignment.centerRight,
              child: _Delta(kpi: kpi, compacto: compacto),
            ),
          ),
        ],
      ),
    );
  }
}

/// A variação contra o mês anterior.
///
/// A cor vem do NEGÓCIO, não da direção: despesa e fiado subindo são vermelhos.
/// Pintar toda alta de verde faz a tela comemorar o que o dono precisa cortar.
///
/// Sem comparação, um traço — e não um zero, que seria afirmar estabilidade
/// onde não há medida.
class _Delta extends StatelessWidget {
  const _Delta({required this.kpi, this.grande = false, this.compacto = false});

  final KpiMensal kpi;
  final bool grande;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final v = kpi.variacao;
    if (v == null) {
      return Text(
        '—',
        style: TextStyle(color: neu.inkFaint, fontSize: grande ? 14 : 13),
      );
    }
    final boa = kpi.variacaoEhBoa;
    final cor = boa == null
        ? neu.inkFaint
        : boa
            ? neu.success
            : neu.danger;
    final pct = v.pct.abs();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          v.pct > 0
              ? Icons.north_rounded
              : v.pct < 0
                  ? Icons.south_rounded
                  : Icons.remove_rounded,
          size: grande ? 15 : 13,
          color: cor,
        ),
        const SizedBox(width: 2),
        // O percentual encolhe antes de estourar: "310%" é mais largo que
        // "8,2%", e a coluna tem largura fixa para o dinheiro ao lado continuar
        // alinhado. Entre perder um ponto de corpo e furar a coluna, perde-se
        // o corpo.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${pct >= 100 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1)}%',
              maxLines: 1,
              style: TextStyle(
                color: cor,
                fontSize: grande ? 15 : (compacto ? 12.5 : 13.5),
                fontWeight: FontWeight.w700,
                fontFeatures: kTabular,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
