import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dashboard_models.dart';

/// Opção do seletor de período (chave estável + rótulo PT-BR).
enum PeriodPreset {
  today('today', 'Hoje'),
  last7('last7', '7 dias'),
  last30('last30', '30 dias'),
  thisMonth('thisMonth', 'Mês atual'),
  custom('custom', 'Personalizado');

  const PeriodPreset(this.key, this.label);
  final String key;
  final String label;
}

/// Estado do período compartilhado pelos widgets de OS e Clientes. Estoque é
/// point-in-time e ignora isto. Default: 30 dias.
class PeriodState {
  const PeriodState({required this.preset, this.customFrom, this.customTo});

  final PeriodPreset preset;
  final DateTime? customFrom;
  final DateTime? customTo;

  /// Resolve o preset em uma janela `[from, to]` concreta (hora local → o repo
  /// converte para UTC ISO). `to` é sempre "agora" exceto no range personalizado.
  MetricsRange resolve([DateTime? now]) {
    final ref = now ?? DateTime.now();
    final endOfDay =
        DateTime(ref.year, ref.month, ref.day, 23, 59, 59, 999);
    switch (preset) {
      case PeriodPreset.today:
        return MetricsRange(
          from: DateTime(ref.year, ref.month, ref.day),
          to: endOfDay,
        );
      case PeriodPreset.last7:
        return MetricsRange(
          from: DateTime(ref.year, ref.month, ref.day)
              .subtract(const Duration(days: 6)),
          to: endOfDay,
        );
      case PeriodPreset.last30:
        return MetricsRange(
          from: DateTime(ref.year, ref.month, ref.day)
              .subtract(const Duration(days: 29)),
          to: endOfDay,
        );
      case PeriodPreset.thisMonth:
        return MetricsRange(
          from: DateTime(ref.year, ref.month, 1),
          to: endOfDay,
        );
      case PeriodPreset.custom:
        final f = customFrom ??
            DateTime(ref.year, ref.month, ref.day)
                .subtract(const Duration(days: 29));
        final t = customTo ?? ref;
        return MetricsRange(
          from: DateTime(f.year, f.month, f.day),
          to: DateTime(t.year, t.month, t.day, 23, 59, 59, 999),
        );
    }
  }
}

/// Notifier do período selecionado. Default 30 dias.
class PeriodController extends Notifier<PeriodState> {
  @override
  PeriodState build() => const PeriodState(preset: PeriodPreset.last30);

  void selectPreset(PeriodPreset preset) {
    if (preset == PeriodPreset.custom) {
      state = PeriodState(
        preset: preset,
        customFrom: state.customFrom,
        customTo: state.customTo,
      );
    } else {
      state = PeriodState(preset: preset);
    }
  }

  void setCustomRange(DateTime from, DateTime to) {
    state = PeriodState(
      preset: PeriodPreset.custom,
      customFrom: from,
      customTo: to,
    );
  }
}

final periodControllerProvider =
    NotifierProvider<PeriodController, PeriodState>(PeriodController.new);

/// Janela resolvida a partir do período selecionado (o que os providers leem).
final metricsRangeProvider = Provider<MetricsRange>((ref) {
  return ref.watch(periodControllerProvider).resolve();
});
