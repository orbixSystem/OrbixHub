import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../domain/monthly_models.dart';
import '../../domain/report_models.dart';
import '../report_providers.dart';
import '../widgets/charts/graficos.dart';
import '../widgets/painel.dart';

/// O painel de Despesas.
///
/// Despesa tem duas vidas: a prevista (o compromisso) e a paga (o dinheiro que
/// já saiu). Um relatório que mostra só uma delas responde metade da pergunta
/// — e é sempre a metade errada quando o mês aperta.
class PainelDeDespesas extends ConsumerWidget {
  const PainelDeDespesas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expensesReportProvider);
    final visao = ref.watch(visaoMensalProvider);
    final categoria = ref.watch(reportFiltersProvider).categoriaDespesa;
    return async.when(
      loading: () => const PainelCarregando(),
      error: (_, _) => PainelComErro(
        onRetry: () => ref.invalidate(expensesReportProvider),
      ),
      data: (r) => _Painel(
        relatorio: _recortar(r, categoria),
        categoria: categoria,
        movimento: visao.value?.graficos.movimentoPorDia ?? const [],
      ),
    );
  }
}

/// Aplica o filtro de categoria ANTES de qualquer card ler o relatório.
///
/// Recortar aqui, e não em cada card, é o que garante que os seis contem a
/// mesma coisa: os totais do rodapé são recalculados junto, e não sobra um
/// "previsto no período" do mês inteiro ao lado de uma rosca de uma categoria
/// só.
ExpensesReport _recortar(ExpensesReport r, String? categoria) {
  if (categoria == null) return r;
  final linhas =
      r.rows.where((l) => l.categoryName == categoria).toList();
  return r.copyWith(
    rows: linhas,
    totals: ExpensesReportTotals(
      count: linhas.fold(0, (a, l) => a + l.count),
      previsto: linhas.fold<num>(0, (a, l) => a + l.previsto),
      pago: linhas.fold<num>(0, (a, l) => a + l.pago),
      emAberto: linhas.fold<num>(0, (a, l) => a + l.emAberto),
      vencido: linhas.fold<num>(0, (a, l) => a + l.vencido),
    ),
  );
}

class _Painel extends StatelessWidget {
  const _Painel({
    required this.relatorio,
    required this.movimento,
    this.categoria,
  });

  final ExpensesReport relatorio;
  final List<MovimentoDiario> movimento;

  /// Categoria escolhida na barra, ou `null` para todas.
  final String? categoria;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final t = relatorio.totals;
    final linhas = [...relatorio.rows]
      ..sort((a, b) => b.previsto.compareTo(a.previsto));

    final dias = [for (final m in movimento) m.dia];
    final saiu = [for (final m in movimento) m.saiu.toDouble()];
    final diasComSaida = saiu.where((v) => v > 0).length;
    final maiorSaida = saiu.fold<double>(0, (a, b) => b > a ? b : a);

    final maior = linhas.isEmpty ? null : linhas.first;
    final concentracao =
        t.previsto <= 0 || maior == null ? 0.0 : maior.previsto / t.previsto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FaixaDeIndicadores(
          itens: [
            IndicadorPainel(
              rotulo: 'Previsto no período',
              valor: formatMoney(t.previsto),
              icone: Icons.receipt_long_outlined,
              detalhe: '${t.count} lançamentos',
            ),
            IndicadorPainel(
              rotulo: 'Já pago',
              valor: formatMoney(t.pago),
              icone: Icons.task_alt_rounded,
              detalhe: fatiaDoTotal(t.pago, t.previsto),
              cor: neu.success,
            ),
            IndicadorPainel(
              rotulo: 'Em aberto',
              valor: formatMoney(t.emAberto),
              icone: Icons.schedule_outlined,
              detalhe: fatiaDoTotal(t.emAberto, t.previsto),
              cor: t.emAberto > 0 ? neu.warning : null,
            ),
            IndicadorPainel(
              rotulo: 'Vencido',
              valor: formatMoney(t.vencido),
              icone: Icons.error_outline_rounded,
              detalhe: t.vencido > 0 ? 'cobrar ou renegociar' : 'nada atrasado',
              cor: t.vencido > 0 ? neu.danger : null,
            ),
            IndicadorPainel(
              rotulo: 'Categorias',
              valor: '${linhas.length}',
              icone: Icons.category_outlined,
              detalhe: maior == null ? null : 'maior: ${maior.categoryName}',
            ),
            IndicadorPainel(
              rotulo: 'Concentração',
              valor: '${(concentracao * 100).round()}%',
              icone: Icons.pie_chart_outline_rounded,
              detalhe: 'numa categoria só',
              // Acima de 60% numa categoria só, cortar custo vira uma
              // negociação com um fornecedor — e não um esforço difuso.
              cor: concentracao >= 0.6 ? neu.warning : null,
            ),
            IndicadorPainel(
              rotulo: 'Saiu do caixa',
              valor: formatMoney(saiu.fold<double>(0, (a, b) => a + b)),
              icone: Icons.north_east_rounded,
              detalhe: '$diasComSaida dias com saída',
            ),
            IndicadorPainel(
              rotulo: 'Maior saída num dia',
              valor: formatMoney(maiorSaida),
              icone: Icons.trending_down_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),
        GradeDeGraficos(
          cards: [
            CardDeGrafico(
              titulo: 'Para onde foi o dinheiro',
              subtitulo: 'Despesas previstas por categoria',
              valor: formatMoney(t.previsto),
              info: 'O valor previsto de cada categoria no período. Saber que '
                  'a despesa subiu é informação; saber que subiu em peças é o '
                  'que dá para resolver.',
              vazio: linhas.isEmpty,
              mensagemVazio: 'Nenhuma despesa no período.',
              child: RoscaComCentro(
                centroValor: compactoEmReais(t.previsto),
                centroRotulo: 'previstos',
                fatias: [
                  for (var i = 0; i < linhas.length; i++)
                    (
                      rotulo: linhas[i].categoryName,
                      valor: linhas[i].previsto.toDouble(),
                      texto: formatMoney(linhas[i].previsto),
                      cor: _cor(linhas[i].categoryColor) ??
                          neu.glyphs[i % neu.glyphs.length],
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Previsto × pago, por categoria',
              subtitulo: 'O compromisso contra o que já saiu da conta',
              valor: formatMoney(t.pago),
              info: 'Barra de pago bem menor que a de previsto é conta que '
                  'ainda vai vencer — ou que já venceu. É onde o aperto do '
                  'fim do mês começa a aparecer.',
              vazio: linhas.isEmpty,
              child: BarrasComparadas(
                categorias: [for (final l in linhas.take(5)) l.categoryName],
                primeira: [
                  for (final l in linhas.take(5)) l.previsto.toDouble(),
                ],
                segunda: [for (final l in linhas.take(5)) l.pago.toDouble()],
                rotuloPrimeira: 'Previsto',
                rotuloSegunda: 'Pago',
              ),
            ),
            CardDeGrafico(
              titulo: 'As maiores contas',
              subtitulo: 'Categorias do maior para o menor valor previsto',
              valor: '${linhas.length}',
              info: 'A mesma composição da rosca, em ordem e com o número '
                  'escrito — para quem precisa levar o valor para uma '
                  'conversa com o fornecedor.',
              vazio: linhas.isEmpty,
              child: RankingDeBarras(
                itens: [
                  for (var i = 0; i < linhas.length; i++)
                    (
                      rotulo: linhas[i].categoryName,
                      valor: linhas[i].previsto,
                      texto: formatMoney(linhas[i].previsto),
                      cor: _cor(linhas[i].categoryColor) ??
                          neu.glyphs[i % neu.glyphs.length],
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'O que ainda não foi pago',
              subtitulo: 'Em aberto e vencido, por categoria',
              valor: formatMoney(t.emAberto),
              info: 'Vencido é a parte do "em aberto" que já passou da data. '
                  'Uma categoria com muito vencido costuma ser um fornecedor '
                  'esperando — e uma conversa que vale ter antes do telefonema.',
              vazio: linhas.every((l) => l.emAberto <= 0),
              mensagemVazio: 'Tudo pago no período.',
              child: BarrasComparadas(
                categorias: [
                  for (final l in linhas.where((l) => l.emAberto > 0).take(5))
                    l.categoryName,
                ],
                primeira: [
                  for (final l in linhas.where((l) => l.emAberto > 0).take(5))
                    l.emAberto.toDouble(),
                ],
                segunda: [
                  for (final l in linhas.where((l) => l.emAberto > 0).take(5))
                    l.vencido.toDouble(),
                ],
                rotuloPrimeira: 'Em aberto',
                rotuloSegunda: 'Vencido',
              ),
            ),
            CardDeGrafico(
              titulo: 'Saídas do caixa, dia a dia',
              // Este card lê o CAIXA, não a tabela de despesas: a saída de
              // dinheiro não guarda a categoria da conta que pagou. Com um
              // filtro ativo ele diz isso, em vez de mostrar o mês inteiro
              // calado ao lado de cinco cards recortados.
              subtitulo: categoria == null
                  ? 'Quando o dinheiro de fato saiu da gaveta'
                  : 'Todas as categorias — a saída de caixa não guarda a categoria',
              valor: formatMoney(saiu.fold<double>(0, (a, b) => a + b)),
              info: 'Despesa prevista é compromisso; isto é dinheiro saindo. '
                  'Os picos são os dias em que várias contas venceram juntas.',
              vazio: dias.isEmpty,
              mensagemVazio: 'Nenhuma saída de caixa no período.',
              rodape: RodapeDeCard(itens: [
                ('Dias com saída', '$diasComSaida'),
                ('Maior saída', formatMoney(maiorSaida)),
                (
                  'Média por dia com saída',
                  formatMoney(
                    diasComSaida == 0
                        ? 0
                        : saiu.fold<double>(0, (a, b) => a + b) / diasComSaida,
                  ),
                ),
              ]),
              child: ColunasPorDia(dias: dias, valores: saiu, cor: neu.danger),
            ),
            CardDeGrafico(
              titulo: 'Quantos lançamentos por categoria',
              subtitulo: 'A contagem, não o valor',
              valor: '${t.count}',
              info: 'Muitas contas pequenas numa categoria pedem um '
                  'fornecedor único ou um lançamento recorrente; uma conta '
                  'grande e solitária pede negociação.',
              vazio: linhas.isEmpty,
              child: RankingDeBarras(
                itens: [
                  for (var i = 0; i < linhas.length; i++)
                    (
                      rotulo: linhas[i].categoryName,
                      valor: linhas[i].count,
                      texto: '${linhas[i].count}',
                      cor: neu.navy,
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "#E08A2E" → Color. A categoria escolhe a própria cor nas Configurações; o
/// relatório respeita essa escolha para a mesma categoria não ser verde aqui
/// e laranja na tela de despesas.
Color? _cor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final limpo = hex.replaceAll('#', '').trim();
  if (limpo.length != 6) return null;
  final v = int.tryParse(limpo, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}
