import 'notifications_models.dart';

/// Contrato de notificações (escopo JWT, não gated por módulo). Impl real (dio)
/// + fake, trocadas por injeção Riverpod. A UI nunca fala com o dio direto.
abstract interface class NotificationsRepository {
  /// Lista + contagem de não-lidas (`GET /notifications`).
  Future<NotificationsResult> list();

  /// Marca uma notificação como lida (`POST /notifications/:id/read`).
  Future<void> markRead(String id);

  /// Marca todas como lidas (`POST /notifications/read-all`).
  Future<void> markAllRead();
}
