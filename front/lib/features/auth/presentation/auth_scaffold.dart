import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/brand_panel.dart';

/// Split-panel auth layout: a dark brand hero on the left (wide screens) and a
/// neumorphic form CARD floating on the lavender canvas on the right.
/// Collapses to just the card on narrow screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 920;

    final form = _FormSide(
      title: title,
      subtitle: subtitle,
      showBrand: !wide,
      child: child,
    );

    return Scaffold(
      backgroundColor: context.neu.base,
      body: wide
          ? Row(
              children: [
                const Expanded(flex: 5, child: BrandPanel()),
                Expanded(flex: 6, child: form),
              ],
            )
          : SafeArea(child: form),
    );
  }
}

class _FormSide extends StatelessWidget {
  const _FormSide({
    required this.title,
    required this.subtitle,
    required this.showBrand,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final bool showBrand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    // No mobile o cartão ocupa quase toda a largura; em telas maiores flutua
    // centralizado sobre o canvas (o relevo neumórfico faz a moldura).
    final isMobile = context.isMobile;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 24 : 48,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBrand) ...[
                const Center(child: BrandMark(size: 28)),
                const SizedBox(height: 28),
              ],
              NeuSurface(
                elevation: NeuElevation.raisedHigh,
                radius: NeuTokens.rPanel,
                color: neu.surface,
                padding: EdgeInsets.all(isMobile ? 22 : 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: neu.ink),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: neu.inkMuted,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline error banner — generic backend messages (anti-enumeration).
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: neu.dangerTint,
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
        border: Border.all(color: neu.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: neu.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: neu.danger,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
