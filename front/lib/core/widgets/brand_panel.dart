import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'brand_mark.dart';

/// The dark brand hero shown beside auth forms on wide screens: a graphite
/// field with a tangerine gradient bloom, a faint engineering grid, the Orbix
/// mark, a confident headline and a few product proof-points.
class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.7, -0.9),
          radius: 1.4,
          colors: [Color(0xFF272A33), AppColors.graphite],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Tangerine bloom, bottom-left.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.9, 1.1),
                radius: 0.9,
                colors: [Color(0x33EC5E12), Color(0x00EC5E12)],
              ),
            ),
          ),
          // Faint engineering grid.
          const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Padding(
            padding: const EdgeInsets.all(44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandMark(size: 30, onDark: true),
                const Spacer(),
                Text(
                  'A central de\ncomando da sua\noficina.',
                  style: GoogleFonts.sora(
                    fontSize: 40,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                    color: AppColors.onGraphite,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Ordens de serviço, clientes, estoque e cobrança — '
                  'multi-empresa, em um só lugar.',
                  style: GoogleFonts.manrope(
                    fontSize: 15.5,
                    height: 1.5,
                    color: AppColors.onGraphiteMuted,
                  ),
                ),
                const SizedBox(height: 34),
                const _Proof(text: 'Multi-empresa com isolamento total'),
                const _Proof(text: 'Acesso por papel e por módulo'),
                const _Proof(text: 'Planos e cobrança integrados'),
                const Spacer(),
                Text(
                  '© 2026 OrbixHub',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: AppColors.onGraphiteMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Proof extends StatelessWidget {
  const _Proof({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.check_rounded,
                size: 14, color: AppColors.brandBright),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onGraphite.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 38.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
