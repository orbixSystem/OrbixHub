import 'package:freezed_annotation/freezed_annotation.dart';

part 'notifications_models.freezed.dart';
part 'notifications_models.g.dart';

/// Uma notificação do usuário (`GET /notifications`). Genérica — aponta para a
/// origem por `ref_type`/`ref_id` (ex.: 'message' + conversationId). `read_at`
/// nulo = não lida.
@freezed
abstract class AppNotification with _$AppNotification {
  const AppNotification._();

  const factory AppNotification({
    required String id,
    @Default('') String type,
    @Default('') String title,
    String? body,
    @JsonKey(name: 'ref_type') String? refType,
    @JsonKey(name: 'ref_id') String? refId,
    @JsonKey(name: 'read_at') String? readAt,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  bool get isRead => readAt != null;
}

/// Resultado de `GET /notifications`: itens + contagem de não-lidas.
@freezed
abstract class NotificationsResult with _$NotificationsResult {
  const factory NotificationsResult({
    @Default(<AppNotification>[]) List<AppNotification> items,
    @Default(0) int unread,
  }) = _NotificationsResult;

  factory NotificationsResult.fromJson(Map<String, dynamic> json) =>
      _$NotificationsResultFromJson(json);
}
