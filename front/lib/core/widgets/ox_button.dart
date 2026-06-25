import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

enum OxButtonVariant { primary, secondary }

/// Botão tátil com sombra sólida de 2px que some ao pressionar.
/// primary: Orbix Blue + shadow; secondary: transparente + borda.
class OxButton extends StatefulWidget {
  const OxButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.variant = OxButtonVariant.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final OxButtonVariant variant;
  final bool expand;

  @override
  State<OxButton> createState() => _OxButtonState();
}

class _OxButtonState extends State<OxButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;
    final isPrimary = widget.variant == OxButtonVariant.primary;

    final bg = isPrimary
        ? (disabled ? AppColors.inkFaint : AppColors.brand)
        : Colors.transparent;
    final fg = isPrimary
        ? Colors.white
        : (disabled ? AppColors.inkFaint : AppColors.ink);
    final shadowColor = isPrimary
        ? (disabled ? Colors.transparent : AppColors.brandDeep)
        : (disabled ? Colors.transparent : const Color(0x22000000));

    final inner = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, color: fg, size: 16),
            const SizedBox(width: 7),
          ],
          Text(
            widget.label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );

    final decorated = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
      width: widget.expand ? double.infinity : null,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: isPrimary ? null : Border.all(color: AppColors.line),
        boxShadow: (_pressed || disabled)
            ? []
            : [
                BoxShadow(
                  color: shadowColor,
                  offset: const Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: inner,
    );

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: disabled ? null : widget.onPressed,
      child: decorated,
    );
  }
}
