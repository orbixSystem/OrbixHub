import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../../cashier/domain/cashier_models.dart';
import '../../domain/monthly_models.dart';
import '../report_providers.dart';
import '../widgets/charts/graficos.dart';
import '../widgets/painel.dart';

/// O painel do Caixa.
///
/// A pergunta aqui não é "quanto faturei" — é "quanto virou dinheiro, por
/// onde entrou e no que foi gasto". São três perguntas que o total do período
/// esconde: um mês pode fechar positivo tendo passado três semanas no
/// vermelho, e um saldo bonito pode ser quase todo cartão a receber.
class PainelDeCaixa extends ConsumerWidget {
  const PainelDeCaixa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumo = ref.watch(cashierRecebidoReportProvider);
    final visao = ref.watch(visaoMensalProvider);

    return resumo.when(
      loading: () => const PainelCarregando(),
      error: (_, _) => PainelComErro(
        onRetry: () => ref.invalidate(cashierRecebidoReportProvider),
      ),
      data: (r) => _Painel(
        resumo: r,
        // A série diária vem da mesma função que alimenta a Visão: duas
        // somas independentes do "movimento do mês" divergiriam no primeiro
        // ajuste, e a tela passaria a discordar de si mesma entre abas.
        movimento: visao.value?.graficos.movimentoPorDia ?? const [],
      ),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({required this.resumo, required this.movimento});

  final CashSummary resumo;
  final List<MovimentoDiario> movimento;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;

    final dias = [for (final m in movimento) m.dia];
    final entrou = [for (final m in movimento) m.entrou.toDouble()];
    final saiu = [for (final m in movimento) m.saiu.toDouble()];
    final saldoDiario = [
      for (var i = 0; i < movimento.length; i++) entrou[i] - saiu[i],
    ];
    final diasNegativos = saldoDiario.where((v) => v < 0).length;

    final formas = resumo.byMethod.where((m) => m.inAmount > 0).toList()
      ..sort((a, b) => b.inAmount.compareTo(a.inAmount));
    final saidas = resumo.byCategory.where((c) => c.outAmount > 0).toList()
      ..sort((a, b) => b.outAmount.compareTo(a.outAmount));
    final origens = resumo.byOrigin.where((o) => o.inAmount > 0).toList()
      ..sort((a, b) => b.inAmount.compareTo(a.inAmount));

    final melhorDia = entrou.fold<double>(0, (a, b) => b > a ? b : a);
    final piorDia = saldoDiario.isEmpty
        ? 0.0
        : saldoDiario.reduce((a, b) => a < b ? a : b);
    final diasComEntrada = entrou.where((v) => v > 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FaixaDeIndicadores(
          itens: [
            IndicadorPainel(
              rotulo: 'Entrou',
              valor: formatMoney(resumo.totalIn),
              icone: Icons.south_west_rounded,
              detalhe: '$diasComEntrada dias com recebimento',
              cor: neu.success,
            ),
            IndicadorPainel(
              rotulo: 'Saiu',
              valor: formatMoney(resumo.totalOut),
              icone: Icons.north_east_rounded,
              detalhe: fatiaDoTotal(resumo.totalOut, resumo.totalIn)
                  .replaceAll('do total', 'do que entrou'),
              cor: resumo.totalOut > 0 ? neu.danger : null,
            ),
            IndicadorPainel(
              rotulo: 'Saldo do período',
              valor: formatMoney(resumo.net),
              icone: Icons.account_balance_wallet_outlined,
              detalhe: resumo.net >= 0 ? 'no azul' : 'no vermelho',
              cor: resumo.net >= 0 ? neu.success : neu.danger,
            ),
            IndicadorPainel(
              rotulo: 'Desconto concedido',
              valor: formatMoney(resumo.totalDiscount),
              icone: Icons.percent_rounded,
              detalhe: 'fecha dívida sem entrar dinheiro',
              cor: resumo.totalDiscount > 0 ? neu.warning : null,
            ),
            IndicadorPainel(
              rotulo: 'Melhor dia',
              valor: formatMoney(melhorDia),
              icone: Icons.trending_up_rounded,
              detalhe: 'maior entrada num só dia',
            ),
            IndicadorPainel(
              rotulo: 'Média por dia com caixa',
              valor: formatMoney(
                diasComEntrada == 0 ? 0 : resumo.totalIn / diasComEntrada,
              ),
              icone: Icons.calendar_today_outlined,
            ),
            IndicadorPainel(
              rotulo: 'Dias no vermelho',
              valor: '$diasNegativos',
              icone: Icons.warning_amber_rounded,
              detalhe: diasNegativos == 0 ? 'nenhum' : 'saiu mais do que entrou',
              cor: diasNegativos > 0 ? neu.warning : null,
            ),
            IndicadorPainel(
              rotulo: 'Formas usadas',
              valor: '${formas.length}',
              icone: Icons.credit_card_outlined,
              detalhe: formas.isEmpty
                  ? null
                  : 'maior: ${methodLabel(formas.first.method)}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        GradeDeGraficos(
          cards: [
            CardDeGrafico(
              titulo: 'Entrou × saiu, dia a dia',
              subtitulo: 'O movimento real do caixa ao longo do período',
              valor: formatMoney(resumo.net),
              info: 'Entradas e saídas registradas no caixa, sem estornos. '
                  'Um período que fecha positivo pode ter passado semanas no '
                  'vermelho — e é isso que o total esconde.',
              vazio: dias.isEmpty,
              mensagemVazio: 'Nenhum movimento de caixa no período.',
              rodape: RodapeDeCard(itens: [
                ('Entrou', formatMoney(resumo.totalIn)),
                ('Saiu', formatMoney(resumo.totalOut)),
                ('Saldo', formatMoney(resumo.net)),
              ]),
              child: LinhasPorDia(
                dias: dias,
                series: [
                  SerieNomeada(
                    nome: 'Entrou',
                    valores: entrou,
                    cor: neu.success,
                    preenchida: true,
                  ),
                  SerieNomeada(nome: 'Saiu', valores: saiu, cor: neu.danger),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Sobrou ou faltou, por dia',
              subtitulo: 'Entrada menos saída de cada dia',
              valor: formatMoney(resumo.net),
              info: 'A diferença dos dois traços do gráfico ao lado, dia a '
                  'dia. Barras para baixo são dias em que saiu mais dinheiro '
                  'do que entrou.',
              vazio: dias.isEmpty,
              rodape: RodapeDeCard(itens: [
                ('Dias no azul', '${saldoDiario.where((v) => v > 0).length}'),
                ('Dias no vermelho', '$diasNegativos'),
                ('Pior dia', formatMoney(piorDia)),
              ]),
              child: ColunasPorDia(
                dias: dias,
                valores: saldoDiario,
                cor: neu.navy,
              ),
            ),
            CardDeGrafico(
              titulo: 'Como o dinheiro entrou',
              subtitulo: 'Recebimentos por forma de pagamento',
              valor: formatMoney(resumo.totalIn),
              info: 'Só entradas. Serve para negociar taxa de cartão e para '
                  'saber se o pix já virou a regra da casa.',
              vazio: formas.isEmpty,
              mensagemVazio: 'Nenhum recebimento no período.',
              child: RoscaComCentro(
                centroValor: compactoEmReais(resumo.totalIn),
                centroRotulo: 'recebidos',
                fatias: [
                  for (var i = 0; i < formas.length; i++)
                    (
                      rotulo: methodLabel(formas[i].method),
                      valor: formas[i].inAmount.toDouble(),
                      texto: formatMoney(formas[i].inAmount),
                      cor: neu.glyphs[i % neu.glyphs.length],
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'No que o caixa foi gasto',
              subtitulo: 'Saídas por categoria de lançamento',
              valor: formatMoney(resumo.totalOut),
              info: 'Saídas registradas no caixa, agrupadas pela categoria do '
                  'lançamento. É dinheiro que saiu da gaveta — não a despesa '
                  'prevista do mês, que mora na aba Despesas.',
              vazio: saidas.isEmpty,
              mensagemVazio: 'Nenhuma saída registrada no período.',
              child: RankingDeBarras(
                itens: [
                  for (final c in saidas)
                    (
                      rotulo: categoryLabel(c.key),
                      valor: c.outAmount,
                      texto: formatMoney(c.outAmount),
                      cor: neu.danger,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'De onde vieram os recebimentos',
              subtitulo: 'Ordem de serviço, venda de balcão ou avulso',
              valor: formatMoney(resumo.totalIn),
              info: 'A origem do lançamento. "Nenhum" é dinheiro que entrou '
                  'sem venda vinculada — aporte, acerto, devolução.',
              vazio: origens.isEmpty,
              child: RankingDeBarras(
                itens: [
                  for (var i = 0; i < origens.length; i++)
                    (
                      rotulo: _origemLegivel(origens[i].key),
                      valor: origens[i].inAmount,
                      texto: formatMoney(origens[i].inAmount),
                      cor: neu.glyphs[i % neu.glyphs.length],
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Cada forma, entrada e saída',
              subtitulo: 'O que entrou e o que saiu por meio de pagamento',
              valor: formatMoney(resumo.totalIn - resumo.totalOut),
              info: 'Dinheiro vivo costuma ser o único meio com saída: é dele '
                  'que sai o pagamento de balcão. Saída alta num meio '
                  'eletrônico merece conferência.',
              vazio: resumo.byMethod.isEmpty,
              child: BarrasComparadas(
                categorias: [
                  for (final m in resumo.byMethod.take(5))
                    methodLabel(m.method),
                ],
                primeira: [
                  for (final m in resumo.byMethod.take(5))
                    m.inAmount.toDouble(),
                ],
                segunda: [
                  for (final m in resumo.byMethod.take(5))
                    m.outAmount.toDouble(),
                ],
                rotuloPrimeira: 'Entrou',
                rotuloSegunda: 'Saiu',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A origem de um lançamento, escrita como o dono fala.
String _origemLegivel(String key) => switch (key) {
      'os' => 'Ordem de serviço',
      'sale' => 'Venda de balcão',
      'nenhum' => 'Sem venda vinculada',
      _ => key,
    };
