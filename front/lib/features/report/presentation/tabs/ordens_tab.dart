import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../../os/presentation/os_status.dart';
import '../../domain/monthly_models.dart';
import '../../domain/report_models.dart';
import '../report_providers.dart';
import '../widgets/charts/graficos.dart';
import '../widgets/painel.dart';

/// O painel de Ordens de Serviço.
///
/// Duas perguntas moram aqui e costumam ser confundidas: quanto a oficina
/// PRODUZIU (ordens faturadas, receita, ticket) e onde o trabalho ESTÁ (a
/// fila). Um mês fraco com fila cheia é um problema de execução; um mês fraco
/// com fila vazia é um problema de venda. O painel separa as duas.
class PainelDeOrdens extends ConsumerWidget {
  const PainelDeOrdens({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(salesLedgerReportProvider);
    final receita = ref.watch(revenueReportProvider);
    final visao = ref.watch(visaoMensalProvider);
    final servicos = ref.watch(painelTopItensProvider('service'));
    final pecas = ref.watch(painelTopItensProvider('product'));

    return ledger.when(
      loading: () => const PainelCarregando(),
      error: (_, _) => PainelComErro(
        onRetry: () => ref.invalidate(salesLedgerReportProvider),
      ),
      data: (l) => _Painel(
        // Só o que nasceu de ordem de serviço. `/report/revenue` soma OS e
        // balcão no mesmo número (e marca a parte do balcão como um "status"
        // chamado `venda`): usá-lo aqui faria a aba Ordens anunciar como
        // trabalho de oficina a peça que saiu pelo balcão.
        linhas: l.rows.where((r) => r.origin == 'os').toList(),
        porStatus: {
          for (final e in (receita.value?.byStatus ?? const {}).entries)
            if (e.key != 'venda') e.key: e.value,
        },
        fila: visao.value?.graficos.osPorStatus ?? const [],
        servicos: servicos.value?.rows ?? const [],
        pecas: pecas.value?.rows ?? const [],
      ),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({
    required this.linhas,
    required this.porStatus,
    required this.fila,
    required this.servicos,
    required this.pecas,
  });

  final List<SalesLedgerRow> linhas;
  final Map<String, CountRevenue> porStatus;
  final List<FatiaStatus> fila;
  final List<TopItemRow> servicos;
  final List<TopItemRow> pecas;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cores = coresDeSerie(context);

    // Uma ordem pode ter várias linhas no detalhamento (serviço e peça da
    // mesma OS): o dia soma valores, mas a CONTAGEM conta documentos.
    final porDia = <String, double>{};
    final docsPorDia = <String, Set<String>>{};
    for (final l in linhas) {
      final dia = l.date.length >= 10 ? l.date.substring(0, 10) : l.date;
      porDia[dia] = (porDia[dia] ?? 0) + l.value.toDouble();
      (docsPorDia[dia] ??= <String>{}).add(l.originNumber);
    }
    final dias = porDia.keys.toList()..sort();
    final valores = [for (final d in dias) porDia[d] ?? 0];
    final contagem = [for (final d in dias) (docsPorDia[d]?.length ?? 0).toDouble()];
    final ticketPorDia = [
      for (var i = 0; i < dias.length; i++)
        contagem[i] == 0 ? 0.0 : valores[i] / contagem[i],
    ];

    final total = valores.fold<double>(0, (a, b) => a + b);
    final faturadas =
        linhas.map((l) => l.originNumber).toSet().length;
    final ticketMedio = faturadas == 0 ? 0.0 : total / faturadas;
    final diasComOs = contagem.where((v) => v > 0).length;
    final pico = valores.fold<double>(0, (a, b) => b > a ? b : a);

    final naFila = fila.fold<int>(0, (a, s) => a + s.total);
    final emAndamento = fila
        .where((s) => !_encerrados.contains(s.status))
        .fold<int>(0, (a, s) => a + s.total);
    final receitaPorStatus = [...porStatus.entries]
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FaixaDeIndicadores(
          itens: [
            IndicadorPainel(
              rotulo: 'Receita de OS',
              valor: formatMoney(total),
              icone: Icons.handyman_outlined,
              detalhe: '$faturadas ordens faturadas',
            ),
            IndicadorPainel(
              rotulo: 'Ticket médio',
              valor: formatMoney(ticketMedio),
              icone: Icons.receipt_long_outlined,
              detalhe: 'por ordem',
            ),
            IndicadorPainel(
              rotulo: 'Ordens no período',
              valor: '$naFila',
              icone: Icons.assignment_outlined,
              detalhe: '$emAndamento ainda em andamento',
            ),
            IndicadorPainel(
              rotulo: 'Em andamento',
              valor: '$emAndamento',
              icone: Icons.pending_actions_outlined,
              detalhe: emAndamento == 0 ? 'fila vazia' : 'trabalho na casa',
              cor: emAndamento > 0 ? neu.warning : null,
            ),
            IndicadorPainel(
              rotulo: 'Dias com ordem faturada',
              valor: '$diasComOs',
              icone: Icons.calendar_today_outlined,
            ),
            IndicadorPainel(
              rotulo: 'Melhor dia',
              valor: formatMoney(pico),
              icone: Icons.trending_up_rounded,
            ),
            IndicadorPainel(
              rotulo: 'Serviços distintos',
              valor: '${servicos.length}',
              icone: Icons.build_outlined,
              detalhe: servicos.isEmpty ? null : 'top: ${servicos.first.name}',
            ),
            IndicadorPainel(
              rotulo: 'Peças distintas',
              valor: '${pecas.length}',
              icone: Icons.settings_outlined,
              detalhe: pecas.isEmpty ? null : 'top: ${pecas.first.name}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        GradeDeGraficos(
          cards: [
            CardDeGrafico(
              titulo: 'Receita de OS por dia',
              subtitulo: 'Só ordens de serviço, pela data de faturamento',
              valor: formatMoney(total),
              info: 'Venda de balcão não entra: aqui a pergunta é quanto a '
                  'oficina produziu de trabalho. O balcão está na aba '
                  'Faturamento, somado a este número.',
              vazio: dias.isEmpty,
              mensagemVazio: 'Nenhuma ordem faturada no período.',
              rodape: RodapeDeCard(itens: [
                ('Ordens', '$faturadas'),
                ('Ticket médio', formatMoney(ticketMedio)),
                ('Melhor dia', formatMoney(pico)),
              ]),
              child: ColunasPorDia(dias: dias, valores: valores),
            ),
            CardDeGrafico(
              titulo: 'Quantas ordens por dia',
              subtitulo: 'A contagem, lado a lado com o ticket do dia',
              valor: '$faturadas',
              info: 'Duas leituras no mesmo eixo não caberiam — a contagem '
                  'vive na casa das dezenas e o ticket na dos milhares. Aqui '
                  'está a contagem; o ticket vem no rodapé.',
              vazio: dias.isEmpty,
              rodape: RodapeDeCard(itens: [
                (
                  'Média por dia',
                  diasComOs == 0
                      ? '0'
                      : (faturadas / diasComOs).toStringAsFixed(1),
                ),
                (
                  'Maior ticket do dia',
                  formatMoney(ticketPorDia.fold<double>(0, (a, b) => b > a ? b : a)),
                ),
                ('Dias com ordem', '$diasComOs'),
              ]),
              child: ColunasPorDia(
                dias: dias,
                valores: contagem,
                dinheiro: false,
                cor: neu.info,
              ),
            ),
            CardDeGrafico(
              titulo: 'Onde as ordens estão',
              subtitulo: 'A fila de trabalho, por estado',
              valor: '$naFila',
              info: 'Toda ordem do período, no estado em que está agora. '
                  'Uma pilha em "aguardando peça" explica um mês fraco melhor '
                  'do que qualquer total de receita.',
              vazio: fila.isEmpty,
              mensagemVazio: 'Nenhuma ordem no período.',
              child: RoscaComCentro(
                centroValor: '$naFila',
                centroRotulo: 'ordens',
                fatias: [
                  for (final s in fila)
                    (
                      rotulo: osStatusLabel(s.status),
                      valor: s.total.toDouble(),
                      texto: '${s.total}',
                      cor: osStatusColor(s.status),
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Quanto cada estado representa',
              subtitulo: 'Receita das ordens por estado',
              valor: formatMoney(total),
              info: 'Receita presa num estado que não é "entregue" é trabalho '
                  'feito que ainda não virou dinheiro — ou orçamento que o '
                  'cliente não aprovou.',
              vazio: receitaPorStatus.isEmpty,
              child: RankingDeBarras(
                itens: [
                  for (final e in receitaPorStatus)
                    (
                      rotulo: osStatusLabel(e.key),
                      valor: e.value.revenue,
                      texto: formatMoney(e.value.revenue),
                      cor: osStatusColor(e.key),
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Serviços mais vendidos',
              subtitulo: 'Mão de obra, por receita no período',
              valor: '${servicos.length}',
              info: 'O que a oficina mais faz. Serviço muito repetido é '
                  'candidato a modelo de OS — e a revisão de preço.',
              vazio: servicos.isEmpty,
              mensagemVazio: 'Nenhum serviço no período.',
              child: RankingDeBarras(
                itens: [
                  for (final s in servicos)
                    (
                      rotulo: s.name,
                      valor: s.revenue,
                      texto: formatMoney(s.revenue),
                      cor: cores.principal,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Peças mais vendidas',
              subtitulo: 'Produtos, por receita no período',
              valor: '${pecas.length}',
              info: 'O que mais sai da prateleira. É a lista que deveria '
                  'guiar a compra do mês que vem.',
              vazio: pecas.isEmpty,
              mensagemVazio: 'Nenhuma peça vendida no período.',
              child: RankingDeBarras(
                itens: [
                  for (final p in pecas)
                    (
                      rotulo: p.name,
                      valor: p.revenue,
                      texto: formatMoney(p.revenue),
                      cor: cores.secundaria,
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

/// Estados em que a ordem já saiu da oficina — o resto é fila.
const _encerrados = {'entregue', 'cancelada', 'arquivada'};
