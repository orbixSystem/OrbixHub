import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/brand_panel.dart';

/// Split-panel auth layout: a dark brand hero on the left (wide screens) and a
/// clean, width-constrained form on the right. Collapses to just the form on
/// narrow screens.
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
      body: wide
          ? Row(
              children: [
                const Expanded(flex: 5, child: BrandPanel()),
                Expanded(flex: 6, child: form),
              ],
            )
          : form,
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBrand) ...[
                const Center(child: BrandMark(size: 28)),
                const SizedBox(height: 40),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 30),
              child,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
