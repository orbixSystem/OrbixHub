import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import 'appearance_section.dart';
import 'company_form.dart';
import 'dynamic_section.dart';

/// Tela de Configurações — corpo apenas (o shell é dono da moldura).
///
/// Visível para QUALQUER membro autenticado:
/// - [AppearanceSection] (presets de tema + claro/escuro) — sempre exibida.
/// - [CompanyForm] e seções de módulo — exibidas apenas quando o usuário tem
///   `settings.manage` (owner / gerente).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    // Determina se o usuário tem a permissão para editar empresa e módulos.
    final canManage = session is SessionAuthenticated &&
        session.me.hasPermission('settings.manage');

    // ---- Settings data --------------------------------------------------
    final settingsAsync = ref.watch(settingsControllerProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar configurações',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () =>
                    ref.read(settingsControllerProvider.notifier).load(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      data: (bundle) {
        final moduleSections =
            bundle.sections.where((s) => s.moduleKey != null).toList();

        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            // Page header
            Text(
              'Configurações',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              canManage
                  ? 'Gerencie os dados da empresa, identidade visual e preferências dos módulos.'
                  : 'Personalize a aparência da sua interface.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
            ),
            const SizedBox(height: 24),

            // ---- Empresa & Identidade visual (apenas com settings.manage) -
            if (canManage) ...[
              _CollapsibleSection(
                title: 'Empresa & Identidade visual',
                initiallyExpanded: true,
                child: CompanyForm(
                  bundle: bundle,
                  company: bundle.company,
                  embedded: true,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ---- Aparência (sempre visível a qualquer membro) ------------
            _CollapsibleSection(
              title: 'Aparência',
              initiallyExpanded: !canManage, // aberta por padrão para não-owners
              child: AppearanceSection(
                company: bundle.company,
                embedded: true,
              ),
            ),

            // ---- Module sections (apenas com settings.manage) ------------
            if (canManage && moduleSections.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Configurações por módulo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Gerenciado pelo sistema',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final section in moduleSections) ...[
                _CollapsibleSection(
                  title: section.title,
                  initiallyExpanded: false,
                  child: DynamicSection(
                    section: section,
                    values: section.values,
                    hideTitle: true,
                  ),
                ),
                if (section != moduleSections.last) const SizedBox(height: 12),
              ],
            ],

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

/// Card expansível que envolve uma seção de configurações.
///
/// O [title] aparece no cabeçalho do painel; o [child] é exibido quando
/// expandido. Usa [ExpansionTile] com visual alinhado ao design system do
/// projeto (borda, cor de fundo via [ColorScheme], sem cores hardcoded).
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      color: scheme.surfaceContainerLowest,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        expansionAnimationStyle: AnimationStyle(
          curve: Curves.easeInOut,
          duration: const Duration(milliseconds: 200),
        ),
        backgroundColor: scheme.surfaceContainerLowest,
        collapsedBackgroundColor: scheme.surfaceContainerLowest,
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        children: [
          Divider(height: 1, color: scheme.outlineVariant),
          child,
        ],
      ),
    );
  }
}
