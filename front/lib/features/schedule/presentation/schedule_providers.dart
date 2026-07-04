import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/schedule_models.dart';
import '../domain/schedule_repository.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  throw UnimplementedError(
      'scheduleRepositoryProvider must be overridden in di.dart');
});

/// Horários de funcionamento do tenant.
final businessHoursProvider =
    FutureProvider.autoDispose<List<BusinessHours>>((ref) {
  return ref.read(scheduleRepositoryProvider).getBusinessHours();
});

/// Filtros da agenda (data de referência + técnico opcional).
class AgendaQuery {
  const AgendaQuery({required this.date, this.assignedTo});

  final DateTime date; // dia de referência (agenda do dia)
  final String? assignedTo;

  AgendaQuery copyWith({DateTime? date, Object? assignedTo = _sentinel}) =>
      AgendaQuery(
        date: date ?? this.date,
        assignedTo:
            assignedTo == _sentinel ? this.assignedTo : assignedTo as String?,
      );

  static const _sentinel = Object();
}

class AgendaQueryNotifier extends Notifier<AgendaQuery> {
  @override
  AgendaQuery build() => AgendaQuery(date: _today());

  void prevDay() => state = state.copyWith(date: state.date.subtract(const Duration(days: 1)));
  void nextDay() => state = state.copyWith(date: state.date.add(const Duration(days: 1)));
  void setDate(DateTime d) => state = state.copyWith(date: d);
  void setAssignedTo(String? id) => state = state.copyWith(assignedTo: id);

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}

final agendaQueryProvider =
    NotifierProvider<AgendaQueryNotifier, AgendaQuery>(AgendaQueryNotifier.new);

/// Itens agendados para o dia corrente (± filtro de técnico).
final agendaProvider = FutureProvider.autoDispose<AgendaResult>((ref) {
  final q = ref.watch(agendaQueryProvider);
  final from = q.date;
  final to = from.add(const Duration(days: 1));
  return ref.read(scheduleRepositoryProvider).getAgenda(
        from: from,
        to: to,
        assignedTo: q.assignedTo,
      );
});
