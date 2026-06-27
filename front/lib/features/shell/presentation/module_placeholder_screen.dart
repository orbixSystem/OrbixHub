import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'nav_items.dart';

/// Placeholder for a product module (OS, inventory, customers). Real module UIs
/// are out of scope for this milestone; this gives module-gated navigation and
/// route guards a concrete, on-brand target.
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({super.key, required this.moduleKey});

  final String moduleKey;

  @override
  Widget build(BuildContext context) {
    final meta = moduleMeta[moduleKey] ?? (moduleKey, Icons.extension_outlined);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(meta.$2, size: 36, color: AppColors.brandDeep),
            ),
            const SizedBox(height: 20),
            Text(meta.$1, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Este módulo está habilitado no seu plano. A tela completa chega '
              'em breve.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkMuted, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.successTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 15, color: AppColors.success),
                  SizedBox(width: 6),
                  Text('Acesso liberado',
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
