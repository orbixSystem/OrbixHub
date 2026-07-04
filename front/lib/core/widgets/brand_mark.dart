import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ui/neu_tokens.dart';

/// The Orbix glyph: an orbital ring with a lavender body — a small, precise
/// identity mark drawn with a painter so it stays crisp at any size.
/// (Paleta fixa do redesign 2026-07: violeta/lavanda; o laranja legado saiu.)
class OrbixGlyph extends StatelessWidget {
  const OrbixGlyph({super.key, this.size = 28, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(
        onDark: onDark,
        bodyA: const Color(0xFF9BA2E8),
        bodyB: const Color(0xFF6C72C4),
        ring: onDark ? const Color(0xFF8A90B8) : neu.inkFaint,
        node: onDark ? Colors.white : neu.navy,
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.onDark,
    required this.bodyA,
    required this.bodyB,
    required this.ring,
    required this.node,
  });

  final bool onDark;
  final Color bodyA;
  final Color bodyB;
  final Color ring;
  final Color node;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Orbital ring (an open arc) in a soft tone.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..color = ring;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.92),
      -math.pi * 0.15,
      math.pi * 1.55,
      false,
      ringPaint,
    );

    // The body — a lavender sphere with a highlight.
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [bodyA, bodyB],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.5));
    canvas.drawCircle(c, r * 0.46, body);

    // Orbiting node.
    final nodePaint = Paint()..color = node;
    const nodeAngle = -math.pi * 0.15;
    final nodePos = c +
        Offset(math.cos(nodeAngle), math.sin(nodeAngle)) * (r * 0.92);
    canvas.drawCircle(nodePos, size.width * 0.085, nodePaint);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.onDark != onDark || old.bodyA != bodyA;
}

/// Glyph + "OrbixHub" wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 26, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final baseColor = onDark ? const Color(0xFFF2F3F8) : neu.ink;
    final accentColor =
        onDark ? const Color(0xFFAEB4F0) : const Color(0xFF6C72C4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OrbixGlyph(size: size, onDark: onDark),
        SizedBox(width: size * 0.42),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Orbix',
                style: GoogleFonts.sora(
                  fontSize: size * 0.74,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: baseColor,
                ),
              ),
              TextSpan(
                text: 'Hub',
                style: GoogleFonts.sora(
                  fontSize: size * 0.74,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
