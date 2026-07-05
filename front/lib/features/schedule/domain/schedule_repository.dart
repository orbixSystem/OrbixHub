import 'schedule_models.dart';

/// Interface do repositório de agenda. A UI nunca chama dio direto — sempre
/// via esta interface injetada via Riverpod.
abstract class ScheduleRepository {
  /// Retorna os 7 dias do horário de funcionamento do tenant.
  Future<List<BusinessHours>> getBusinessHours();

  /// Atualiza o horário de um dia (0=Dom … 6=Sáb).
  Future<BusinessHours> updateBusinessHours(int day, BusinessHoursPatch patch);

  /// Retorna itens agendados no período [from, to).
  /// [assignedTo] (opcional) filtra por técnico (userId).
  Future<AgendaResult> getAgenda({
    required DateTime from,
    required DateTime to,
    String? assignedTo,
  });

  /// Atribui técnico e/ou horário a um item de OS.
  Future<Map<String, dynamic>> scheduleItem(
    String orderId,
    String itemId,
    ScheduleItemDraft draft,
  );

  /// Remove atribuição e agendamento de um item.
  Future<Map<String, dynamic>> unscheduleItem(String orderId, String itemId);
}
