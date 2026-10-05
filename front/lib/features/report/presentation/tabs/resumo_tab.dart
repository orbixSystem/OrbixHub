import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../domain/monthly_models.dart';
import '../report_providers.dart';
import '../report_tabs.dart';
import '../widgets/charts/graficos.dart';
import '../widgets/documento_do_mes.dart';
import '../widgets/motion.dart';
import '../widgets/sinais_do_mes.dart';

/// O relatório do mês, escrito.
///
/// É a primeira página de Relatórios porque é a única que responde "como foi o
/// mês" para quem não vai ler gráfico nenhum. As outras abas são o mesmo mês
/// em desenho e em tabela; esta é o mês em palavras, com os números ao lado
/// das frases que os comentam.
///
/// A ordem é a de um relatório de verdade, e não a de um dashboard: a frase
/// que abre, os números que a sustentam, o que foi bem, o que preocupa, as
/// evidências, o que fazer, e o fechamento. Um dono que leia só até a metade
/// já saiu com a conclusão.
class ResumoTab extends ConsumerWidget {
  const ResumoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginaAsync = ref.watch(resumoMensalProvider);
    final visaoAsync = ref.watch(visaoMensalProvider);

    return paginaAsync.when(
      loading: () => const _Escrevendo(),
      error: (e, _) => _Erro(
        mensagem: e is AppException ? e.message : 'Não foi possível carregar.',
        onRetry: () => ref.invalidate(resumoMensalProvider),
      ),
      data: (pagina) {
        final resumo = pagina.resumo;
        if (resumo == null) {
          return _SemResumo(
            rotuloDoMes: visaoAsync.value?.periodo.rotulo ?? '',
            mesCorrente: ref.watch(mesSelecionadoProvider) == null,
            serie: visaoAsync.value?.graficos.serieDiaria ?? const [],
            aoVerPainel: () =>
                ref.read(selectedTabProvider.notifier).select(ReportTab.visao),
          );
        }
        return _Relatorio(
          resumo: resumo,
          serie: visaoAsync.value?.graficos.serieDiaria ?? const [],
          aoVerPainel: () =>
              ref.read(selectedTabProvider.notifier).select(ReportTab.visao),
        );
      },
    );
  }
}

class _Relatorio extends StatelessWidget {
  const _Relatorio({
    required this.resumo,
    required this.serie,
    required this.aoVerPainel,
  });

  final ResumoMensal resumo;
  final List<PontoDiario> serie;
  final VoidCallback aoVerPainel;

  @override
  Widget build(BuildContext context) {
    final n = resumo.narrativa;
    // Os destaques apontam para KPIs desta mesma página: a cifra vem daqui,
    // nunca do texto. Um destaque órfão (rótulo que não existe mais) some em
    // vez de virar uma linha com o valor em branco.
    final porRotulo = {for (final k in resumo.kpis) k.rotulo: k};
    final destaques = [
      for (final d in n.destaques)
        if (porRotulo.containsKey(d.kpi))
          (kpi: porRotulo[d.kpi]!, comentario: d.comentario),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FaixaDeGeracao(resumo: resumo),
        const SizedBox(height: 12),
        DocumentoDoMes(resumo: resumo),
        if (resumo.kpis.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Secao(
            titulo: 'Os números do mês',
            legenda: 'Cada um comparado com o mês anterior.',
            child: _NumerosDoMes(kpis: resumo.kpis),
          ),
        ],
        if (destaques.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Secao(
            titulo: 'O que esses números dizem',
            legenda: 'Os que mudaram, e o que a mudança significa.',
            child: _Destaques(itens: destaques),
          ),
        ],
        if (n.oQueFoiBem.isNotEmpty || n.oQuePreocupa.isNotEmpty) ...[
          const SizedBox(height: 16),
          _BalancoDoMes(foiBem: n.oQueFoiBem, preocupa: n.oQuePreocupa),
        ],
        if (serie.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Secao(
            titulo: 'O mês, dia a dia',
            legenda:
                'O faturamento que sustenta tudo o que está escrito acima.',
            aoAbrir: aoVerPainel,
            rotuloAbrir: 'Ver o painel completo',
            child: SizedBox(
              height: 200,
              child: ColunasPorDia(
                dias: [for (final p in serie) p.dia],
                valores: [for (final p in serie) p.valor.toDouble()],
              ),
            ),
          ),
        ],
        if (resumo.sinais.isNotEmpty) ...[
          const SizedBox(height: 16),
          SinaisDoMes(sinais: resumo.sinais),
        ],
        if (n.recomendacoes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Secao(
            titulo: 'Para este mês',
            legenda: 'Cada uma cabe numa tarde.',
            child: ParaEsteMes(itens: n.recomendacoes),
          ),
        ],
        if (n.fechamento.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Fechamento(texto: n.fechamento),
        ],
      ],
    );
  }
}

/// A faixa de quando o relatório foi escrito.
///
/// Fica no TOPO, antes do texto, porque é a pergunta que vem antes de
/// qualquer leitura: isto ainda vale? A data absoluta diz quando; o "há 3
/// dias" diz se está velho — e é o segundo que o olho usa.
class _FaixaDeGeracao extends StatelessWidget {
  const _FaixaDeGeracao({required this.resumo});

  final ResumoMensal resumo;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ia = resumo.escritoPorIa;
    final decorrido = AssinaturaDoResumo.tempoDecorrido(resumo.generatedAt);
    final absoluto = _dataPorExtenso(resumo.generatedAt);

    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: (ia ? neu.accent : neu.navy).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(NeuTokens.rChip),
                ),
                child: Icon(
                  ia ? Icons.auto_awesome_rounded : Icons.calculate_outlined,
                  size: 14,
                  color: ia ? neu.accent : neu.navy,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                ia ? 'Escrito por IA' : 'Escrito pelo sistema',
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: neu.inkFaint),
              const SizedBox(width: 6),
              // `Flexible` porque esta faixa vive num `Wrap`: no celular ela
              // recebe a largura da tela inteira e o texto completo não cabe.
              // Sem isso, a primeira coisa que o dono vê ao abrir o relatório
              // no pátio é uma tarja listrada de overflow.
              Flexible(
                child: Text(
                  decorrido.isEmpty
                      ? 'Gerado $absoluto'
                      : 'Gerado $decorrido'
                            '${absoluto.isEmpty ? '' : ' · $absoluto'}',
                  maxLines: 2,
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_rounded, size: 14, color: neu.inkFaint),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Mês analisado: ${resumo.periodo.rotulo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// "em 4 de outubro às 20h33".
String _dataPorExtenso(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final dia = d.day == 1 ? '1º' : '${d.day}';
  final hora =
      '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  return 'em $dia de ${_meses[d.month - 1]} às $hora';
}

/// Uma seção do relatório: título, legenda e o conteúdo.
class _Secao extends StatelessWidget {
  const _Secao({
    required this.titulo,
    required this.child,
    this.legenda,
    this.aoAbrir,
    this.rotuloAbrir,
  });

  final String titulo;
  final String? legenda;
  final Widget child;
  final VoidCallback? aoAbrir;
  final String? rotuloAbrir;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: EdgeInsets.fromLTRB(
        context.isMobile ? 18 : 24,
        20,
        context.isMobile ? 18 : 24,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (legenda != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        legenda!,
                        style: TextStyle(color: neu.inkFaint, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              if (aoAbrir != null)
                TextButton.icon(
                  onPressed: aoAbrir,
                  icon: Text(
                    rotuloAbrir ?? 'Ver mais',
                    style: TextStyle(
                      color: neu.navy,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  label: Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: neu.navy,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Os KPIs do mês em grade, com a variação colorida pelo que ela significa.
///
/// Verde não é "subiu": despesa subindo e fiado subindo são ruins. Pintar toda
/// alta de verde é comemorar justamente o que o dono precisa cortar.
class _NumerosDoMes extends StatelessWidget {
  const _NumerosDoMes({required this.kpis});

  final List<KpiMensal> kpis;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return LayoutBuilder(
      builder: (context, c) {
        final colunas = c.maxWidth < 560 ? 2 : (c.maxWidth < 920 ? 3 : 4);
        const gap = 12.0;
        final largura = (c.maxWidth - gap * (colunas - 1)) / colunas;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final k in kpis)
              SizedBox(
                width: largura,
                child: _Numero(kpi: k, neu: neu),
              ),
          ],
        );
      },
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.kpi, required this.neu});

  final KpiMensal kpi;
  final NeuTokens neu;

  @override
  Widget build(BuildContext context) {
    final boa = kpi.variacaoEhBoa;
    final cor = boa == null ? neu.inkFaint : (boa ? neu.success : neu.danger);
    final pct = kpi.variacao?.pct ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: neu.surfaceHi,
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        border: Border.all(color: neu.line, width: 1),
      ),
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
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.ehDinheiro
                  ? formatMoney(kpi.valor)
                  : kpi.valor.toStringAsFixed(0),
              style: TextStyle(
                color: neu.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.1,
                fontFeatures: kTabular,
              ),
            ),
          ),
          const SizedBox(height: 5),
          if (kpi.variacao == null)
            Text(
              'sem comparação',
              style: TextStyle(color: neu.inkFaint, fontSize: 12),
            )
          else
            Row(
              children: [
                Icon(
                  pct >= 0
                      ? Icons.north_east_rounded
                      : Icons.south_east_rounded,
                  size: 13,
                  color: cor,
                ),
                const SizedBox(width: 3),
                Text(
                  '${pct.abs().toStringAsFixed(1).replaceAll('.', ',')}%',
                  style: TextStyle(
                    color: cor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: kTabular,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
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

/// Os números que o texto comentou: a cifra ao lado da frase sobre ela.
///
/// Separados dos outros porque comentar tudo é não comentar nada: aqui ficam
/// só os que mudaram, com o rail colorido pelo lado para o qual mudaram.
class _Destaques extends StatelessWidget {
  const _Destaques({required this.itens});

  final List<({KpiMensal kpi, String comentario})> itens;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < itens.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final k = itens[i].kpi;
              final boa = k.variacaoEhBoa;
              final cor = boa == null
                  ? neu.inkFaint
                  : (boa ? neu.success : neu.danger);
              // `IntrinsicHeight` porque o trilho colorido precisa ter a
              // altura do texto ao lado: num Row com `stretch` dentro de uma
              // página que rola, a altura disponível é infinita e o layout
              // quebra antes de desenhar qualquer coisa.
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            children: [
                              Text(
                                k.rotulo,
                                style: TextStyle(
                                  color: neu.ink,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                k.ehDinheiro
                                    ? formatMoney(k.valor)
                                    : k.valor.toStringAsFixed(0),
                                style: TextStyle(
                                  color: neu.ink,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: kTabular,
                                ),
                              ),
                              if (k.variacao != null)
                                Text(
                                  '${k.variacao!.pct >= 0 ? '+' : '−'}'
                                  '${k.variacao!.pct.abs().toStringAsFixed(1).replaceAll('.', ',')}%',
                                  style: TextStyle(
                                    color: cor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: kTabular,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            itens[i].comentario,
                            style: TextStyle(
                              color: neu.inkMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// O que foi bem × o que preocupa, lado a lado.
///
/// Lado a lado, e não em duas seções empilhadas, porque a leitura que importa
/// é a COMPARAÇÃO: um mês com três elogios e um problema é diferente de um mês
/// com um elogio e três problemas, e empilhados os dois parecem iguais.
class _BalancoDoMes extends StatelessWidget {
  const _BalancoDoMes({required this.foiBem, required this.preocupa});

  final List<String> foiBem;
  final List<String> preocupa;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final bom = _Coluna(
      titulo: 'O que foi bem',
      icone: Icons.thumb_up_outlined,
      cor: neu.success,
      itens: foiBem,
      vazio: 'Nenhum número melhorou em relação ao mês anterior.',
    );
    final ruim = _Coluna(
      titulo: 'O que preocupa',
      icone: Icons.report_problem_outlined,
      cor: neu.warning,
      itens: preocupa,
      vazio: 'Nada no mês pede atenção imediata.',
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [bom, const SizedBox(height: 14), ruim],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: bom),
              const SizedBox(width: 14),
              Expanded(child: ruim),
            ],
          ),
        );
      },
    );
  }
}

class _Coluna extends StatelessWidget {
  const _Coluna({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.itens,
    required this.vazio,
  });

  final String titulo;
  final IconData icone;
  final Color cor;
  final List<String> itens;
  final String vazio;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: cor),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (itens.isEmpty)
            Text(
              vazio,
              style: TextStyle(
                color: neu.inkFaint,
                fontSize: 13.5,
                height: 1.5,
              ),
            )
          else
            for (var i = 0; i < itens.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == itens.length - 1 ? 0 : 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: 10),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: cor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        itens[i],
                        style: TextStyle(
                          color: neu.inkMuted,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// O fechamento: a última frase, no peso de uma citação.
class _Fechamento extends StatelessWidget {
  const _Fechamento({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: EdgeInsets.fromLTRB(
        context.isMobile ? 18 : 26,
        22,
        context.isMobile ? 18 : 26,
        22,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: neu.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  texto,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 16,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O mês ainda em andamento — sem texto escrito, mas com o que já existe.
class _SemResumo extends StatelessWidget {
  const _SemResumo({
    required this.rotuloDoMes,
    required this.mesCorrente,
    required this.serie,
    required this.aoVerPainel,
  });

  final String rotuloDoMes;
  final bool mesCorrente;
  final List<PontoDiario> serie;
  final VoidCallback aoVerPainel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DocumentoAindaNaoEscrito(
          rotuloDoMes: rotuloDoMes,
          mesCorrente: mesCorrente,
        ),
        if (serie.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Secao(
            titulo: 'O mês até aqui',
            legenda: 'O faturamento já registrado, dia a dia.',
            aoAbrir: aoVerPainel,
            rotuloAbrir: 'Ver o painel completo',
            child: SizedBox(
              height: 200,
              child: ColunasPorDia(
                dias: [for (final p in serie) p.dia],
                valores: [for (final p in serie) p.valor.toDouble()],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A espera, com o texto certo.
class _Escrevendo extends StatelessWidget {
  const _Escrevendo();

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: neu.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Buscando o relatório do mês',
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem, required this.onRetry});

  final String mensagem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: neu.danger, size: 26),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          NeuButton(
            label: 'Tentar de novo',
            kind: NeuButtonKind.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
