import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../../dashboard/presentation/dashboard_providers.dart';
import '../../domain/report_models.dart';
import '../report_providers.dart';
import '../widgets/charts/graficos.dart';
import '../widgets/painel.dart';

/// O painel de Estoque.
///
/// Estoque não tem período: é uma foto do agora. A pergunta que ele responde
/// não é "quanto girou", é "quanto dinheiro está parado na prateleira e o que
/// vai faltar na hora do serviço".
class PainelDeEstoque extends ConsumerWidget {
  const PainelDeEstoque({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagina = ref.watch(painelEstoqueProvider);
    final metricas = ref.watch(inventoryMetricsProvider);
    final pecasVendidas = ref.watch(painelTopItensProvider('product'));

    final situacao = ref.watch(reportFiltersProvider).estoqueSituacao;

    return pagina.when(
      loading: () => const PainelCarregando(),
      error: (_, _) => PainelComErro(
        onRetry: () => ref.invalidate(painelEstoqueProvider),
      ),
      data: (r) => _Painel(
        relatorio: _recortar(r, situacao),
        abaixoDoMinimo: metricas.value?.belowMin ?? 0,
        maisVendidas: pecasVendidas.value?.rows ?? const [],
      ),
    );
  }
}

/// Aplica o recorte de situação sobre as linhas.
///
/// A busca já foi ao servidor; esta parte é de tela, porque "abaixo do
/// mínimo" é uma comparação entre duas colunas e o endpoint de estoque não a
/// conhece como filtro. O `stockValue` NÃO é recalculado: ele é o valor
/// global da prateleira inteira, e reduzi-lo ao recorte faria o KPI de
/// "dinheiro parado" diminuir sempre que alguém filtrasse.
InventoryReport _recortar(InventoryReport r, String? situacao) {
  if (situacao == null) return r;
  bool cabe(InventoryReportRow l) => switch (situacao) {
        'zerado' => l.currentStock <= 0,
        'abaixo' => l.belowMin,
        'ok' => !l.belowMin && l.currentStock > 0,
        _ => true,
      };
  return r.copyWith(rows: r.rows.where(cabe).toList());
}

class _Painel extends StatelessWidget {
  const _Painel({
    required this.relatorio,
    required this.abaixoDoMinimo,
    required this.maisVendidas,
  });

  final InventoryReport relatorio;
  final int abaixoDoMinimo;
  final List<TopItemRow> maisVendidas;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cores = coresDeSerie(context);
    final linhas = relatorio.rows;

    // A página do painel cobre até 200 itens (o teto do endpoint). Acima
    // disso os rankings viram amostra, e a tela diz isso em vez de fingir que
    // leu o estoque inteiro.
    final amostra = relatorio.total > linhas.length;

    final porValor = [...linhas]
      ..sort((a, b) => b.stockValue.compareTo(a.stockValue));
    final faltando = linhas.where((l) => l.belowMin).toList()
      ..sort((a, b) => a.currentStock.compareTo(b.currentStock));
    final zerados = linhas.where((l) => l.currentStock <= 0).length;
    final semMinimo = linhas.where((l) => (l.minStock ?? 0) <= 0).length;

    final comMargem = linhas
        .where((l) => (l.costPrice ?? 0) > 0 && (l.salePrice ?? 0) > 0)
        .toList();
    final margens = [
      for (final l in comMargem)
        (
          nome: l.name,
          pct: ((l.salePrice! - l.costPrice!) / l.costPrice!) * 100,
        ),
    ]..sort((a, b) => b.pct.compareTo(a.pct));
    final margemMedia = margens.isEmpty
        ? 0.0
        : margens.fold<double>(0, (a, m) => a + m.pct) / margens.length;

    final topoValor = porValor.isEmpty ? null : porValor.first;
    final concentracao = relatorio.stockValue <= 0 || topoValor == null
        ? 0.0
        : topoValor.stockValue / relatorio.stockValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FaixaDeIndicadores(
          itens: [
            IndicadorPainel(
              rotulo: 'Valor em estoque',
              valor: formatMoney(relatorio.stockValue),
              icone: Icons.inventory_2_outlined,
              detalhe: 'dinheiro parado na prateleira',
            ),
            IndicadorPainel(
              rotulo: 'Itens cadastrados',
              valor: '${relatorio.total}',
              icone: Icons.widgets_outlined,
              detalhe: amostra ? 'painel lê ${linhas.length}' : null,
            ),
            IndicadorPainel(
              rotulo: 'Abaixo do mínimo',
              valor: '$abaixoDoMinimo',
              icone: Icons.warning_amber_rounded,
              detalhe: abaixoDoMinimo == 0 ? 'nada faltando' : 'comprar',
              cor: abaixoDoMinimo > 0 ? neu.warning : null,
            ),
            IndicadorPainel(
              rotulo: 'Zerados',
              valor: '$zerados',
              icone: Icons.remove_shopping_cart_outlined,
              detalhe: zerados == 0 ? 'nenhum' : 'sem nenhuma unidade',
              cor: zerados > 0 ? neu.danger : null,
            ),
            IndicadorPainel(
              rotulo: 'Margem média',
              valor: '${margemMedia.round()}%',
              icone: Icons.trending_up_rounded,
              detalhe: '${comMargem.length} itens com custo e venda',
            ),
            IndicadorPainel(
              rotulo: 'Sem mínimo definido',
              valor: '$semMinimo',
              icone: Icons.help_outline_rounded,
              // Item sem mínimo nunca entra no aviso de falta: ele some do
              // radar justamente na hora em que acaba.
              detalhe: semMinimo == 0 ? 'todos configurados' : 'nunca avisam',
              cor: semMinimo > 0 ? neu.warning : null,
            ),
            IndicadorPainel(
              rotulo: 'Item de maior valor',
              valor: topoValor == null
                  ? '—'
                  : formatMoney(topoValor.stockValue),
              icone: Icons.star_outline_rounded,
              detalhe: topoValor?.name,
            ),
            IndicadorPainel(
              rotulo: 'Concentração',
              valor: '${(concentracao * 100).round()}%',
              icone: Icons.pie_chart_outline_rounded,
              detalhe: 'num item só',
              cor: concentracao >= 0.4 ? neu.warning : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        GradeDeGraficos(
          cards: [
            CardDeGrafico(
              titulo: 'Onde o dinheiro está parado',
              subtitulo: 'Itens por valor em estoque',
              valor: formatMoney(relatorio.stockValue),
              info: 'Quantidade vezes custo. É o capital que está na '
                  'prateleira em vez de estar no caixa — e a primeira lista a '
                  'olhar quando falta dinheiro para pagar conta.',
              vazio: porValor.isEmpty,
              mensagemVazio: 'Nenhum item em estoque.',
              child: RankingDeBarras(
                itens: [
                  for (final l in porValor)
                    (
                      rotulo: l.name,
                      valor: l.stockValue,
                      texto: formatMoney(l.stockValue),
                      cor: cores.principal,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'O que vai faltar',
              subtitulo: 'Itens abaixo do mínimo, do mais crítico',
              valor: '$abaixoDoMinimo',
              info: 'Peça que falta na hora do serviço vira ordem parada '
                  'esperando compra. A barra mostra quanto resta em relação '
                  'ao mínimo configurado.',
              vazio: faltando.isEmpty,
              mensagemVazio: 'Nenhum item abaixo do mínimo.',
              child: RankingDeBarras(
                // Zero aqui é a notícia: item zerado tem barra vazia E é o
                // mais urgente da lista. E a escala é o PRÓPRIO mínimo, não o
                // maior da lista: quatro itens igualmente faltando não podem
                // virar quatro barras cheias.
                ocultarZeros: false,
                maximoFixo: 1,
                itens: [
                  for (final l in faltando)
                    (
                      rotulo: l.name,
                      valor: (l.minStock ?? 0) <= 0
                          ? 0
                          : l.currentStock / l.minStock!,
                      texto:
                          '${_qtd(l.currentStock)} de ${_qtd(l.minStock ?? 0)}',
                      cor: l.currentStock <= 0 ? neu.danger : neu.warning,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'As peças que mais saem',
              subtitulo: 'Produtos vendidos no período, por receita',
              valor: '${maisVendidas.length}',
              info: 'A lista que deveria guiar a compra do mês. Item que '
                  'vende muito e aparece em "o que vai faltar" é a compra '
                  'mais urgente da oficina.',
              vazio: maisVendidas.isEmpty,
              mensagemVazio: 'Nenhuma peça vendida no período.',
              child: RankingDeBarras(
                itens: [
                  for (final p in maisVendidas)
                    (
                      rotulo: p.name,
                      valor: p.revenue,
                      texto: formatMoney(p.revenue),
                      cor: cores.secundaria,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Maiores margens',
              subtitulo: 'Diferença entre preço de venda e custo',
              valor: '${margemMedia.round()}%',
              info: 'Margem sobre o custo cadastrado. Serve para decidir o '
                  'que empurrar no balcão — e para encontrar o item cujo '
                  'preço ficou velho.',
              vazio: margens.isEmpty,
              mensagemVazio: 'Nenhum item com custo e preço de venda.',
              child: RankingDeBarras(
                itens: [
                  for (final m in margens)
                    (
                      rotulo: m.nome,
                      valor: m.pct,
                      texto: '${m.pct.round()}%',
                      cor: neu.success,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Como o estoque está',
              subtitulo: 'Itens por situação de quantidade',
              valor: '${linhas.length}',
              info: 'A foto do estoque em três estados. "Sem mínimo" não é '
                  'elogio nem problema de quantidade: é item que nunca vai '
                  'disparar o aviso de falta.',
              vazio: linhas.isEmpty,
              child: RoscaComCentro(
                centroValor: '${linhas.length}',
                centroRotulo: 'itens',
                fatias: [
                  (
                    rotulo: 'Acima do mínimo',
                    valor: linhas
                        .where((l) => !l.belowMin && l.currentStock > 0)
                        .length
                        .toDouble(),
                    texto: '${linhas.where((l) => !l.belowMin && l.currentStock > 0).length}',
                    cor: neu.success,
                  ),
                  (
                    rotulo: 'Abaixo do mínimo',
                    valor: faltando.where((l) => l.currentStock > 0).length.toDouble(),
                    texto: '${faltando.where((l) => l.currentStock > 0).length}',
                    cor: neu.warning,
                  ),
                  (
                    rotulo: 'Zerados',
                    valor: zerados.toDouble(),
                    texto: '$zerados',
                    cor: neu.danger,
                  ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Custo × venda dos itens de maior valor',
              subtitulo: 'O que cada peça custou e por quanto sai',
              valor: formatMoney(relatorio.stockValue),
              info: 'Barras encostadas de altura parecida são itens que quase '
                  'não deixam margem. Serve para revisar preço antes que o '
                  'balcão venda no prejuízo.',
              vazio: comMargem.isEmpty,
              child: BarrasComparadas(
                categorias: [
                  for (final l in porValor
                      .where((l) => (l.costPrice ?? 0) > 0)
                      .take(5))
                    l.name,
                ],
                primeira: [
                  for (final l in porValor
                      .where((l) => (l.costPrice ?? 0) > 0)
                      .take(5))
                    (l.costPrice ?? 0).toDouble(),
                ],
                segunda: [
                  for (final l in porValor
                      .where((l) => (l.costPrice ?? 0) > 0)
                      .take(5))
                    (l.salePrice ?? 0).toDouble(),
                ],
                rotuloPrimeira: 'Custo',
                rotuloSegunda: 'Venda',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "3" em vez de "3.0" — quantidade fracionária só aparece quando existe.
String _qtd(num v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);
