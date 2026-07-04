import 'package:flutter/material.dart';

import 'neu_tokens.dart';

/// Níveis de relevo do soft-UI.
enum NeuElevation {
  /// Sem sombra — plano, no nível da base.
  flat,

  /// Extrudado padrão (cartões, botões em repouso).
  raised,

  /// Extrudado alto (dialogs, FAB, overlays).
  raisedHigh,

  /// Afundado (feedback de toque / item selecionado).
  pressed,

  /// Cavado (campos de entrada, trilhas).
  inset,
}

/// Superfície base do design system: pinta o relevo neumórfico correto para
/// cada [NeuElevation]. Todos os componentes Neu* derivam daqui.
///
/// `pressed`/`inset` são simulados com fundo levemente escurecido + brilho
/// interno em gradiente (Flutter não tem BoxShadow inset nativo) — barato e
/// idêntico ao olho na prática.
class NeuSurface extends StatelessWidget {
  const NeuSurface({
    super.key,
    required this.child,
    this.elevation = NeuElevation.raised,
    this.color,
    this.radius = NeuTokens.rCard,
    this.padding,
    this.border,
    this.duration = const Duration(milliseconds: 120),
  });

  final Widget child;
  final NeuElevation elevation;

  /// Cor da superfície; default = `surface` (raised) ou `base` (inset).
  final Color? color;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;

  /// Animação implícita entre estados (ex.: raised → pressed).
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final r = BorderRadius.circular(radius);

    final (Color bg, List<BoxShadow> shadows, Gradient? overlay) =
        switch (elevation) {
      NeuElevation.flat => (color ?? neu.base, const <BoxShadow>[], null),
      NeuElevation.raised => (color ?? neu.surface, neu.raised(), null),
      NeuElevation.raisedHigh => (
          color ?? neu.surface,
          neu.raised(high: true),
          null
        ),
      NeuElevation.pressed => (
          color ?? neu.base,
          const <BoxShadow>[],
          _innerGlow(neu, strength: .5)
        ),
      NeuElevation.inset => (
          color ?? neu.base,
          const <BoxShadow>[],
          _innerGlow(neu, strength: 1)
        ),
    };

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: border ??
            (elevation == NeuElevation.inset
                ? Border.all(color: neu.shadowDark.withValues(alpha: .18))
                : null),
        boxShadow: shadows,
        gradient: overlay,
      ),
      child: child,
    );
  }

  /// Gradiente diagonal que simula sombra interna: escuro no topo-esquerda
  /// (onde a "luz" não bate dentro da cavidade), clareando ao fundo-direita.
  static Gradient _innerGlow(NeuTokens neu, {required double strength}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          neu.shadowDark.withValues(alpha: .10 * strength),
          neu.base,
        ),
        neu.base,
        Color.alphaBlend(
          neu.shadowLight.withValues(alpha: .45 * strength),
          neu.base,
        ),
      ],
      stops: const [0, .55, 1],
    );
  }
}
