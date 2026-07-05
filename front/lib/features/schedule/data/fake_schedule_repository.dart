import '../domain/schedule_models.dart';
import '../domain/schedule_repository.dart';

/// Implementação fake para testes e desenvolvimento offline.
class FakeScheduleRepository implements ScheduleRepository {
  final _hours = List.generate(7, (i) {
    final labels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return BusinessHours(
      id: 'fake-day-$i',
      dayOfWeek: i,
      dayLabel: labels[i],
      isOpen: i != 0 && i != 6,
      openTime: '08:00',
      closeTime: i == 6 ? '12:00' : '18:00',
    );
  });

  @override
  Future<List<BusinessHours>> getBusinessHours() async => List.from(_hours);

  @override
  Future<BusinessHours> updateBusinessHours(
      int day, BusinessHoursPatch patch) async {
    final updated = BusinessHours(
      id: _hours[day].id,
      dayOfWeek: day,
      dayLabel: _hours[day].dayLabel,
      isOpen: patch.isOpen,
      openTime: patch.openTime,
      closeTime: patch.closeTime,
    );
    _hours[day] = updated;
    return updated;
  }

  @override
  Future<AgendaResult> getAgenda({
    required DateTime from,
    required DateTime to,
    String? assignedTo,
  }) async =>
      const AgendaResult(items: []);

  @override
  Future<Map<String, dynamic>> scheduleItem(
    String orderId,
    String itemId,
    ScheduleItemDraft draft,
  ) async =>
      {'id': itemId, ...draft.toJson()};

  @override
  Future<Map<String, dynamic>> unscheduleItem(
          String orderId, String itemId) async =>
      {'id': itemId, 'unscheduled': true};
}
