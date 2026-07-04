import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import 'appearance_section.dart';
import 'company_form.dart';
import 'dynamic_section.dart';

/// Uma categoria de configuração (item da navegação + conteúdo).
class _Category {
  const _Category({
    required this.title,
    required this.icon,
    required this.builder,
  });
  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

/// Tela de Configurações — corpo apenas (o shell é dono da moldura).
///
/// Layout master-detail (profissional): navegação por categorias — trilha
/// lateral no desktop/tablet, chips roláveis no mobile — + conteúdo da
/// categoria selecionada num cartão. Aparência é pública; Empresa e módulos
/// exigem `settings.manage`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final neu = context.neu;
    final canManage = session is SessionAuthenticated &&
        session.me.hasPermission('settings.manage');

    final settingsAsync = ref.watch(settingsControllerProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: neu.danger),
              const SizedBox(height: 16),
              Text('Erro ao carregar configurações',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(err.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: neu.inkMuted)),
              const SizedBox(height: 16),
              NeuButton(
                label: 'Tentar novamente',
                icon: Icons.refresh,
                onPressed: () =>
                    ref.read(settingsControllerProvider.notifier).load(),
              ),
            ],
          ),
        ),
      ),
      data: (bundle) {
        final moduleSections =
            bundle.sections.where((s) => s.moduleKey != null).toList();

        // Monta as categorias conforme a permissão.
        final categories = <_Category>[
          if (canManage)
            _Category(
              title: 'Empresa & Identidade visual',
              icon: Icons.storefront_outlined,
              builder: (_) => CompanyForm(
                bundle: bundle,
                company: bundle.company,
                embedded: true,
              ),
            ),
          _Category(
            title: 'Aparência',
            icon: Icons.palette_outlined,
            builder: (_) =>
                AppearanceSection(company: bundle.company, embedded: true),
          ),
          if (canManage)
            for (final section in moduleSections)
              _Category(
                title: section.title,
                icon: Icons.tune_rounded,
                builder: (_) => DynamicSection(
                  section: section,
                  values: section.values,
                  hideTitle: true,
                ),
              ),
        ];

        final selected = _selected.clamp(0, categories.length - 1);
        final isMobile = context.isMobile;

        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configurações',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              canManage
                  ? 'Dados da empresa, identidade visual e preferências dos módulos.'
                  : 'Personalize a aparência da sua interface.',
              style: TextStyle(color: neu.inkMuted, fontSize: 15),
            ),
          ],
        );

        final content = NeuCard(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: SingleChildScrollView(
            key: ValueKey(selected),
            child: categories[selected].builder(context),
          ),
        );

        return Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 20),
              if (isMobile) ...[
                _CategoryChips(
                  categories: categories,
                  selected: selected,
                  onSelect: (i) => setState(() => _selected = i),
                ),
                const SizedBox(height: 16),
                Expanded(child: content),
              ] else
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 260,
                        child: _CategoryRail(
                          categories: categories,
                          selected: selected,
                          onSelect: (i) => setState(() => _selected = i),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: content),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Trilha de categorias (desktop/tablet): cartão com itens selecionáveis.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<_Category> categories;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(NeuTokens.rChip),
                onTap: i == selected ? null : () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: i == selected ? neu.accentTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(NeuTokens.rChip),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        categories[i].icon,
                        size: 20,
                        color: i == selected ? neu.navy : neu.inkMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          categories[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: i == selected ? neu.ink : neu.inkMuted,
                            fontWeight: i == selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chips de categoria (mobile): rolável na horizontal.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<_Category> categories;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: i == selected ? null : () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selected ? neu.navy : neu.surface,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: i == selected ? null : neu.raised(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        categories[i].icon,
                        size: 16,
                        color: i == selected ? neu.onNavy : neu.inkMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        categories[i].title,
                        style: TextStyle(
                          color: i == selected ? neu.onNavy : neu.inkMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
