import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../domain/report_models.dart';
import '../report_providers.dart';
import '../widgets/charts/graficos.dart';
import '../widgets/painel.dart';

/// O painel de Equipe.
///
/// Rendimento de pessoa é um assunto delicado, e o painel trata assim: mostra
/// volume, receita e tempo lado a lado, porque isolados eles mentem. Quem fez
/// menos ordens pode ter feito as mais caras; quem fechou mais rápido pode ter
/// pegado as mais simples.
class PainelDeEquipe extends ConsumerWidget {
  const PainelDeEquipe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teamReportProvider);
    final nomes = ref.watch(reportMembersProvider).value ?? const [];
    final responsavel = ref.watch(reportFiltersProvider).assignedTo;
    return async.when(
      loading: () => const PainelCarregando(),
      error: (_, _) => PainelComErro(
        onRetry: () => ref.invalidate(teamReportProvider),
      ),
      data: (r) => _Painel(
        // O recorte acontece ANTES dos cards: assim os seis contam a mesma
        // pessoa, e a "participação na receita" mostra 100% porque é isso que
        // uma pessoa sozinha representa do recorte — não um erro de conta.
        linhas: responsavel == null
            ? r.rows
            : r.rows.where((l) => l.assignedTo == responsavel).toList(),
        nomes: {for (final m in nomes) m.id: m.name},
      ),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({required this.linhas, required this.nomes});

  final List<TeamReportRow> linhas;
  final Map<String, String> nomes;

  String _nome(String? id) =>
      id == null ? 'Sem responsável' : (nomes[id] ?? 'Sem responsável');

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cores = coresDeSerie(context);

    final porReceita = [...linhas]
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final ordens = linhas.fold<int>(0, (a, l) => a + l.orders);
    final concluidas = linhas.fold<int>(0, (a, l) => a + l.completed);
    final receita = linhas.fold<num>(0, (a, l) => a + l.revenue);

    final comCiclo = linhas.where((l) => (l.avgCycleMs ?? 0) > 0).toList()
      ..sort((a, b) => (a.avgCycleMs ?? 0).compareTo(b.avgCycleMs ?? 0));
    final cicloMedio = comCiclo.isEmpty
        ? 0.0
        : comCiclo.fold<double>(0, (a, l) => a + (l.avgCycleMs ?? 0)) /
            comCiclo.length;

    final topo = porReceita.isEmpty ? null : porReceita.first;
    final concentracao =
        receita <= 0 || topo == null ? 0.0 : topo.revenue / receita;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FaixaDeIndicadores(
          itens: [
            IndicadorPainel(
              rotulo: 'Receita da equipe',
              valor: formatMoney(receita),
              icone: Icons.groups_outlined,
              detalhe: '${linhas.length} pessoas com ordem',
            ),
            IndicadorPainel(
              rotulo: 'Ordens atribuídas',
              valor: '$ordens',
              icone: Icons.assignment_ind_outlined,
              detalhe: '$concluidas concluídas',
            ),
            IndicadorPainel(
              rotulo: 'Taxa de conclusão',
              valor: ordens == 0
                  ? '—'
                  : '${(concluidas * 100 / ordens).round()}%',
              icone: Icons.task_alt_rounded,
              cor: ordens > 0 && concluidas / ordens >= 0.8 ? neu.success : null,
            ),
            IndicadorPainel(
              rotulo: 'Tempo médio de ordem',
              valor: _duracao(cicloMedio),
              icone: Icons.timer_outlined,
              detalhe: 'da abertura à entrega',
            ),
            IndicadorPainel(
              rotulo: 'Maior receita',
              valor: topo == null ? '—' : formatMoney(topo.revenue),
              icone: Icons.emoji_events_outlined,
              detalhe: topo == null ? null : _nome(topo.assignedTo),
            ),
            IndicadorPainel(
              rotulo: 'Concentração',
              valor: '${(concentracao * 100).round()}%',
              icone: Icons.pie_chart_outline_rounded,
              detalhe: 'numa pessoa só',
              // Quando uma pessoa responde por mais de 60% da receita, as
              // férias dela são um risco operacional — não um detalhe de RH.
              cor: concentracao >= 0.6 ? neu.warning : null,
            ),
            IndicadorPainel(
              rotulo: 'Mais rápido',
              valor: comCiclo.isEmpty
                  ? '—'
                  : _duracao((comCiclo.first.avgCycleMs ?? 0).toDouble()),
              icone: Icons.speed_rounded,
              detalhe:
                  comCiclo.isEmpty ? null : _nome(comCiclo.first.assignedTo),
            ),
            IndicadorPainel(
              rotulo: 'Ticket médio da equipe',
              valor: formatMoney(concluidas == 0 ? 0 : receita / concluidas),
              icone: Icons.receipt_long_outlined,
              detalhe: 'por ordem concluída',
            ),
          ],
        ),
        const SizedBox(height: 14),
        GradeDeGraficos(
          cards: [
            CardDeGrafico(
              titulo: 'Quem fez mais receita',
              subtitulo: 'Receita das ordens atribuídas a cada pessoa',
              valor: formatMoney(receita),
              info: 'Receita das ordens com responsável definido. Ordens sem '
                  'responsável aparecem agrupadas — e muitas delas significam '
                  'que a atribuição não está sendo usada.',
              vazio: porReceita.isEmpty,
              mensagemVazio: 'Nenhuma ordem atribuída no período.',
              child: RankingDeBarras(
                itens: [
                  for (final l in porReceita)
                    (
                      rotulo: _nome(l.assignedTo),
                      valor: l.revenue,
                      texto: formatMoney(l.revenue),
                      cor: cores.principal,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Atribuídas × concluídas',
              subtitulo: 'O que entrou para cada um e o que saiu pronto',
              valor: '$concluidas de $ordens',
              info: 'A diferença entre as duas barras é trabalho em aberto. '
                  'Uma pessoa com muita diferença pode estar com ordens '
                  'paradas esperando peça — ou sobrecarregada.',
              vazio: linhas.isEmpty,
              child: BarrasComparadas(
                categorias: [
                  for (final l in porReceita.take(5)) _nome(l.assignedTo),
                ],
                primeira: [
                  for (final l in porReceita.take(5)) l.orders.toDouble(),
                ],
                segunda: [
                  for (final l in porReceita.take(5)) l.completed.toDouble(),
                ],
                rotuloPrimeira: 'Atribuídas',
                rotuloSegunda: 'Concluídas',
              ),
            ),
            CardDeGrafico(
              titulo: 'Ticket médio de cada um',
              subtitulo: 'Receita dividida pelas ordens concluídas',
              valor: formatMoney(concluidas == 0 ? 0 : receita / concluidas),
              info: 'Ticket alto não é mérito automático: pode ser quem pega '
                  'os serviços grandes. Serve para equilibrar a distribuição, '
                  'não para premiar.',
              vazio: linhas.isEmpty,
              child: RankingDeBarras(
                itens: [
                  for (final l in ([...linhas]
                    ..sort((a, b) => b.avgTicket.compareTo(a.avgTicket))))
                    (
                      rotulo: _nome(l.assignedTo),
                      valor: l.avgTicket,
                      texto: formatMoney(l.avgTicket),
                      cor: cores.secundaria,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Participação na receita',
              subtitulo: 'Quanto do período passou pelas mãos de cada um',
              valor: formatMoney(receita),
              info: 'Quando uma fatia domina o círculo, as férias daquela '
                  'pessoa são um risco de faturamento — e vale distribuir as '
                  'próximas ordens com isso em mente.',
              vazio: porReceita.isEmpty,
              child: RoscaComCentro(
                centroValor: compactoEmReais(receita),
                centroRotulo: 'da equipe',
                fatias: [
                  for (var i = 0; i < porReceita.length; i++)
                    (
                      rotulo: _nome(porReceita[i].assignedTo),
                      valor: porReceita[i].revenue.toDouble(),
                      texto: formatMoney(porReceita[i].revenue),
                      cor: neu.glyphs[i % neu.glyphs.length],
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Tempo médio por ordem',
              subtitulo: 'Da abertura à entrega, por pessoa',
              valor: _duracao(cicloMedio),
              info: 'Média do tempo entre abrir e entregar. Barra curta é '
                  'bom sinal, mas leia junto com o ticket: serviço simples '
                  'fecha rápido por natureza.',
              vazio: comCiclo.isEmpty,
              mensagemVazio: 'Nenhuma ordem concluída no período.',
              child: RankingDeBarras(
                itens: [
                  for (final l in comCiclo)
                    (
                      rotulo: _nome(l.assignedTo),
                      valor: (l.avgCycleMs ?? 0),
                      texto: _duracao((l.avgCycleMs ?? 0).toDouble()),
                      cor: neu.info,
                    ),
                ],
              ),
            ),
            CardDeGrafico(
              titulo: 'Volume de trabalho',
              subtitulo: 'Ordens atribuídas a cada pessoa',
              valor: '$ordens',
              info: 'A contagem pura, sem dinheiro no meio. É a leitura que '
                  'responde "está equilibrado?" antes de qualquer conversa '
                  'sobre desempenho.',
              vazio: linhas.isEmpty,
              child: RankingDeBarras(
                itens: [
                  for (final l in ([...linhas]
                    ..sort((a, b) => b.orders.compareTo(a.orders))))
                    (
                      rotulo: _nome(l.assignedTo),
                      valor: l.orders,
                      texto: '${l.orders}',
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

/// "2 d 4 h", "5 h 20 min", "40 min" — a duração como alguém diria em voz alta.
String _duracao(double ms) {
  if (ms <= 0) return '—';
  final minutos = ms / 60000;
  if (minutos < 60) return '${minutos.round()} min';
  final horas = minutos / 60;
  if (horas < 24) {
    final h = horas.floor();
    final m = (minutos - h * 60).round();
    return m == 0 ? '$h h' : '$h h $m min';
  }
  final dias = horas / 24;
  final d = dias.floor();
  final h = (horas - d * 24).round();
  return h == 0 ? '$d d' : '$d d $h h';
}
