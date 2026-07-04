import 'package:freezed_annotation/freezed_annotation.dart';

part 'schedule_models.freezed.dart';
part 'schedule_models.g.dart';

/// Horário de funcionamento de um dia da semana do tenant.
/// `dayOfWeek`: 0=Dom, 1=Seg … 6=Sáb.
@freezed
abstract class BusinessHours with _$BusinessHours {
  const factory BusinessHours({
    required String id,
    @JsonKey(name: 'dayOfWeek') required int dayOfWeek,
    @JsonKey(name: 'dayLabel') required String dayLabel,
    @JsonKey(name: 'isOpen') @Default(true) bool isOpen,
    @JsonKey(name: 'openTime') @Default('08:00') String openTime,
    @JsonKey(name: 'closeTime') @Default('18:00') String closeTime,
  }) = _BusinessHours;

  factory BusinessHours.fromJson(Map<String, dynamic> json) =>
      _$BusinessHoursFromJson(json);
}

/// Payload de atualização de um dia do horário de funcionamento.
class BusinessHoursPatch {
  const BusinessHoursPatch({
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  final bool isOpen;
  final String openTime;
  final String closeTime;

  Map<String, dynamic> toJson() => {
        'isOpen': isOpen,
        'openTime': openTime,
        'closeTime': closeTime,
      };
}

/// Referência resumida da OS para exibição na agenda.
@freezed
abstract class AgendaOrderRef with _$AgendaOrderRef {
  const factory AgendaOrderRef({
    required String id,
    required String number,
    @Default('aberta') String status,
    @JsonKey(name: 'customer_name') String? customerName,
    @JsonKey(name: 'subject_label') String? subjectLabel,
  }) = _AgendaOrderRef;

  factory AgendaOrderRef.fromJson(Map<String, dynamic> json) =>
      _$AgendaOrderRefFromJson(json);
}

/// Item agendado (retornado pela agenda). Inclui dados básicos do item +
/// referência à OS e ao técnico responsável.
@freezed
abstract class AgendaItem with _$AgendaItem {
  const factory AgendaItem({
    required String id,
    required String name,
    @Default('service') String kind,
    @JsonKey(name: 'assigned_to') String? assignedTo,
    @JsonKey(name: 'scheduled_start') String? scheduledStart,
    @JsonKey(name: 'scheduled_end') String? scheduledEnd,
    @JsonKey(name: 'estimated_duration') int? estimatedDuration,
    @JsonKey(name: 'order_id') required String orderId,
    required AgendaOrderRef order,
  }) = _AgendaItem;

  factory AgendaItem.fromJson(Map<String, dynamic> json) =>
      _$AgendaItemFromJson(json);
}

/// Resposta de GET /schedule/agenda.
@freezed
abstract class AgendaResult with _$AgendaResult {
  const factory AgendaResult({
    @Default(<AgendaItem>[]) List<AgendaItem> items,
  }) = _AgendaResult;

  factory AgendaResult.fromJson(Map<String, dynamic> json) =>
      _$AgendaResultFromJson(json);
}

/// Draft para agendar/reatribuir um item de OS.
class ScheduleItemDraft {
  const ScheduleItemDraft({
    this.assignedTo,
    this.scheduledStart,
    this.estimatedDuration,
  });

  final String? assignedTo;
  final String? scheduledStart; // ISO-8601
  final int? estimatedDuration; // minutos, múltiplos de 30

  Map<String, dynamic> toJson() => {
        if (assignedTo != null) 'assignedTo': assignedTo,
        if (scheduledStart != null) 'scheduledStart': scheduledStart,
        if (estimatedDuration != null) 'estimatedDuration': estimatedDuration,
      };
}
