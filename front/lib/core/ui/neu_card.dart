import 'package:flutter/material.dart';

import 'neu_surface.dart';
import 'neu_tokens.dart';

/// Cartão padrão do app (extrudado). Se [onTap] for dado, afunda ao pressionar
/// — o feedback tátil padrão do design system.
class NeuCard extends StatefulWidget {
  const NeuCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = NeuTokens.rCard,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  State<NeuCard> createState() => _NeuCardState();
}

class _NeuCardState extends State<NeuCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final surface = NeuSurface(
      elevation: _pressed ? NeuElevation.pressed : NeuElevation.raised,
      radius: widget.radius,
      padding: widget.padding,
      color: _pressed ? null : widget.color,
      child: widget.child,
    );
    if (widget.onTap == null) return surface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: surface),
    );
  }
}

/// Painel navy de contraste (sidebar, cards de destaque) — como na referência
/// visual: bloco escuro dentro do canvas claro.
class NeuPanel extends StatelessWidget {
  const NeuPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = NeuTokens.rPanel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // No claro o painel é o navy ESCURO fixo (contraste — não segue o roxo
    // primário); no escuro usamos a superfície elevada.
    final bg = isDark ? neu.surfaceHi : const Color(0xFF2B2F44);
    final fg = isDark ? neu.ink : const Color(0xFFF2F3F8);
    return NeuSurface(
      elevation: NeuElevation.raisedHigh,
      radius: radius,
      padding: padding,
      color: bg,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: IconTheme.merge(
          data: IconThemeData(color: fg),
          child: child,
        ),
      ),
    );
  }
}
