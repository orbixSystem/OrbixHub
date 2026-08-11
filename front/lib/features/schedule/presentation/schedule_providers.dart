import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../os/domain/os_models.dart';
import '../../os/presentation/os_providers.dart';
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

/// Chave de mês (ano + mês) para o provider de pontos do calendário.
class MonthKey {
  const MonthKey({required this.year, required this.month});

  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// Quantas OS ocupam cada dia do mês (`dia → contagem`).
///
/// Conta a JANELA inteira, não só o dia de início: um carro que entra dia 10 e
/// sai dia 15 está na oficina nos seis dias, e antes marcava só o dia 10 — o
/// calendário mostrava um mês quase vazio enquanto a oficina estava cheia.
///
/// Devolve contagem (não um conjunto) porque a grade passou a mostrar QUANTAS
/// OS há no dia: um pontinho dizia apenas "tem alguma coisa", que é o mesmo
/// para um dia tranquilo e para um dia lotado — inútil justamente quando mais
/// importa decidir onde encaixar o próximo serviço.
final monthScheduledDaysProvider =
    FutureProvider.autoDispose.family<Map<int, int>, MonthKey>((ref, key) async {
  final from = DateTime(key.year, key.month, 1);
  final to = DateTime(key.year, key.month + 1, 1);
  final result = await ref.read(scheduleRepositoryProvider).getAgenda(
        from: from,
        to: to,
      );
  final porDia = <int, int>{};
  for (final item in result.items) {
    for (final dia in diasOcupadosNoMes(item, year: key.year, month: key.month)) {
      porDia[dia] = (porDia[dia] ?? 0) + 1;
    }
  }
  return porDia;
});

/// Dias DO MÊS pedido que a janela de [item] ocupa.
///
/// Recorta ao mês para não estourar em janelas que atravessam a virada (uma OS
/// de 28/07 a 03/08 ocupa 1–3 em agosto). Sem fim definido, ocupa só o dia do
/// início. Exposto para teste — é regra de calendário, não desenho.
Iterable<int> diasOcupadosNoMes(
  AgendaItem item, {
  required int year,
  required int month,
}) sync* {
  final inicio = DateTime.tryParse(item.scheduledStart ?? '')?.toLocal();
  if (inicio == null) return;
  final fim = DateTime.tryParse(item.scheduledEnd ?? '')?.toLocal() ?? inicio;
  // Dia civil: a hora não importa para ocupar a casa do calendário.
  var d = DateTime(inicio.year, inicio.month, inicio.day);
  final ultimo = DateTime(fim.year, fim.month, fim.day);
  // Janela invertida (fim antes do início) é dado inconsistente: trata como
  // ponto, em vez de girar para sempre.
  if (ultimo.isBefore(d)) {
    if (d.year == year && d.month == month) yield d.day;
    return;
  }
  while (!d.isAfter(ultimo)) {
    if (d.year == year && d.month == month) yield d.day;
    d = d.add(const Duration(days: 1));
  }
}

/// Responsáveis para o filtro da agenda. Vem do módulo OS (dono da equipe da
/// oficina) — a agenda aponta, não invade.
final agendaMembersProvider =
    FutureProvider.autoDispose<List<MemberOption>>((ref) async {
  try {
    return await ref.read(osRepositoryProvider).listMembers();
  } on Object {
    // Sem a lista o filtro simplesmente não aparece — não derruba a agenda.
    return const <MemberOption>[];
  }
});
