import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import 'appearance_section.dart';
import 'company_form.dart';
import 'dynamic_section.dart';

/// Tela de Configurações — corpo apenas (o shell é dono da moldura).
///
/// Exibe:
/// 1. [CompanyForm] para editar dados da empresa.
/// 2. Um card placeholder de Aparência (Task 5.1).
/// 3. Um [DynamicSection] por seção de módulo habilitado (moduleKey != null).
///
/// Se o usuário não tiver permissão `settings.manage`, exibe uma mensagem de
/// acesso negado em vez do formulário.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    // ---- Permission gate ------------------------------------------------
    if (session is SessionAuthenticated) {
      if (!session.me.hasPermission('settings.manage')) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'Acesso negado',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Você não tem permissão para acessar as configurações.\n'
                  'Fale com o proprietário da conta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      }
    }

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
              'Gerencie os dados da empresa, identidade visual e preferências dos módulos.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
            ),
            const SizedBox(height: 24),

            // ---- Empresa & Identidade visual ----------------------------
            CompanyForm(bundle: bundle, company: bundle.company),
            const SizedBox(height: 24),

            // ---- Aparência (Task 5.1) ------------------------------------
            AppearanceSection(company: bundle.company),

            // ---- Module sections ----------------------------------------
            if (moduleSections.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Configurações por módulo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (final section in moduleSections) ...[
                DynamicSection(
                  section: section,
                  values: bundle.company,
                ),
                if (section != moduleSections.last) const SizedBox(height: 16),
              ],
            ],

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}
