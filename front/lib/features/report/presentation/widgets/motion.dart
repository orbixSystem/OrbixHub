import 'package:flutter/material.dart';

/// O movimento desta tela — um gesto só, no carregamento.
///
/// A escolha é deliberada: entrada em cascata por seção e elevação no hover de
/// todo card são o default genérico, e lido como tal. Aqui o mês chega como um
/// documento sendo preparado — o fio se desenha, o número principal corre até o
/// valor, a linha do gráfico é traçada — e depois a tela fica quieta.
///
/// Tudo respeita [MediaQuery.disableAnimationsOf]: com movimento reduzido, cada
/// peça aparece no estado final, sem atalho nem versão empobrecida.

/// Duração compartilhada do gesto de abertura.
const kAberturaCurta = Duration(milliseconds: 420);
const kAberturaLonga = Duration(milliseconds: 780);

/// Algarismos de largura fixa.
///
/// Sem isto, a contagem do número principal faz a largura pular a cada quadro
/// (o "1" é mais estreito que o "8") e a coluna de valores do livro-caixa
/// deixa de alinhar na vírgula — que é a única razão de existir uma coluna.
const kTabular = [FontFeature.tabularFigures()];

/// Um fio que se desenha da esquerda para a direita.
///
/// É o gesto de abertura do documento: a régua sob o título sendo puxada.
/// Separa o cabeçalho do corpo e, ao mesmo tempo, diz que a página acabou de
/// ser montada para quem está olhando.
class FioQueDesenha extends StatelessWidget {
  const FioQueDesenha({
    super.key,
    required this.cor,
    this.espessura = 1,
    this.atraso = Duration.zero,
  });

  final Color cor;
  final double espessura;
  final Duration atraso;

  @override
  Widget build(BuildContext context) {
    final semMovimento = MediaQuery.disableAnimationsOf(context);
    final fio = Container(height: espessura, color: cor);
    if (semMovimento) return fio;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: kAberturaLonga,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(widthFactor: t, child: child),
      ),
      child: fio,
    );
  }
}

/// Um número que corre até o valor final.
///
/// Só o número de abertura usa isto. Animar todos os valores da página faria o
/// olho perseguir seis coisas ao mesmo tempo e nenhuma chegar — e um livro-caixa
/// inteiro em movimento é difícil de ler, não impressionante.
class NumeroQueConta extends StatelessWidget {
  const NumeroQueConta({
    super.key,
    required this.valor,
    required this.formatar,
    required this.estilo,
  });

  final num valor;
  final String Function(num) formatar;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) {
    Widget texto(num v) => Text(
          formatar(v),
          maxLines: 1,
          style: estilo.copyWith(fontFeatures: kTabular),
        );
    if (MediaQuery.disableAnimationsOf(context)) return texto(valor);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor.toDouble()),
      duration: kAberturaLonga,
      // Desacelera forte no fim: a leitura acontece quando o número para, e
      // uma curva linear dá a impressão de contador de posto de gasolina.
      curve: Curves.easeOutExpo,
      builder: (context, v, _) => texto(v),
    );
  }
}

/// Aparição discreta, usada UMA vez — no texto de abertura.
///
/// Sem deslocamento vertical: o "fade + sobe 20px" em cada bloco é a assinatura
/// visual de página gerada. Aqui o texto só ganha corpo, enquanto o fio é
/// puxado ao lado.
class SurgeSuave extends StatelessWidget {
  const SurgeSuave({super.key, required this.child, this.atraso = Duration.zero});

  final Widget child;
  final Duration atraso;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: kAberturaCurta + atraso,
      curve: Interval(
        atraso.inMilliseconds / (kAberturaCurta + atraso).inMilliseconds,
        1,
        curve: Curves.easeOut,
      ),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}
