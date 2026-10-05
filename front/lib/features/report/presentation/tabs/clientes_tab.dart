import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../domain/report_models.dart';
import '../customers_ranking_card.dart';
import '../report_providers.dart';
import '../widgets/charts/graficos.dart';
import '../widgets/painel.dart';

/// O painel de Clientes.
///
/// Duas perguntas que parecem a mesma: quem chegou (o crescimento) e quem
/// volta (a base). Oficina que só responde a primeira vive de propaganda; a
/// segunda é a que paga as contas no mês em que ninguém novo aparece.
class PainelDeClientes extends ConsumerWidget {
  const PainelDeClientes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumo = ref.watch(customersReportProvider);
    final range = ref.watch(reportRangeProvider);
    final ranking = ref.watch(customersRankingProvider(range));

    return resumo.when(
      loading: () => const PainelCarregando(),
      error: (_, _) => PainelComErro(
        onRetry: () => ref.invalidate(customersReportProvider),
      ),
      data: (r) => _Painel(
        relatorio: r,
        ranking: ranking.value ?? const CustomersRanking(),
      ),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({required this.relatorio, required this.ranking});

  final CustomersReport relatorio;
  final CustomersRanking ranking;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cores = coresDeSerie(context);

    // A série vem quebrada por dia E por tipo; o gráfico de chegada soma os
    // tipos, e o de composição soma os dias.
    final porDia = <String, double>{};
    final porTipo = <String, int>{};
    for (final p in relatorio.series) {
      porDia[p.day] = (porDia[p.day] ?? 0) + p.count;
      porTipo[p.type] = (porTipo[p.type] ?? 0) + p.count;
    }
    final dias = porDia.keys.toList()..sort();
    final chegadas = [for (final d in dias) porDia[d] ?? 0];
    final diasComChegada = chegadas.where((v) => v > 0).length;
    final melhorDia = chegadas.fold<double>(0, (a, b) => b > a ? b : a);

    final porReceita = ranking.porReceita;
    final porRecorrencia = ranking.porRecorrencia;
    final receita = porReceita.fold<num>(0, (a, c) => a + c.recebido);
    final topo = porReceita.isEmpty ? null : porReceita.first;
    final concentracao =
        receita <= 0 || topo == null ? 0.0 : topo.recebido / receita;
    final desconto = porReceita.fold<num>(0, (a, c) => a + c.desconto);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FaixaDeIndicadores(
          itens: [
            IndicadorPainel(
              rotulo: 'Clientes ativos',
              valor: '${relatorio.active}',
              icone: Icons.people_outline_rounded,
              detalhe: 'na base inteira',
            ),
            IndicadorPainel(
              rotulo: 'Novos no período',
              valor: '${relatorio.newInRange}',
              icone: Icons.person_add_alt_rounded,
              detalhe: relatorio.active == 0
                  ? null
                  : '${(relatorio.newInRange * 100 / relatorio.active).round()}% da base',
              cor: relatorio.newInRange > 0 ? neu.success : null,
            ),
            IndicadorPainel(
              rotulo: 'Dias com cliente novo',
              valor: '$diasComChegada',
              icone: Icons.calendar_today_outlined,
            ),
            IndicadorPainel(
              rotulo: 'Melhor dia',
              valor: '${melhorDia.round()}',
              icone: Icons.trending_up_rounded,
              detalhe: 'clientes num só dia',
            ),
            IndicadorPainel(
              rotulo: 'Receita dos clientes',
              valor: formatMoney(receita),
              icone: Icons.payments_outlined,
              detalhe: '${porReceita.length} pagaram no período',
            ),
            IndicadorPainel(
              rotulo: 'Maior cliente',
              valor: topo == null ? '—' : formatMoney(topo.recebido),
              icone: Icons.emoji_events_outlined,
              detalhe: topo?.customerName,
            ),
            IndicadorPainel(
              rotulo: 'Concentração',
              valor: '${(concentracao * 100).round()}%',
              icone: Icons.pie_chart_outline_rounded,
              detalhe: 'num cliente só',
              // Um cliente que sozinho sustenta o mês é um risco, não uma
              // conquista: se ele some, some o mês junto.
              cor: concentracao >= 0.4 ? neu.warning : null,
            ),
            IndicadorPainel(
              rotulo: 'Desconto concedido',
              valor: formatMoney(desconto),
              icone: Icons.percent_rounded,
              detalhe: 'perdoar dívida não é receita',
              cor: desconto > 0 ? neu.warning : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        GradeDeGraficos(
          cards: [
            CardDeGrafico(
              titulo: 'Quando os clientes chegaram',
              subtitulo: 'Cadastros novos, dia a dia',
              valor: '${relatorio.newInRange}',
              info: 'Cada barra é o número de clientes cadastrados naquele '
                  'dia. Chegada concentrada num dia costuma ser importação ou '
                  'campanha; espalhada é boca a boca.',
              vazio: dias.isEmpty,
              mensagemVazio: 'Nenhum cliente novo no período.',
              rodape: RodapeDeCard(itens: [
                ('Novos', '${relatorio.newInRange}'),
                ('Dias com chegada', '$diasComChegada'),
                ('Melhor dia', '${melhorDia.round()}'),
              ]),
              child: ColunasPorDia(
                dias: dias,
                valores: chegadas,
                dinheiro: false,
              ),
            ),
            CardDeGrafico(
              titulo: 'Pessoa física ou empresa',
              subtitulo: 'Composição dos clientes novos',
              valor: '${relatorio.newInRange}',
              info: 'Empresa costuma trazer frota, prazo de pagamento e nota '
                  'fiscal; pessoa física, volume e pagamento à vista. A '
                  'mistura muda como a oficina precisa se organizar.',
              vazio: porTipo.isEmpty,
              child: RoscaComCentro(
                centroValor: '${relatorio.newInRange}',
                centroRotulo: 'clientes novos',
                fatias: [
                  for (var i = 0; i < porTipo.length; i++)
                    (
                      rotulo: _tipoLegivel(porTipo.keys.elementAt(i)),
                      valor: porTipo.values.elementAt(i).toDouble(),
                      texto: '${porTipo.values.elementAt(i)}',
                      cor: neu.glyphs[i % neu.glyphs.length],
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Quem mais gastou',
              subtitulo: 'Clientes por dinheiro recebido no período',
              valor: formatMoney(receita),
              info: 'Só o que ENTROU. Desconto fica de fora: perdoar dívida '
                  'fecha a conta, mas não põe dinheiro no caixa.',
              vazio: porReceita.isEmpty,
              mensagemVazio: 'Nenhum recebimento de cliente no período.',
              child: RankingDeBarras(
                itens: [
                  for (final c in porReceita)
                    (
                      rotulo: c.customerName,
                      valor: c.recebido,
                      texto: formatMoney(c.recebido),
                      cor: cores.principal,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Quem mais voltou',
              subtitulo: 'Clientes por número de atendimentos',
              valor: '${porRecorrencia.length}',
              info: 'Quem traz mais dinheiro nem sempre é quem volta mais. '
                  'Esta lista é a base fiel — a que sustenta o mês em que '
                  'nenhum cliente novo aparece.',
              vazio: porRecorrencia.isEmpty,
              child: RankingDeBarras(
                itens: [
                  for (final c in porRecorrencia)
                    (
                      rotulo: c.customerName,
                      valor: c.atendimentos,
                      texto: '${c.atendimentos}×',
                      cor: cores.secundaria,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Participação na receita',
              subtitulo: 'Quanto do período veio de cada cliente',
              valor: formatMoney(receita),
              info: 'Uma fatia dominando o círculo é um risco: a oficina '
                  'depende de um telefone que pode parar de tocar.',
              vazio: porReceita.isEmpty,
              child: RoscaComCentro(
                centroValor: compactoEmReais(receita),
                centroRotulo: 'recebidos',
                fatias: [
                  for (var i = 0; i < porReceita.length; i++)
                    (
                      rotulo: porReceita[i].customerName,
                      valor: porReceita[i].recebido.toDouble(),
                      texto: formatMoney(porReceita[i].recebido),
                      cor: neu.glyphs[i % neu.glyphs.length],
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Ticket médio por cliente',
              subtitulo: 'Quanto cada um deixa por visita',
              valor: formatMoney(
                porReceita.isEmpty
                    ? 0
                    : porReceita.fold<num>(0, (a, c) => a + c.ticketMedio) /
                        porReceita.length,
              ),
              info: 'Receita dividida pelos atendimentos de cada cliente. '
                  'Ticket alto com poucos retornos pede fidelização; ticket '
                  'baixo com muitos retornos pede revisão de preço.',
              vazio: porReceita.isEmpty,
              child: RankingDeBarras(
                itens: [
                  for (final c in ([...porReceita]
                    ..sort((a, b) => b.ticketMedio.compareTo(a.ticketMedio))))
                    (
                      rotulo: c.customerName,
                      valor: c.ticketMedio,
                      texto: formatMoney(c.ticketMedio),
                      cor: neu.info,
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

/// "pf"/"pj" como o dono fala.
String _tipoLegivel(String tipo) => switch (tipo.toLowerCase()) {
      'pf' => 'Pessoa física',
      'pj' => 'Empresa',
      '' => 'Sem tipo',
      _ => tipo,
    };
