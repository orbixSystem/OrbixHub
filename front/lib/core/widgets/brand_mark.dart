import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// The Orbix glyph: an orbital ring with a tangerine body — a small, precise
/// identity mark drawn with a painter so it stays crisp at any size.
class OrbixGlyph extends StatelessWidget {
  const OrbixGlyph({super.key, this.size = 28, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(onDark: onDark),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.onDark});
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Orbital ring (an open arc) in a soft tone.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..color = onDark ? AppColors.onGraphiteMuted : AppColors.inkFaint;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.92),
      -math.pi * 0.15,
      math.pi * 1.55,
      false,
      ring,
    );

    // The body — a tangerine sphere with a highlight.
    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.brandBright, AppColors.brandDeep],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.5));
    canvas.drawCircle(c, r * 0.46, body);

    // Orbiting node.
    final node = Paint()..color = onDark ? Colors.white : AppColors.graphite;
    final nodeAngle = -math.pi * 0.15;
    final nodePos = c +
        Offset(math.cos(nodeAngle), math.sin(nodeAngle)) * (r * 0.92);
    canvas.drawCircle(nodePos, size.width * 0.085, node);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) => old.onDark != onDark;
}

/// Glyph + "OrbixHub" wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 26, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
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
                  color: onDark ? AppColors.onGraphite : AppColors.ink,
                ),
              ),
              TextSpan(
                text: 'Hub',
                style: GoogleFonts.sora(
                  fontSize: size * 0.74,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
