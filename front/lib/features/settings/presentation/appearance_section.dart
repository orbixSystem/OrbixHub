import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_presets.dart';
import '../../../di.dart';

/// Seção de Aparência na tela de Configurações.
///
/// Exibe:
/// - Grade de swatches de presets de tema ([kThemePresets]).
/// - Controle segmentado de modo claro/escuro/sistema.
/// - Card de pré-visualização usando [ColorScheme] do tema ativo.
///
/// Recebe [company] (mapa de configurações da empresa) para saber qual preset
/// está atualmente selecionado.
///
/// Quando [embedded] é `true`, omite o Card externo (útil quando este widget
/// é incorporado dentro de um painel expansível que já provê o contêiner).
class AppearanceSection extends ConsumerWidget {
  final Map<String, dynamic> company;
  final bool embedded;

  const AppearanceSection({super.key, required this.company, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeControllerProvider);

    // Determina o preset selecionado: 3-tier resolution.
    // 1. themePreset não-vazio → usa diretamente.
    // 2. primaryColor válido (#RRGGBB) → converte para Color e busca preset.
    // 3. fallback → 'tangerina'.
    final String selectedKey = () {
      final preset = company['themePreset'];
      if (preset is String && preset.isNotEmpty) return preset;

      final hex = company['primaryColor'];
      if (hex is String && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
        final value = int.tryParse('FF${hex.substring(1)}', radix: 16);
        if (value != null) {
          final mapped = presetForSeed(Color(value));
          if (mapped != null) return mapped;
        }
      }

      return 'tangerina';
    }();

    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!embedded) ...[
            // Cabeçalho (omitido quando embedded — o painel expansível provê o título)
            Row(
              children: [
                Icon(Icons.palette_outlined,
                    color: scheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Aparência',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // ---- Tema do sistema (presets) --------------------------------
          Text(
            'Tema do sistema',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _SwatchGrid(
            selectedKey: selectedKey,
            onSelect: (key) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .saveCompany({'themePreset': key});
            },
          ),
          const SizedBox(height: 20),

          // ---- Modo (claro / escuro / sistema) -------------------------
          Text(
            'Modo',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          _ThemeModeSelector(
            current: themeMode,
            onChanged: (mode) {
              ref.read(themeControllerProvider.notifier).set(mode);
            },
          ),
        ],
      ),
    );

    if (embedded) return content;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      color: scheme.surfaceContainerLowest,
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Grade de swatches
// ---------------------------------------------------------------------------

class _SwatchGrid extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<String> onSelect;

  const _SwatchGrid({
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final preset in kThemePresets)
          _SwatchItem(
            preset: preset,
            isSelected: preset.key == selectedKey,
            onTap: () => onSelect(preset.key),
          ),
      ],
    );
  }
}

class _SwatchItem extends StatelessWidget {
  final ThemePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _SwatchItem({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: preset.seed,
              border: Border.all(
                color: isSelected ? scheme.primary : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: preset.seed.withAlpha(100),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            preset.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seletor de modo claro/escuro/sistema
// ---------------------------------------------------------------------------

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeSelector({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Claro'),
          icon: Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Escuro'),
          icon: Icon(Icons.dark_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('Sistema'),
          icon: Icon(Icons.brightness_auto_outlined),
        ),
      ],
      selected: {current},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) onChanged(set.first);
      },
    );
  }
}

