import '../../../core/offline/local_first.dart';
import '../domain/messages_models.dart';
import '../domain/messages_repository.dart';

/// [MessagesRepository] offline-first (B8) — decorator sobre a impl real (dio).
/// Mesmo molde dos demais LocalFirst; ver [LocalFirstBase] para o contrato.
///
/// Entidades espelhadas: `conversation` (lista do inbox) e `message` (thread). As
/// duas são SÓ-LEITURA offline — o histórico é replicado no SQLite pelo pull do
/// SyncEngine e reconstruído aqui.
///
/// Offline lançam "Requer conexão" (chat é tempo real; não há op de sync p/
/// enfileirar): `sendMessage`, `markRead`.
class LocalFirstMessagesRepository extends LocalFirstBase
    implements MessagesRepository {
  LocalFirstMessagesRepository({
    required this.inner,
    required super.db,
    required super.clock,
    required super.isOnline,
    required super.currentUserId,
    super.onWrite,
  });

  final MessagesRepository inner;

  static const _pageSize = 30;

  /// Chave (extra ao modelo [Message]) que o pull grava na linha de `message`
  /// para amarrá-la à conversa — é como filtramos o thread offline. O
  /// `Message.fromJson` a ignora.
  static const _conversationIdKey = 'conversation_id';

  // ========================= conversas (inbox) ==========================

  @override
  Future<ConversationPage> listConversations({String? q, int page = 1}) async {
    if (isOnline()) {
      final res = await inner.listConversations(q: q, page: page);
      await mirrorRows('conversation', [for (final c in res.items) c.toJson()]);
      return res;
    }
    final all = await rows('conversation');
    final filtered = all.where((row) => _matchesConversation(row, q)).toList()
      ..sort((a, b) => _lastAt(b).compareTo(_lastAt(a)));
    return ConversationPage(
      items: [
        for (final row in pageOf(filtered, page, _pageSize))
          Conversation.fromJson(row),
      ],
      total: filtered.length,
      page: page,
      pageSize: _pageSize,
    );
  }

  bool _matchesConversation(Map<String, dynamic> row, String? q) {
    if (q == null || q.isEmpty) return true;
    return matches(row['title'] as String?, q) ||
        matches(row['ref_label'] as String?, q);
  }

  String _lastAt(Map<String, dynamic> row) =>
      (row['last_message_at'] ?? '') as String;

  // ============================== thread ================================

  @override
  Future<ConversationThread> getThread(String id, {String? before}) async {
    if (isOnline()) {
      final thread = await inner.getThread(id, before: before);
      await mirrorRows('conversation', [thread.conversation.toJson()]);
      // Amarra cada mensagem à conversa para o filtro offline (o pull grava a
      // mesma chave). A linha viaja crua — `Message.fromJson` ignora o extra.
      await mirrorRows('message', [
        for (final m in thread.messages)
          {...m.toJson(), _conversationIdKey: id},
      ]);
      return thread;
    }

    final convRow = await rowById('conversation', id);
    final conversation =
        convRow != null ? Conversation.fromJson(convRow) : Conversation(id: id);

    // Offline devolvemos TODAS as mensagens locais de uma vez (sem cursor). Uma
    // página anterior (`before`) não existe localmente: nada a acrescentar.
    if (before != null) {
      return ConversationThread(conversation: conversation, messages: const []);
    }

    final all = await rows('message');
    final messages = [
      for (final row in all)
        if (row[_conversationIdKey] == id) Message.fromJson(row),
    ]..sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));

    return ConversationThread(
      conversation: conversation,
      messages: messages,
    );
  }

  // ===================== ações online-only ==============================

  @override
  Future<Message> sendMessage(
    String id,
    String body, {
    String? replyToId,
    String? photoId,
    String? photoUrl,
  }) async {
    if (!isOnline()) requiresConnection('enviar uma mensagem');
    return inner.sendMessage(
      id,
      body,
      replyToId: replyToId,
      photoId: photoId,
      photoUrl: photoUrl,
    );
  }

  @override
  Future<void> markRead(String id) async {
    if (!isOnline()) requiresConnection('marcar a conversa como lida');
    return inner.markRead(id);
  }
}
