import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../../os/presentation/os_status.dart';
import '../../domain/monthly_models.dart';
import '../../domain/report_models.dart';
import '../report_providers.dart';
import '../report_tabs.dart';
import 'charts/graficos.dart';
import 'motion.dart';
import 'painel.dart';

/// O painel da abertura: UM gráfico de cada assunto, no mesmo lugar.
///
/// As outras sete abas existem para quem vai fundo. Esta é para quem não vai:
/// o dono que abre Relatórios uma vez por mês e quer saber como foi, sem
/// aprender onde cada coisa mora. Por isso aqui há um card por aba — dinheiro
/// que entrou, dinheiro que saiu, oficina, equipe, clientes, prateleira — e
/// cada um leva, com um toque, à página que trata do assunto por inteiro.
///
/// A ordem é a de quem vai decidir alguma coisa: primeiro o que entrou, depois
/// o que saiu, depois o trabalho que gerou isso, e por último quem fez e para
/// quem. Um painel alfabético ou agrupado por tipo de gráfico obrigaria a
/// leitura inteira antes da primeira conclusão.
class PainelDaVisao extends ConsumerWidget {
  const PainelDaVisao({super.key, required this.graficos});

  final GraficosDoMes graficos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cada assunto vem do mesmo provider que alimenta a aba dele: duas somas
    // independentes do mesmo mês divergiriam no primeiro ajuste, e o resumo
    // passaria a discordar da página que ele resume.
    final equipe = ref.watch(teamReportProvider).value?.rows ?? const [];
    final nomes = ref.watch(reportMembersProvider).value ?? const [];
    final clientes = ref.watch(customersReportProvider).value;
    final estoque = ref.watch(painelEstoqueProvider).value;

    return _Painel(
      graficos: graficos,
      equipe: equipe,
      nomes: {for (final m in nomes) m.id: m.name},
      clientes: clientes,
      estoque: estoque,
      irPara: (aba) => ref.read(selectedTabProvider.notifier).select(aba),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({
    required this.graficos,
    required this.equipe,
    required this.nomes,
    required this.clientes,
    required this.estoque,
    required this.irPara,
  });

  final GraficosDoMes graficos;
  final List<TeamReportRow> equipe;
  final Map<String, String> nomes;
  final CustomersReport? clientes;
  final InventoryReport? estoque;
  final void Function(ReportTab) irPara;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cores = coresDeSerie(context);

    final serie = graficos.serieDiaria;
    final movimento = graficos.movimentoPorDia;

    // Os dois gráficos diários precisam do MESMO eixo: faturamento num
    // conjunto de dias e caixa noutro faria duas linhas do tempo diferentes
    // na mesma tela, e o olho compararia posições que não se correspondem.
    final dias = <String>{
      ...serie.map((p) => p.dia),
      ...movimento.map((m) => m.dia),
    }.toList()..sort();

    final faturadoPorDia = {for (final p in serie) p.dia: p.valor.toDouble()};
    final entrouPorDia = {for (final m in movimento) m.dia: m.entrou.toDouble()};
    final saiuPorDia = {for (final m in movimento) m.dia: m.saiu.toDouble()};

    final faturado = [for (final d in dias) faturadoPorDia[d] ?? 0.0];
    final entrou = [for (final d in dias) entrouPorDia[d] ?? 0.0];
    final saiu = [for (final d in dias) saiuPorDia[d] ?? 0.0];

    final totalFaturado = faturado.fold<double>(0, (a, b) => a + b);
    final totalEntrou = entrou.fold<double>(0, (a, b) => a + b);
    final totalSaiu = saiu.fold<double>(0, (a, b) => a + b);

    // Média sobre os dias COM movimento, não sobre o mês inteiro: domingo
    // fechado não é um dia ruim, é um dia que não houve — e diluir o mês por
    // trinta faria toda oficina parecer meia-boca.
    final diasUteis = faturado.where((v) => v > 0).length;
    final media = diasUteis == 0 ? 0.0 : totalFaturado / diasUteis;
    final pico = faturado.fold<double>(0, (a, b) => b > a ? b : a);
    final diaDoPico = pico <= 0
        ? null
        : dias[faturado.indexWhere((v) => v == pico)];

    final despesas = graficos.despesasPorCategoria
        .where((f) => f.total > 0)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final formas = graficos.formasDePagamento.where((f) => f.total > 0).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final fila = graficos.osPorStatus.where((s) => s.total > 0).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final porReceita = [...equipe]
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final receitaEquipe = equipe.fold<num>(0, (a, l) => a + l.revenue);

    final chegadaPorDia = <String, double>{};
    for (final p in clientes?.series ?? const []) {
      chegadaPorDia[p.day] = (chegadaPorDia[p.day] ?? 0) + p.count;
    }
    final diasDeChegada = chegadaPorDia.keys.toList()..sort();

    final faltando = (estoque?.rows ?? const <InventoryReportRow>[])
        .where((l) => l.belowMin)
        .toList()
      ..sort((a, b) => a.currentStock.compareTo(b.currentStock));

    return GradeDeGraficos(
      cards: [
        CardDeGrafico(
          titulo: 'Faturamento dia a dia',
          subtitulo: 'OS faturadas e vendas de balcão, somadas por dia',
          valor: formatMoney(totalFaturado),
          info: 'Soma do total das ordens faturadas e das vendas concluídas '
              'em cada dia do período. O dia de maior movimento vem '
              'destacado.',
          vazio: dias.isEmpty,
          mensagemVazio: 'Nenhum faturamento registrado no período.',
          rodape: RodapeDeCard(
            itens: [
              ('Média por dia trabalhado', formatMoney(media)),
              if (diaDoPico != null)
                ('Melhor dia (${diaCurto(diaDoPico)})', formatMoney(pico)),
              ('Dias com movimento', '$diasUteis'),
            ],
          ),
          atalho: AtalhoDeCard(
            rotulo: 'Abrir Faturamento',
            aoTocar: () => irPara(ReportTab.faturamento),
          ),
          child: ColunasPorDia(dias: dias, valores: faturado),
        ),
        CardDeGrafico(
          titulo: 'Entrou × saiu no caixa',
          subtitulo: 'O dinheiro que de fato passou pelo caixa, dia a dia',
          valor: formatMoney(totalEntrou - totalSaiu),
          info: 'Entradas e saídas registradas no caixa, sem estornos. '
              'Faturar não é receber: a diferença entre esta leitura e a de '
              'cima é o que ficou anotado para receber depois.',
          vazio: movimento.isEmpty,
          mensagemVazio: 'Nenhum movimento de caixa no período.',
          rodape: RodapeDeCard(
            itens: [
              ('Entrou', formatMoney(totalEntrou)),
              ('Saiu', formatMoney(totalSaiu)),
              ('Saldo', formatMoney(totalEntrou - totalSaiu)),
            ],
          ),
          atalho: AtalhoDeCard(
            rotulo: 'Abrir Caixa',
            aoTocar: () => irPara(ReportTab.caixa),
          ),
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
          titulo: 'Acumulado do período',
          subtitulo: 'Quanto já foi faturado e quanto já entrou, somando',
          valor: formatMoney(totalFaturado),
          info: 'A mesma informação do primeiro gráfico, somada dia após dia. '
              'A distância entre as duas curvas é o fiado do período crescendo: '
              'ela só encosta de novo quando o cliente paga.',
          vazio: dias.isEmpty,
          rodape: RodapeDeCard(
            itens: [
              ('Faturado', formatMoney(totalFaturado)),
              ('Recebido', formatMoney(totalEntrou)),
              ('Diferença', formatMoney(totalFaturado - totalEntrou)),
            ],
          ),
          child: LinhasPorDia(
            dias: dias,
            series: [
              SerieNomeada(
                nome: 'Faturado',
                valores: _acumular(faturado),
                cor: cores.principal,
                preenchida: true,
                acumulada: true,
              ),
              SerieNomeada(
                nome: 'Recebido',
                valores: _acumular(entrou),
                cor: cores.secundaria,
                acumulada: true,
              ),
            ],
          ),
        ),
        CardDeGrafico(
          titulo: 'Para onde foi o dinheiro',
          subtitulo: 'Despesas do período por categoria',
          valor: formatMoney(despesas.fold<num>(0, (a, f) => a + f.total)),
          info: 'Despesas previstas para o mês, agrupadas pela categoria em '
              'que foram lançadas. Saber que subiu é informação; saber que '
              'subiu em peças é o que dá para resolver.',
          vazio: despesas.isEmpty,
          mensagemVazio: 'Nenhuma despesa registrada no período.',
          atalho: AtalhoDeCard(
            rotulo: 'Abrir Despesas',
            aoTocar: () => irPara(ReportTab.despesas),
          ),
          child: RoscaComCentro(
            centroValor:
                compactoEmReais(despesas.fold<num>(0, (a, f) => a + f.total)),
            centroRotulo: 'em despesas',
            fatias: _fatias(
              context,
              [for (final d in despesas) (rotulo: d.categoria, valor: d.total)],
            ),
          ),
        ),
        CardDeGrafico(
          titulo: 'Como o cliente pagou',
          subtitulo: 'Entradas do caixa por forma de pagamento',
          valor: formatMoney(formas.fold<num>(0, (a, f) => a + f.total)),
          info: 'Só entradas: uma despesa paga em dinheiro não responde como '
              'o cliente paga. Serve para negociar taxa de cartão e para ver '
              'se o pix já virou a regra da casa.',
          vazio: formas.isEmpty,
          mensagemVazio: 'Nenhum recebimento no período.',
          child: RoscaComCentro(
            centroValor:
                compactoEmReais(formas.fold<num>(0, (a, f) => a + f.total)),
            centroRotulo: 'recebidos',
            fatias: _fatias(
              context,
              [
                for (final f in formas)
                  (rotulo: methodLabel(f.forma), valor: f.total),
              ],
            ),
          ),
        ),
        CardDeGrafico(
          titulo: 'Onde as ordens pararam',
          subtitulo: 'A fila de trabalho no fim do período',
          valor: '${fila.fold<int>(0, (a, s) => a + s.total)}',
          info: 'Quantas ordens do período estão em cada estado. É a fila, não o '
              'faturamento: uma pilha em "aguardando peça" explica um mês '
              'fraco melhor do que qualquer total.',
          vazio: fila.isEmpty,
          mensagemVazio: 'Nenhuma ordem no período.',
          atalho: AtalhoDeCard(
            rotulo: 'Abrir Ordens',
            aoTocar: () => irPara(ReportTab.ordens),
          ),
          child: _FilaDeOrdens(fatias: fila),
        ),
        CardDeGrafico(
          titulo: 'Quem fez o trabalho',
          subtitulo: 'Receita das ordens atribuídas a cada pessoa',
          valor: formatMoney(receitaEquipe),
          info: 'Receita das ordens com responsável definido. Ordens sem '
              'responsável aparecem agrupadas — e muitas delas significam que '
              'a atribuição não está sendo usada.',
          vazio: porReceita.isEmpty,
          mensagemVazio: 'Nenhuma ordem atribuída no período.',
          atalho: AtalhoDeCard(
            rotulo: 'Abrir Equipe',
            aoTocar: () => irPara(ReportTab.equipe),
          ),
          child: RankingDeBarras(
            limite: 5,
            itens: [
              for (final l in porReceita)
                (
                  rotulo: l.assignedTo == null
                      ? 'Sem responsável'
                      : (nomes[l.assignedTo] ?? 'Sem responsável'),
                  valor: l.revenue,
                  texto: formatMoney(l.revenue),
                  cor: cores.principal,
                ),
            ],
          ),
        ),
        CardDeGrafico(
          titulo: 'Clientes que chegaram',
          subtitulo: 'Cadastros novos, dia a dia',
          valor: '${clientes?.newInRange ?? 0}',
          info: 'Cada barra é o número de clientes cadastrados naquele dia. '
              'Chegada concentrada num dia costuma ser importação ou '
              'campanha; espalhada é boca a boca.',
          vazio: diasDeChegada.isEmpty,
          mensagemVazio: 'Nenhum cliente novo no período.',
          rodape: RodapeDeCard(
            itens: [
              ('Novos', '${clientes?.newInRange ?? 0}'),
              ('Base ativa', '${clientes?.active ?? 0}'),
              ('Dias com chegada', '${chegadaPorDia.values.where((v) => v > 0).length}'),
            ],
          ),
          atalho: AtalhoDeCard(
            rotulo: 'Abrir Clientes',
            aoTocar: () => irPara(ReportTab.clientes),
          ),
          child: ColunasPorDia(
            dias: diasDeChegada,
            valores: [for (final d in diasDeChegada) chegadaPorDia[d] ?? 0],
            dinheiro: false,
            cor: neu.info,
          ),
        ),
        CardDeGrafico(
          titulo: 'O que vai faltar',
          subtitulo: 'Itens abaixo do mínimo, do mais crítico',
          valor: '${faltando.length}',
          info: 'Peça que falta na hora do serviço vira ordem parada '
              'esperando compra. A barra mostra quanto resta em relação ao '
              'mínimo configurado.',
          vazio: faltando.isEmpty,
          mensagemVazio: 'Nenhum item abaixo do mínimo.',
          rodape: RodapeDeCard(
            itens: [
              ('Valor em estoque', formatMoney(estoque?.stockValue ?? 0)),
              ('Itens cadastrados', '${estoque?.total ?? 0}'),
              ('Abaixo do mínimo', '${faltando.length}'),
            ],
          ),
          atalho: AtalhoDeCard(
            rotulo: 'Abrir Estoque',
            aoTocar: () => irPara(ReportTab.estoque),
          ),
          child: RankingDeBarras(
            limite: 5,
            // Zero aqui é a notícia: item zerado tem barra vazia E é o mais
            // urgente da lista. E a escala é o PRÓPRIO mínimo, não o maior da
            // lista: cinco itens igualmente faltando não podem virar cinco
            // barras cheias.
            ocultarZeros: false,
            maximoFixo: 1,
            itens: [
              for (final l in faltando)
                (
                  rotulo: l.name,
                  valor: (l.minStock ?? 0) <= 0
                      ? 0
                      : l.currentStock / l.minStock!,
                  texto: '${_qtd(l.currentStock)} de ${_qtd(l.minStock ?? 0)}',
                  cor: l.currentStock <= 0 ? neu.danger : neu.warning,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Soma corrente: [10, 5, 7] → [10, 15, 22].
List<double> _acumular(List<double> valores) {
  var soma = 0.0;
  return [
    for (final v in valores) soma += v,
  ];
}

/// "3" em vez de "3.0" — quantidade fracionária só aparece quando existe.
String _qtd(num v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

/// Pinta as fatias com a paleta de glyphs — a mesma que já identifica
/// categorias nas outras telas, para uma cor não significar duas coisas.
///
/// Acima de seis fatias o resto vira "Outras": um donut com quinze categorias
/// não é um gráfico, é uma lista colorida ilegível.
List<({String rotulo, double valor, String texto, Color cor})> _fatias(
  BuildContext context,
  List<({String rotulo, num valor})> itens,
) {
  final cores = context.neu.glyphs;
  final principais = itens.take(6).toList();
  final resto = itens.skip(6).fold<num>(0, (a, i) => a + i.valor);
  final todas = [
    ...principais,
    if (resto > 0) (rotulo: 'Outras', valor: resto),
  ];
  return [
    for (var i = 0; i < todas.length; i++)
      (
        rotulo: todas[i].rotulo,
        valor: todas[i].valor.toDouble(),
        texto: formatMoney(todas[i].valor),
        cor: cores[i % cores.length],
      ),
  ];
}

/// A fila de ordens: barras deitadas, na cor que cada estado já tem no resto
/// do sistema.
///
/// Deitadas porque o rótulo é um nome ("Aguardando peça"); na vertical ele
/// vira reticências e o gráfico passa a precisar de legenda para dizer o que
/// já estava escrito.
class _FilaDeOrdens extends StatelessWidget {
  const _FilaDeOrdens({required this.fatias});

  final List<FatiaStatus> fatias;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final mostrar = fatias.take(7).toList();
    final maior = mostrar.first.total;
    final total = fatias.fold<int>(0, (a, s) => a + s.total);
    final semMovimento = MediaQuery.disableAnimationsOf(context);

    // A altura da linha vem do espaço disponível, com teto: duas barras
    // distribuídas pela altura inteira do card ficariam boiando longe uma da
    // outra, e a comparação — que é o ponto — some na distância. Sete barras
    // num card de 240px, pelo caminho contrário, estourariam.
    return LayoutBuilder(
      builder: (context, c) {
        final alturaLinha = (c.maxHeight / mostrar.length).clamp(20.0, 38.0);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final s in mostrar)
              SizedBox(
                height: alturaLinha,
                child: Row(
                  children: [
                    SizedBox(
                      width: 132,
                      child: Text(
                        osStatusLabel(s.status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neu.inkMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          height: 10,
                          color: neu.line,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: semMovimento
                                ? FractionallySizedBox(
                                    widthFactor: s.total / maior,
                                    child: Container(
                                      color: osStatusColor(s.status),
                                    ),
                                  )
                                : TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 0,
                                      end: s.total / maior,
                                    ),
                                    duration: kAberturaLonga,
                                    curve: Curves.easeOutCubic,
                                    builder: (context, t, _) =>
                                        FractionallySizedBox(
                                      widthFactor: t.clamp(0.0, 1.0),
                                      child: Container(
                                        color: osStatusColor(s.status),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 62,
                      child: Text(
                        '${s.total}  ${_pct(s.total, total)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: kTabular,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

String _pct(int parte, int total) =>
    total == 0 ? '' : '${(parte * 100 / total).round()}%';
