import 'package:flutter/widgets.dart';

/// Faixas de layout do app (spec 2026-07-04):
/// mobile `<600` · tablet `600–1100` · desktop `≥1100`.
enum ScreenSize { mobile, tablet, desktop }

abstract final class Breakpoints {
  static const double tablet = 600;
  static const double desktop = 1100;

  static ScreenSize of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= desktop) return ScreenSize.desktop;
    if (w >= tablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }
}

/// Largura máxima da área de conteúdo em telas grandes.
///
/// Sem teto, num monitor de 27" os cartões e as linhas de tabela esticam de
/// ponta a ponta: o olho perde a linha entre a primeira e a última coluna e o
/// texto vira uma faixa longa e rala. É o mesmo motivo de um jornal ter colunas
/// em vez de uma linha atravessando a página.
///
/// 1400 é escolhido para NÃO mexer em notebook nenhum: com a sidebar (272px),
/// um monitor de 1440 deixa ~1168px de conteúdo, bem abaixo do teto. O limite
/// só começa a agir por volta de 1700px de tela — exatamente onde o problema
/// aparece.
const double kLarguraMaximaDeConteudo = 1400;

/// Centraliza o conteúdo e o limita a [kLarguraMaximaDeConteudo].
///
/// Aplicado UMA vez, na casca — as telas não precisam saber que existe. Envolver
/// tela por tela daria o mesmo resultado hoje e divergiria na primeira tela que
/// alguém esquecesse.
class ConteudoLimitado extends StatelessWidget {
  const ConteudoLimitado({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // Largura JUSTA, não um `maxWidth` solto: `Align`/`Center` com
      // `ConstrainedBox` afrouxam a constraint, e aí toda tela que conta com
      // ser esticada (Column stretch, Row com Expanded) passaria a encolher
      // para o tamanho do conteúdo. Como isto envolve o app inteiro, o efeito
      // colateral seria em toda tela de uma vez.
      if (!c.hasBoundedWidth || c.maxWidth <= kLarguraMaximaDeConteudo) {
        return child;
      }
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: kLarguraMaximaDeConteudo, child: child),
      );
    },
  );
}

extension AdaptiveContext on BuildContext {
  ScreenSize get screenSize => Breakpoints.of(this);
  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;
}

/// Constrói corpos distintos por faixa quando os layouts realmente divergem.
/// [tablet] cai para [desktop] quando não informado (rail compacto + conteúdo
/// desktop costuma bastar); telas simples nem precisam deste widget.
class AdaptiveBody extends StatelessWidget {
  const AdaptiveBody({
    super.key,
    required this.mobile,
    required this.desktop,
    this.tablet,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder desktop;
  final WidgetBuilder? tablet;

  @override
  Widget build(BuildContext context) {
    return switch (context.screenSize) {
      ScreenSize.mobile => mobile(context),
      ScreenSize.tablet => (tablet ?? desktop)(context),
      ScreenSize.desktop => desktop(context),
    };
  }
}
