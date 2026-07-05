import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_presets.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';

/// Seção de Aparência na tela de Configurações.
///
/// Exibe:
/// - Grade de cartões selecionáveis de presets de tema ([kThemePresets]).
/// - Seletor de modo claro/escuro/sistema.
///
/// Recebe [company] (mapa de configurações da empresa) para saber qual preset
/// está atualmente selecionado.
///
/// Quando [embedded] é `true`, omite o cartão externo (útil quando este widget
/// é incorporado dentro de um painel expansível que já provê o contêiner).
class AppearanceSection extends ConsumerWidget {
  final Map<String, dynamic> company;
  final bool embedded;

  const AppearanceSection({super.key, required this.company, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          // Cabeçalho (omitido quando embedded — o painel expansível provê o título)
          Row(
            children: [
              NeuIconChip.glyph(
                context,
                icon: Icons.palette_outlined,
                index: 0,
                size: 40,
              ),
              const SizedBox(width: 14),
              Text(
                'Aparência',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: neu.ink, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // ---- Tema do sistema (presets) --------------------------------
        Text(
          'Tema do sistema',
          style: TextStyle(
            color: neu.inkMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        _SwatchGrid(
          selectedKey: selectedKey,
          onSelect: (key) {
            ref
                .read(settingsControllerProvider.notifier)
                .saveAppearance({'themePreset': key});
          },
        ),
        const SizedBox(height: 24),

        // ---- Modo (claro / escuro / sistema) -------------------------
        Text(
          'Modo',
          style: TextStyle(
            color: neu.inkMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        _ThemeModeSelector(
          current: themeMode,
          onChanged: (mode) {
            ref.read(themeControllerProvider.notifier).set(mode);
          },
        ),
      ],
    );

    if (embedded) return content;

    return NeuCard(
      padding: const EdgeInsets.all(20),
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
      spacing: 14,
      runSpacing: 14,
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
    final neu = context.neu;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: NeuSurface(
          elevation: isSelected ? NeuElevation.pressed : NeuElevation.raised,
          radius: NeuTokens.rCard,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: isSelected ? Border.all(color: neu.navy, width: 2) : null,
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
                  boxShadow: [
                    BoxShadow(
                      color: preset.seed.withValues(alpha: .40),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                preset.label,
                style: TextStyle(
                  color: isSelected ? neu.navy : neu.inkMuted,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
    return Row(
      children: [
        _ModeOption(
          icon: Icons.light_mode_outlined,
          label: 'Claro',
          selected: current == ThemeMode.light,
          onTap: () => onChanged(ThemeMode.light),
        ),
        const SizedBox(width: 12),
        _ModeOption(
          icon: Icons.dark_mode_outlined,
          label: 'Escuro',
          selected: current == ThemeMode.dark,
          onTap: () => onChanged(ThemeMode.dark),
        ),
        const SizedBox(width: 12),
        _ModeOption(
          icon: Icons.brightness_auto_outlined,
          label: 'Sistema',
          selected: current == ThemeMode.system,
          onTap: () => onChanged(ThemeMode.system),
        ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final fg = selected ? neu.navy : neu.inkMuted;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: NeuSurface(
            elevation: selected ? NeuElevation.pressed : NeuElevation.raised,
            radius: NeuTokens.rField,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: selected ? Border.all(color: neu.navy, width: 2) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
