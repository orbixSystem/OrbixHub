import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../domain/report_models.dart';
import '../report_providers.dart';
import '../widgets/charts/graficos.dart';
import '../widgets/painel.dart';

/// O painel de Faturamento.
///
/// Uma chamada só — o detalhamento linha a linha que a tabela já usa — e seis
/// leituras tiradas dela. É de propósito: painel e tabela somando a mesma
/// coisa de fontes diferentes divergiriam no primeiro ajuste, e o dono ficaria
/// com dois números para a mesma pergunta e nada dizendo qual vale.
class PainelDeFaturamento extends ConsumerWidget {
  const PainelDeFaturamento({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesLedgerReportProvider);
    return async.when(
      loading: () => const PainelCarregando(),
      error: (_, _) => PainelComErro(
        onRetry: () => ref.invalidate(salesLedgerReportProvider),
      ),
      data: (ledger) => _Painel(linhas: ledger.rows),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({required this.linhas});

  final List<SalesLedgerRow> linhas;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cores = coresDeSerie(context);
    final n = _Numeros.de(linhas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FaixaDeIndicadores(
          itens: [
            IndicadorPainel(
              rotulo: 'Faturado no período',
              valor: formatMoney(n.total),
              icone: Icons.payments_outlined,
              detalhe: '${n.documentos} documentos',
            ),
            IndicadorPainel(
              rotulo: 'Ticket médio',
              valor: formatMoney(n.ticket),
              icone: Icons.receipt_long_outlined,
              detalhe: 'por documento',
            ),
            IndicadorPainel(
              rotulo: 'Melhor dia',
              valor: formatMoney(n.pico),
              icone: Icons.trending_up_rounded,
              detalhe: n.diaDoPico == null ? null : 'dia ${diaCurto(n.diaDoPico!)}',
            ),
            IndicadorPainel(
              rotulo: 'Média por dia útil',
              valor: formatMoney(n.media),
              icone: Icons.calendar_today_outlined,
              detalhe: '${n.diasComMovimento} dias com venda',
            ),
            IndicadorPainel(
              rotulo: 'Serviço',
              valor: formatMoney(n.servico),
              icone: Icons.build_outlined,
              detalhe: fatiaDoTotal(n.servico, n.total),
            ),
            IndicadorPainel(
              rotulo: 'Produto',
              valor: formatMoney(n.produto),
              icone: Icons.inventory_2_outlined,
              detalhe: fatiaDoTotal(n.produto, n.total),
            ),
            IndicadorPainel(
              rotulo: 'Já pago',
              valor: formatMoney(n.pago),
              icone: Icons.task_alt_rounded,
              detalhe: fatiaDoTotal(n.pago, n.total),
              cor: n.total > 0 && n.pago >= n.total * 0.7 ? neu.success : null,
            ),
            IndicadorPainel(
              rotulo: 'A receber',
              valor: formatMoney(n.aReceber),
              icone: Icons.schedule_outlined,
              detalhe: fatiaDoTotal(n.aReceber, n.total),
              cor: n.aReceber > 0 ? neu.warning : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        GradeDeGraficos(
          cards: [
            CardDeGrafico(
              titulo: 'Faturado por dia',
              subtitulo: 'Todo documento do período, na data em que foi emitido',
              valor: formatMoney(n.total),
              info: 'Soma do valor de cada ordem faturada e de cada venda de '
                  'balcão, pelo dia da emissão. O dia de maior movimento fica '
                  'destacado.',
              vazio: n.dias.isEmpty,
              rodape: RodapeDeCard(itens: [
                ('Média por dia útil', formatMoney(n.media)),
                ('Melhor dia', formatMoney(n.pico)),
                ('Pior dia com venda', formatMoney(n.vale)),
              ]),
              child: ColunasPorDia(dias: n.dias, valores: n.porDia),
            ),
            CardDeGrafico(
              titulo: 'Serviço × produto, dia a dia',
              subtitulo: 'Mão de obra contra peça vendida',
              valor: formatMoney(n.total),
              info: 'A mesma receita, separada pelo que foi cobrado. Oficina '
                  'que vive de peça e oficina que vive de mão de obra têm '
                  'custos diferentes — e o gráfico mostra qual das duas é esta.',
              vazio: n.dias.isEmpty,
              rodape: RodapeDeCard(itens: [
                ('Serviço', formatMoney(n.servico)),
                ('Produto', formatMoney(n.produto)),
                ('Proporção', '${fatiaDoTotal(n.servico, n.total)} serviço'),
              ]),
              child: LinhasPorDia(
                dias: n.dias,
                series: [
                  SerieNomeada(
                    nome: 'Serviço',
                    valores: n.servicoPorDia,
                    cor: cores.principal,
                    preenchida: true,
                  ),
                  SerieNomeada(
                    nome: 'Produto',
                    valores: n.produtoPorDia,
                    cor: cores.secundaria,
                  ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Documentos por dia',
              subtitulo: 'Quantas ordens e vendas saíram em cada dia',
              valor: '${n.documentos}',
              info: 'A contagem, não o valor. Um dia de muito dinheiro com um '
                  'documento só é um serviço grande; muitos documentos pequenos '
                  'é balcão movimentado. São negócios diferentes.',
              vazio: n.dias.isEmpty,
              rodape: RodapeDeCard(itens: [
                ('Documentos', '${n.documentos}'),
                ('Média por dia útil',
                    n.diasComMovimento == 0
                        ? '0'
                        : (n.documentos / n.diasComMovimento).toStringAsFixed(1)),
                ('Ticket médio', formatMoney(n.ticket)),
              ]),
              child: ColunasPorDia(
                dias: n.dias,
                valores: n.contagemPorDia,
                dinheiro: false,
                cor: neu.info,
              ),
            ),
            CardDeGrafico(
              titulo: 'De onde veio o faturamento',
              subtitulo: 'Ordem de serviço contra venda de balcão',
              valor: formatMoney(n.total),
              info: 'Ordem de serviço é trabalho agendado e executado; venda '
                  'de balcão é peça saindo pela porta. Saber a mistura é o que '
                  'diz se vale abrir mais boxes ou ampliar a prateleira.',
              vazio: n.total <= 0,
              child: RoscaComCentro(
                centroValor: compactoEmReais(n.total),
                centroRotulo: 'faturados',
                fatias: [
                  (
                    rotulo: 'Ordens de serviço',
                    valor: n.porOs.toDouble(),
                    texto: formatMoney(n.porOs),
                    cor: cores.principal,
                  ),
                  (
                    rotulo: 'Vendas de balcão',
                    valor: n.porBalcao.toDouble(),
                    texto: formatMoney(n.porBalcao),
                    cor: cores.secundaria,
                  ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Quanto já virou dinheiro',
              subtitulo: 'Situação de pagamento do que foi faturado',
              valor: formatMoney(n.total),
              info: 'Faturar não é receber. Esta é a parte do período que já '
                  'entrou, a que está anotada e a que foi paga pela metade.',
              vazio: n.total <= 0,
              child: RoscaComCentro(
                centroValor: compactoEmReais(n.pago),
                centroRotulo: 'já recebidos',
                fatias: [
                  (
                    rotulo: 'Pago',
                    valor: n.pago.toDouble(),
                    texto: formatMoney(n.pago),
                    cor: neu.success,
                  ),
                  (
                    rotulo: 'Parcial',
                    valor: n.parcial.toDouble(),
                    texto: formatMoney(n.parcial),
                    cor: neu.warning,
                  ),
                  (
                    rotulo: 'A receber',
                    valor: n.aReceber.toDouble(),
                    texto: formatMoney(n.aReceber),
                    cor: neu.danger,
                  ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Quem mais gastou aqui',
              subtitulo: 'Os maiores clientes do período',
              valor: '${n.clientes.length}',
              info: 'Soma do que cada cliente faturou no período, do maior '
                  'para o menor. Quando um cliente sozinho sustenta o mês, a '
                  'oficina tem um risco, não uma conquista.',
              vazio: n.clientes.isEmpty,
              child: RankingDeBarras(
                itens: [
                  for (final c in n.clientes)
                    (rotulo: c.nome, valor: c.valor, texto: formatMoney(c.valor), cor: null),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Os números do período, tirados UMA vez das linhas.
///
/// Juntos numa classe, e não espalhados em getters no build: a tela monta seis
/// cards a partir deles, e recalcular a cada card faria o mesmo laço rodar
/// dezenas de vezes a cada frame de animação.
class _Numeros {
  _Numeros._({
    required this.dias,
    required this.porDia,
    required this.servicoPorDia,
    required this.produtoPorDia,
    required this.contagemPorDia,
    required this.total,
    required this.servico,
    required this.produto,
    required this.porOs,
    required this.porBalcao,
    required this.pago,
    required this.parcial,
    required this.aReceber,
    required this.documentos,
    required this.clientes,
  });

  final List<String> dias;
  final List<double> porDia;
  final List<double> servicoPorDia;
  final List<double> produtoPorDia;
  final List<double> contagemPorDia;
  final num total;
  final num servico;
  final num produto;
  final num porOs;
  final num porBalcao;
  final num pago;
  final num parcial;
  final num aReceber;
  final int documentos;
  final List<({String nome, num valor})> clientes;

  int get diasComMovimento => porDia.where((v) => v > 0).length;
  double get media => diasComMovimento == 0 ? 0 : total / diasComMovimento;
  double get ticket => documentos == 0 ? 0 : total / documentos;
  double get pico => porDia.fold<double>(0, (a, b) => b > a ? b : a);
  double get vale {
    final comVenda = porDia.where((v) => v > 0);
    return comVenda.isEmpty ? 0 : comVenda.reduce((a, b) => a < b ? a : b);
  }

  String? get diaDoPico =>
      pico <= 0 ? null : dias[porDia.indexWhere((v) => v == pico)];

  static _Numeros de(List<SalesLedgerRow> linhas) {
    final porDia = <String, double>{};
    final servicoPorDia = <String, double>{};
    final produtoPorDia = <String, double>{};
    final contagem = <String, double>{};
    final porCliente = <String, num>{};
    num total = 0, servico = 0, produto = 0, porOs = 0, porBalcao = 0;
    num pago = 0, parcial = 0, aReceber = 0;

    for (final l in linhas) {
      // A data vem ISO com hora; o gráfico é por dia.
      final dia = l.date.length >= 10 ? l.date.substring(0, 10) : l.date;
      final v = l.value.toDouble();
      porDia[dia] = (porDia[dia] ?? 0) + v;
      contagem[dia] = (contagem[dia] ?? 0) + 1;
      total += l.value;
      if (l.type == 'produto') {
        produto += l.value;
        produtoPorDia[dia] = (produtoPorDia[dia] ?? 0) + v;
      } else {
        servico += l.value;
        servicoPorDia[dia] = (servicoPorDia[dia] ?? 0) + v;
      }
      if (l.origin == 'sale') {
        porBalcao += l.value;
      } else {
        porOs += l.value;
      }
      switch (l.paymentStatus) {
        case 'pago':
          pago += l.value;
        case 'parcial':
          parcial += l.value;
        default:
          aReceber += l.value;
      }
      final nome = (l.customerName ?? '').trim();
      if (nome.isNotEmpty) porCliente[nome] = (porCliente[nome] ?? 0) + l.value;
    }

    final dias = porDia.keys.toList()..sort();
    final clientes = porCliente.entries
        .map((e) => (nome: e.key, valor: e.value))
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));

    return _Numeros._(
      dias: dias,
      porDia: [for (final d in dias) porDia[d] ?? 0],
      servicoPorDia: [for (final d in dias) servicoPorDia[d] ?? 0],
      produtoPorDia: [for (final d in dias) produtoPorDia[d] ?? 0],
      contagemPorDia: [for (final d in dias) contagem[d] ?? 0],
      total: total,
      servico: servico,
      produto: produto,
      porOs: porOs,
      porBalcao: porBalcao,
      pago: pago,
      parcial: parcial,
      aReceber: aReceber,
      documentos: linhas.length,
      clientes: clientes,
    );
  }
}
