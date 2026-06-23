import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../period_controller.dart';

/// Abre o seletor de intervalo no CALENDÁRIO (toca início e fim direto nos meses),
/// em pt-BR — o modo digitável (`input`) ficava espremido e ilegível num diálogo
/// minúsculo. O botão de teclado no cabeçalho ainda permite digitar as datas.
/// Usado pelo seletor de período do dashboard e por qualquer tela que precise de
/// um range personalizado. Retorna null se o usuário cancelar.
Future<DateTimeRange?> pickMetricsRange(
  BuildContext context, {
  DateTime? from,
  DateTime? to,
}) {
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    locale: const Locale('pt', 'BR'),
    initialEntryMode: DatePickerEntryMode.calendar,
    helpText: 'Selecione o período',
    saveText: 'Aplicar',
    initialDateRange: from != null && to != null
        ? DateTimeRange(start: from, end: to)
        : null,
    builder: (context, child) {
      // Limita a largura do diálogo de calendário (cheia, ocuparia a janela toda
      // no web/desktop) e o centraliza, dando o visual de painel de apps grandes.
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: child,
        ),
      );
    },
  );
}

/// Seletor de período no topo do dashboard: Hoje · 7 dias · 30 dias · Mês atual ·
/// Personalizado (abre date range). Atualiza o `PeriodController`; os widgets de
/// OS e Clientes reagem. Default 30 dias.
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(periodControllerProvider);
    final controller = ref.read(periodControllerProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in PeriodPreset.values)
          _PeriodChip(
            label: preset == PeriodPreset.custom
                ? _customLabel(state)
                : preset.label,
            selected: state.preset == preset,
            onTap: () async {
              if (preset == PeriodPreset.custom) {
                final picked = await pickMetricsRange(
                  context,
                  from: state.customFrom,
                  to: state.customTo,
                );
                if (picked != null) {
                  controller.setCustomRange(picked.start, picked.end);
                }
              } else {
                controller.selectPreset(preset);
              }
            },
          ),
      ],
    );
  }

  String _customLabel(PeriodState state) {
    if (state.preset == PeriodPreset.custom &&
        state.customFrom != null &&
        state.customTo != null) {
      String d(DateTime x) =>
          '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}';
      return '${d(state.customFrom!)} – ${d(state.customTo!)}';
    }
    return 'Personalizado';
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? AppColors.brandTint : scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.brand : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.brandDeep : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
