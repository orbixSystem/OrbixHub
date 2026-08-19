import 'package:flutter/material.dart';

import 'neu_surface.dart';
import 'neu_tokens.dart';

/// Variantes do botão do design system.
enum NeuButtonKind {
  /// Ação principal: navy sólido, alto contraste (usabilidade primeiro —
  /// nunca "fantasma" neumórfico).
  primary,

  /// Ação secundária: extrudado na cor da superfície.
  secondary,

  /// Ação destrutiva: vermelho sólido.
  danger,
}

/// Botão padrão. Sempre com rótulo (usuário pouco digital); ícone opcional.
/// Alvo mínimo 48px. Afunda ao pressionar.
class NeuButton extends StatefulWidget {
  const NeuButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.kind = NeuButtonKind.primary,
    this.expanded = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NeuButtonKind kind;

  /// Ocupa a largura disponível (formulários mobile).
  final bool expanded;

  /// Mostra spinner e desabilita.
  final bool loading;

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;

    final (Color bg, Color fg) = switch (widget.kind) {
      NeuButtonKind.primary => (
          _hovered && _enabled ? neu.navyHover : neu.navy,
          neu.onNavy,
        ),
      NeuButtonKind.secondary => (
          _hovered && _enabled ? neu.surfaceHi : neu.surface,
          neu.ink,
        ),
      NeuButtonKind.danger => (neu.danger, Colors.white),
    };

    final content = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 20, color: fg),
        if (widget.loading || widget.icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              // 16px: rótulo de botão é "texto padrão de componente".
              fontSize: 16,
            ),
          ),
        ),
      ],
    );

    return FocusableActionDetector(
      enabled: _enabled,
      onShowHoverHighlight: (h) => setState(() => _hovered = h),
      mouseCursor:
          _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: _enabled ? widget.onPressed : null,
          child: Opacity(
            opacity: _enabled ? 1 : .55,
            child: NeuSurface(
              elevation: widget.kind == NeuButtonKind.secondary
                  ? (_pressed ? NeuElevation.pressed : NeuElevation.raised)
                  // Sólidos (primary/danger) mantêm a cor; o "afundar" vem da
                  // sombra sumir.
                  : (_pressed ? NeuElevation.flat : NeuElevation.raised),
              color: bg,
              radius: NeuTokens.rField,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 22),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de ícone circular (voltar, fechar, ações de toolbar). Alvo 48px.
class NeuIconButton extends StatefulWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.size = 48,
  });

  final IconData icon;

  /// Obrigatório: acessibilidade + descoberta (usuário pouco digital).
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  @override
  State<NeuIconButton> createState() => _NeuIconButtonState();
}

class _NeuIconButtonState extends State<NeuIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final enabled = widget.onPressed != null;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Opacity(
            opacity: enabled ? 1 : .55,
            child: NeuSurface(
              elevation: _pressed ? NeuElevation.pressed : NeuElevation.raised,
              radius: widget.size / 2,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Icon(
                  widget.icon,
                  size: widget.size * .42,
                  color: widget.color ?? neu.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
