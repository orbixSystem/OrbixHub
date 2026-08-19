import 'package:flutter/material.dart';

import 'neu_surface.dart';
import 'neu_tokens.dart';

/// Chip de ícone colorido (glyph) — como os ícones da referência visual:
/// quadradinho extrudado com ícone vivo sobre tint da mesma cor.
class NeuIconChip extends StatelessWidget {
  const NeuIconChip({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  /// Constrói com uma cor estável da paleta de glyphs a partir de um índice
  /// (ex.: índice do módulo) — mantém a mesma cor entre sessões.
  NeuIconChip.glyph(
    BuildContext context, {
    super.key,
    required this.icon,
    required int index,
    this.size = 44,
  }) : color = context.neu.glyphs[index % context.neu.glyphs.length];

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      elevation: NeuElevation.raised,
      radius: size * .32,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .32),
          color: color.withValues(alpha: .14),
        ),
        child: Icon(icon, size: size * .5, color: color),
      ),
    );
  }
}

/// Bolha de contagem (não-lidas, pendências).
class NeuBadge extends StatelessWidget {
  const NeuBadge({super.key, required this.count, this.color});

  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? neu.danger,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Chip de status (OS, assinatura, NF…): tint + texto forte da cor semântica.
class NeuStatusChip extends StatelessWidget {
  const NeuStatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.tint,
    this.icon,
  });

  final String label;
  final Color color;
  final Color tint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          // Flexible + ellipsis: em coluna estreita (painel da agenda, cards no
          // mobile) um rótulo longo como "Aguardando aprovação" estourava o
          // chip. Quando há espaço, o resultado é idêntico ao de antes.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
