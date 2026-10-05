import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import 'motion.dart';

/// As peças de montagem de um painel: card de gráfico, faixa de KPIs e a grade
/// de duas colunas.
///
/// Elas existem para que toda aba de Relatórios tenha o MESMO esqueleto — mesma
/// altura de conteúdo, mesmo cabeçalho, mesma grade. Um painel onde cada card
/// tem uma altura diferente não parece um painel, parece uma pilha de coisas
/// que foram sendo adicionadas.

/// O caminho do resumo para a página que trata do assunto por inteiro.
class AtalhoDeCard {
  const AtalhoDeCard({required this.rotulo, required this.aoTocar});

  final String rotulo;
  final VoidCallback aoTocar;
}

/// Card de gráfico: cabeçalho enxuto, corpo de altura fixa.
///
/// O subtítulo diz o que o gráfico mede (não o que ele é) e o "?" guarda a
/// explicação longa — a que responde "de onde vem esse número". Deixar essa
/// explicação fora do card obrigaria o dono a perguntar para alguém; deixá-la
/// visível empurraria o gráfico para baixo em todos os cards.
class CardDeGrafico extends StatelessWidget {
  const CardDeGrafico({
    super.key,
    required this.titulo,
    required this.child,
    this.subtitulo,
    this.valor,
    this.info,
    this.altura = 240,
    this.vazio = false,
    this.mensagemVazio = 'Sem dados no período.',
    this.rodape,
    this.atalho,
  });

  final String titulo;

  /// Uma linha sobre o que o gráfico mede.
  final String? subtitulo;

  /// Número de destaque no canto do cabeçalho (o total, normalmente).
  final String? valor;

  /// Explicação longa, atrás do "?".
  final String? info;

  final double altura;
  final bool vazio;
  final String mensagemVazio;

  /// Linha discreta abaixo do gráfico — legenda, contagem, observação.
  final Widget? rodape;

  /// Para onde ir ver isto por inteiro.
  ///
  /// Existe para a página de abertura: ela condensa um gráfico de cada
  /// assunto, e sem o caminho de volta o dono veria o resumo do estoque sem
  /// descobrir que há uma aba inteira sobre ele.
  final AtalhoDeCard? atalho;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitulo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neu.inkFaint,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (valor != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    valor!,
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFeatures: kTabular,
                    ),
                  ),
                ],
                if (info != null) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: info!,
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: neu.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, thickness: 1 / MediaQuery.devicePixelRatioOf(context), color: neu.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: SizedBox(
              height: altura,
              child: vazio
                  ? _Vazio(mensagem: mensagemVazio)
                  : child,
            ),
          ),
          if (rodape != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: rodape!,
            ),
          if (atalho != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16, rodape == null ? 0 : 0, 10, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: atalho!.aoTocar,
                  icon: Text(
                    atalho!.rotulo,
                    style: TextStyle(
                      color: neu.navy,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  label: Icon(Icons.arrow_forward_rounded, size: 15, color: neu.navy),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.mensagem});
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded, size: 24, color: neu.line),
          const SizedBox(height: 8),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: TextStyle(color: neu.inkFaint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Grade de duas colunas (uma só no estreito).
///
/// Lado a lado dois gráficos se comparam; empilhados, o segundo já saiu da tela
/// quando o olho chega nele.
class GradeDeGraficos extends StatelessWidget {
  const GradeDeGraficos({super.key, required this.cards, this.espaco = 14});

  final List<Widget> cards;
  final double espaco;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(height: espaco),
                cards[i],
              ],
            ],
          );
        }
        final linhas = <Widget>[];
        for (var i = 0; i < cards.length; i += 2) {
          final direita = i + 1 < cards.length ? cards[i + 1] : null;
          linhas.add(
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : espaco),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[i]),
                    SizedBox(width: espaco),
                    // Sem par, o card ocupa metade e o resto fica vazio: um
                    // gráfico esticado ao dobro da largura dos outros quebra o
                    // ritmo da grade inteira.
                    Expanded(child: direita ?? const SizedBox.shrink()),
                  ],
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: linhas,
        );
      },
    );
  }
}

/// Um indicador da faixa superior.
class IndicadorPainel {
  const IndicadorPainel({
    required this.rotulo,
    required this.valor,
    required this.icone,
    this.detalhe,
    this.cor,
  });

  final String rotulo;
  final String valor;
  final IconData icone;

  /// Linha de apoio — a comparação, a parcela, o contexto.
  final String? detalhe;

  /// Cor do ícone e do detalhe quando o número pede atenção.
  final Color? cor;
}

/// A faixa de indicadores no topo da aba.
///
/// Compacta de propósito: ela é o resumo que o olho pega antes de descer para
/// os gráficos, e KPI gigante ocupando meia tela adia a pergunta seguinte.
class FaixaDeIndicadores extends StatelessWidget {
  const FaixaDeIndicadores({super.key, required this.itens, this.colunas = 4});

  final List<IndicadorPainel> itens;
  final int colunas;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final n = c.maxWidth < 620
            ? 2
            : c.maxWidth < 1000
                ? 3
                : colunas;
        const gap = 12.0;
        final largura = (c.maxWidth - gap * (n - 1)) / n;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final i in itens)
              SizedBox(width: largura, child: _Indicador(item: i)),
          ],
        );
      },
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({required this.item});
  final IndicadorPainel item;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cor = item.cor ?? neu.navy;
    return NeuCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(NeuTokens.rChip),
            ),
            child: Icon(item.icone, size: 17, color: cor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.valor,
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      fontFeatures: kTabular,
                    ),
                  ),
                ),
                if (item.detalhe != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.detalhe!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: item.cor ?? neu.inkFaint,
                      fontSize: 12,
                      fontWeight: item.cor != null
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "R$ 31,3 mil" — o miolo de uma rosca e um KPI apertado têm lugar para um
/// número, não para sete dígitos com centavos.
String compactoEmReais(num v) {
  if (v >= 1000000) {
    return 'R\$ ${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')} mi';
  }
  if (v >= 1000) {
    return 'R\$ ${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')} mil';
  }
  return formatMoney(v);
}

/// "27% do total" — ou travessão, quando não há total contra o que comparar.
String fatiaDoTotal(num parte, num total) =>
    total <= 0 ? '—' : '${(parte * 100 / total).round()}% do total';

/// A linha de números sob um gráfico.
///
/// É onde moram as leituras que o desenho sugere mas não afirma — a média, o
/// pico, o saldo. Escritas, elas podem ser copiadas para uma conversa; lidas
/// do gráfico, são sempre uma estimativa.
class RodapeDeCard extends StatelessWidget {
  const RodapeDeCard({super.key, required this.itens});

  final List<(String, String)> itens;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      children: [
        for (var i = 0; i < itens.length; i++) ...[
          if (i > 0)
            Container(
              width: 1 / MediaQuery.devicePixelRatioOf(context),
              height: 26,
              color: neu.line,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  itens[i].$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neu.inkFaint, fontSize: 12),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    itens[i].$2,
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: kTabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Uma linha do ranking de um card.
typedef LinhaDeRanking = ({String rotulo, num valor, String texto, Color? cor});

/// Ranking em barras DEITADAS dentro de um card de altura fixa.
///
/// Deitadas porque o rótulo é um nome — "Pastilha de freio dianteira", "João
/// Mecânico". Na vertical esse texto vira diagonal ou reticências, e o gráfico
/// passa a exigir uma legenda para dizer o que já estava escrito.
class RankingDeBarras extends StatelessWidget {
  const RankingDeBarras({
    super.key,
    required this.itens,
    this.limite = 6,
    this.ocultarZeros = true,
    this.maximoFixo,
  });

  final List<LinhaDeRanking> itens;
  final int limite;

  /// Esconde as linhas de valor zero.
  ///
  /// Barra de tamanho zero não informa nada e ainda rouba uma linha de quem
  /// informa. A exceção é quando o ZERO é a notícia — estoque zerado, por
  /// exemplo —, e aí o chamador desliga isto.
  final bool ocultarZeros;

  /// A escala das barras, quando ela NÃO é "o maior item da lista".
  ///
  /// Num ranking a barra maior é sempre cheia, porque a pergunta é "quem é o
  /// maior". Quando o valor já é uma fração de algo (o estoque contra o
  /// mínimo, por exemplo), normalizar pelo maior pintaria quatro itens
  /// faltando como quatro barras cheias — exatamente o contrário do que
  /// aconteceu.
  final double? maximoFixo;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final mostrar = (ocultarZeros ? itens.where((i) => i.valor > 0) : itens)
        .take(limite)
        .toList();
    if (mostrar.isEmpty) return const SizedBox.shrink();
    final maior = maximoFixo ??
        mostrar
            .map((i) => i.valor.toDouble())
            .fold<double>(0, (a, b) => b > a ? b : a);
    final semMovimento = MediaQuery.disableAnimationsOf(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < mostrar.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mostrar[i].rotulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          mostrar[i].texto,
                          style: TextStyle(
                            color: neu.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: kTabular,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 6,
                    color: neu.line,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _Barra(
                        // A primeira barra é cheia e as seguintes esmaecem: sem
                        // isso o ranking é uma lista de retângulos iguais e a
                        // ordem precisa ser lida, em vez de vista.
                        cor: (mostrar[i].cor ?? neu.accent).withValues(
                          alpha: 1 - (i / (mostrar.length + 2)) * 0.55,
                        ),
                        proporcao:
                            maior <= 0 ? 0 : mostrar[i].valor / maior,
                        anima: !semMovimento,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.cor,
    required this.proporcao,
    required this.anima,
  });

  final Color cor;
  final num proporcao;
  final bool anima;

  @override
  Widget build(BuildContext context) {
    final alvo = proporcao.toDouble().clamp(0.0, 1.0);
    if (!anima) {
      return FractionallySizedBox(
        widthFactor: alvo,
        child: Container(color: cor),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: alvo),
      duration: kAberturaLonga,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => FractionallySizedBox(
        widthFactor: t,
        child: Container(color: cor),
      ),
    );
  }
}

/// O esqueleto de um painel enquanto os números não chegam.
///
/// Tem a FORMA do que vem: a faixa de indicadores e a primeira linha de
/// cards. Um spinner no lugar não prepara o olho para nada e faz a tela
/// "pular" quando o conteúdo chega.
class PainelCarregando extends StatelessWidget {
  const PainelCarregando({super.key});

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    Widget bloco(double altura) => Container(
          height: altura,
          decoration: BoxDecoration(
            color: neu.line.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(NeuTokens.rCard),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bloco(62),
        const SizedBox(height: 14),
        bloco(62),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: bloco(300)),
            const SizedBox(width: 14),
            Expanded(child: bloco(300)),
          ],
        ),
      ],
    );
  }
}

/// O painel que não pôde ser montado.
///
/// Some em silêncio era pior: a tela ficava com um buraco entre as abas e o
/// detalhamento, e quem olhasse concluiria que a oficina não tem dados — e não
/// que a busca falhou.
class PainelComErro extends StatelessWidget {
  const PainelComErro({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, color: neu.inkFaint, size: 24),
          const SizedBox(height: 10),
          Text(
            'Não foi possível montar o painel.',
            style: TextStyle(color: neu.inkMuted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'O detalhamento abaixo continua disponível.',
            style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
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

/// O aviso de que o painel NÃO aplica um filtro que está na barra.
///
/// Existe porque a alternativa é pior: o dono filtra por um mecânico, os
/// gráficos continuam mostrando a oficina inteira e nada na tela diz isso.
/// Ele some quando não há filtro que o painel ignore — um aviso permanente
/// deixa de ser lido na segunda visita.
class AvisoDeFiltroParcial extends StatelessWidget {
  const AvisoDeFiltroParcial({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: neu.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        border: Border.all(color: neu.warning.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 9),
            child: Icon(Icons.info_outline_rounded, size: 15, color: neu.warning),
          ),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: neu.inkMuted, fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
