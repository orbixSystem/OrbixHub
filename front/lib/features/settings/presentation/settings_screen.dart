import 'package:flutter/material.dart';

import '../../../core/config/feature_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/widgets/offline_notices.dart';
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
    required this.subtitle,
    required this.icon,
    required this.glyphIndex,
    required this.builder,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final int glyphIndex;
  final WidgetBuilder builder;
}

/// Tela de Configurações — corpo apenas (o shell é dono da moldura).
///
/// Layout adaptativo:
/// - **Desktop/tablet:** master-detail — nav-rail com ícone + título + subtítulo
///   à esquerda e o conteúdo da categoria (com cabeçalho de seção) à direita.
/// - **Mobile:** drill-down estilo Ajustes — lista de categorias em cartões
///   grandes; tocar abre a seção em tela cheia com botão "voltar".
///
/// Aparência é pública; Empresa e módulos exigem `settings.manage`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Categoria selecionada no desktop (master-detail).
  int _selected = 0;

  /// Categoria aberta no mobile (drill-down). `null` = mostrando a lista.
  int? _mobileOpen;

  /// Salva um campo de seção de módulo. Erro do servidor (ex.: valor recusado
  /// pelo módulo dono) aparece na tela — sem isto o toggle voltaria sozinho sem
  /// explicação.
  Future<void> _salvarSecao(String key, Map<String, dynamic> patch) async {
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .saveSection(key, patch);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final neu = context.neu;
    final canManage =
        session.meOrNull?.hasPermission('settings.manage') ?? false;

    final settingsAsync = ref.watch(settingsControllerProvider);

    // Offline: empresa e módulos são gravados no SERVIDOR (sem outbox) — a tela
    // explica em vez de mostrar formulários que não salvam. Mas a APARÊNCIA
    // (tema claro/escuro) é 100% LOCAL e continua utilizável.
    if (ref.watch(isOfflineProvider)) {
      final company =
          settingsAsync.asData?.value.company ?? const <String, dynamic>{};
      return _offlineLayout(company, canManage);
    }

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
              Text(
                'Erro ao carregar configurações',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: neu.inkMuted),
              ),
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
        final moduleSections = bundle.sections
            .where((s) => s.moduleKey != null)
            // NF desligada no front (kInvoiceEnabled=false): esconde a seção
            // de config fiscal do módulo `invoice`.
            .where((s) => kInvoiceEnabled || s.moduleKey != 'invoice')
            .toList();

        // Paleta de glyph por categoria (cores do DS, ciclo p/ os módulos).
        const glyphs = [0, 1, 3, 5, 2, 4];
        var gi = 0;
        int nextGlyph() => glyphs[gi++ % glyphs.length];

        final categories = <_Category>[
          if (canManage)
            _Category(
              title: 'Empresa & Identidade visual',
              subtitle: 'Logo, dados cadastrais, endereço e fiscal',
              icon: Icons.storefront_outlined,
              glyphIndex: nextGlyph(),
              builder: (_) => CompanyForm(
                bundle: bundle,
                company: bundle.company,
                embedded: true,
              ),
            ),
          _Category(
            title: 'Aparência',
            subtitle: 'Tema claro/escuro e preferências visuais',
            icon: Icons.palette_outlined,
            glyphIndex: nextGlyph(),
            builder: (_) =>
                AppearanceSection(company: bundle.company, embedded: true),
          ),
          if (canManage)
            for (final section in moduleSections)
              _Category(
                title: section.title,
                subtitle: 'Preferências do módulo',
                icon: Icons.tune_rounded,
                glyphIndex: nextGlyph(),
                builder: (_) => DynamicSection(
                  section: section,
                  values: section.values,
                  hideTitle: true,
                  onToggle: (campo, valor) =>
                      _salvarSecao(section.key, {campo: valor}),
                ),
              ),
        ];

        if (categories.isEmpty) {
          return const Center(child: SizedBox.shrink());
        }

        return context.isMobile
            ? _mobileLayout(categories, canManage)
            : _desktopLayout(categories, canManage);
      },
    );
  }

  // ===================== Offline =====================

  /// Layout offline: a seção de Aparência (tema local) continua utilizável; o
  /// resto (empresa + módulos, gravados no servidor) vira "Requer conexão".
  Widget _offlineLayout(Map<String, dynamic> company, bool canManage) {
    final isMobile = context.isMobile;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: ListView(
        children: [
          _PageHeader(canManage: canManage),
          const SizedBox(height: 22),
          AppearanceSection(company: company),
          const SizedBox(height: 16),
          const SizedBox(
            height: 300,
            child: RequiresConnectionView(
              message:
                  'As configurações da empresa e dos módulos são salvas no '
                  'servidor. Conecte-se à internet para vê-las e alterá-las — '
                  'o tema acima continua funcionando offline.',
            ),
          ),
        ],
      ),
    );
  }

  // ===================== Desktop / tablet =====================

  Widget _desktopLayout(List<_Category> categories, bool canManage) {
    final selected = _selected.clamp(0, categories.length - 1);
    final cat = categories[selected];
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(canManage: canManage),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              // stretch: rail e conteúdo preenchem a altura toda (o rail não
              // fica "cortado" no meio da tela).
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 300,
                  // MESMO nome de alvo nos dois layouts: só um está montado por
                  // vez, então a GlobalKey nunca aparece duas vezes na árvore —
                  // e o tutorial destaca "as seções" em desktop e no celular.
                  child: CoachTarget(
                    'config.secoes',
                    child: _NavRail(
                      categories: categories,
                      selected: selected,
                      onSelect: (i) => setState(() => _selected = i),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: NeuCard(
                    padding: const EdgeInsets.all(28),
                    child: SingleChildScrollView(
                      key: ValueKey(selected),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionHeader(category: cat),
                              const SizedBox(height: 22),
                              cat.builder(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== Mobile (drill-down) =====================

  Widget _mobileLayout(List<_Category> categories, bool canManage) {
    final open = _mobileOpen;
    if (open != null && open >= 0 && open < categories.length) {
      final cat = categories[open];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho da seção com "voltar".
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
            child: Row(
              children: [
                NeuIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Voltar',
                  size: 42,
                  onPressed: () => setState(() => _mobileOpen = null),
                ),
                const SizedBox(width: 12),
                NeuIconChip.glyph(
                  context,
                  icon: cat.icon,
                  index: cat.glyphIndex,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cat.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.neu.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: NeuCard(
                padding: const EdgeInsets.all(18),
                child: cat.builder(context),
              ),
            ),
          ),
        ],
      );
    }

    // Lista de categorias (nível raiz).
    // Mesmo nome do rail do desktop — ver o comentário lá.
    return CoachTarget(
      'config.secoes',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _PageHeader(canManage: canManage),
          const SizedBox(height: 18),
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryTile(
                category: categories[i],
                selected: false,
                showChevron: true,
                onTap: () => setState(() => _mobileOpen = i),
              ),
            ),
        ],
      ),
    );
  }
}

/// Título + subtítulo do topo da tela.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.canManage});
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configurações',
          style: TextStyle(
            color: neu.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          canManage
              ? 'Dados da empresa, identidade visual e preferências dos módulos.'
              : 'Personalize a aparência da sua interface.',
          style: TextStyle(color: neu.inkMuted, fontSize: 14.5, height: 1.35),
        ),
      ],
    );
  }
}

/// Cabeçalho da seção de conteúdo (glyph + título + subtítulo).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.category});
  final _Category category;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      children: [
        NeuIconChip.glyph(
          context,
          icon: category.icon,
          index: category.glyphIndex,
          size: 46,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.title,
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                category.subtitle,
                style: TextStyle(color: neu.inkMuted, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nav-rail do desktop: cartão com as categorias selecionáveis.
class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<_Category> categories;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _CategoryTile(
                category: categories[i],
                selected: i == selected,
                showChevron: false,
                onTap: i == selected ? null : () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// Linha de categoria — usada no nav-rail (desktop) e na lista (mobile).
/// Ícone colorido + título + subtítulo, com realce quando [selected] e chevron
/// opcional (mobile). [onTap] nulo = item já ativo (desktop).
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.showChevron,
    required this.onTap,
  });

  final _Category category;
  final bool selected;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? neu.accentTint : Colors.transparent,
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
      ),
      child: Row(
        children: [
          NeuIconChip.glyph(
            context,
            icon: category.icon,
            index: category.glyphIndex,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? neu.navy : neu.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neu.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: neu.inkFaint, size: 22),
          ],
        ],
      ),
    );

    // NeuCard (relevo) no mobile p/ os itens da lista "flutuarem"; no desktop o
    // realce é só o fundo tint dentro do rail.
    final wrapped = showChevron
        ? NeuCard(padding: EdgeInsets.zero, child: tile)
        : tile;

    if (onTap == null) return wrapped;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuTokens.rCard),
      child: wrapped,
    );
  }
}
