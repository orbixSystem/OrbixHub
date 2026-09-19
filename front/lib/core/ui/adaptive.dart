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
