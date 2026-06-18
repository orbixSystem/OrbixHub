import 'messages_models.dart';

/// Contrato do módulo Mensagens (lado staff). O backend é a verdade (RLS +
/// permissões + gating); o cliente só reflete para UX. Impl real (dio) + fake,
/// trocadas por injeção Riverpod. A UI nunca fala com o dio direto.
abstract interface class MessagesRepository {
  /// Conversas do inbox, mais recentes primeiro (`GET /messages/conversations`).
  Future<List<Conversation>> listConversations();

  /// Thread completo; abrir reseta `staff_unread` no servidor
  /// (`GET /messages/conversations/:id`).
  Future<ConversationThread> getThread(String id);

  /// Posta uma resposta do staff (`POST /messages/conversations/:id/messages`).
  Future<Message> sendMessage(String id, String body);

  /// Marca a conversa como lida (idempotente; o GET do thread já reseta).
  Future<void> markRead(String id);
}
