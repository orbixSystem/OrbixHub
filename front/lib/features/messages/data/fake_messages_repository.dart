import '../domain/messages_models.dart';
import '../domain/messages_repository.dart';

/// In-memory [MessagesRepository] for tests/offline. Algumas conversas + um
/// thread; enviar adiciona uma mensagem do staff; abrir zera o `staff_unread`.
class FakeMessagesRepository implements MessagesRepository {
  FakeMessagesRepository({List<Conversation>? conversations}) {
    final seed = conversations ??
        const [
          Conversation(
            id: 'c1',
            title: 'Maria Souza',
            refType: 'os',
            refId: 'os-1',
            staffUnread: 2,
            lastMessage: 'Meu carro já está pronto?',
          ),
          Conversation(
            id: 'c2',
            title: 'João Lima',
            refType: 'os',
            refId: 'os-2',
            lastMessage: 'Pode retirar amanhã às 9h.',
            lastMessageSender: 'staff',
            lastMessageRead: true,
          ),
        ];
    for (final c in seed) {
      _conversations[c.id] = c;
    }
    _threads['c1'] = const [
      Message(
        id: 'm1',
        sender: 'customer',
        authorName: 'Maria Souza',
        body: 'Bom dia! Meu carro já está pronto?',
      ),
      Message(
        id: 'm2',
        sender: 'customer',
        authorName: 'Maria Souza',
        body: 'Preciso muito dele hoje.',
      ),
    ];
    _threads['c2'] = const [
      Message(
        id: 'm3',
        sender: 'customer',
        authorName: 'João Lima',
        body: 'Obrigado pelo atendimento!',
      ),
    ];
  }

  final Map<String, Conversation> _conversations = {};
  final Map<String, List<Message>> _threads = {};
  int _seq = 0;

  @override
  Future<ConversationPage> listConversations({String? q, int page = 1}) async {
    var all = _conversations.values.toList();
    final term = q?.trim().toLowerCase();
    if (term != null && term.isNotEmpty) {
      all = all
          .where((c) =>
              (c.title?.toLowerCase().contains(term) ?? false) ||
              (c.refLabel?.toLowerCase().contains(term) ?? false))
          .toList();
    }
    // Paginação simples em memória — devolve tudo numa página (total = tamanho),
    // de modo que o scroll infinito termina no 1º lote.
    return ConversationPage(items: all, total: all.length, page: page);
  }

  @override
  Future<ConversationThread> getThread(String id, {String? before}) async {
    // Abrir (página inicial) reseta o não-lido (espelha o servidor).
    if (before == null) {
      _conversations[id] = _conversations[id]!.copyWith(staffUnread: 0);
    }
    return ConversationThread(
      conversation: _conversations[id]!,
      messages: _threads[id] ?? const <Message>[],
    );
  }

  @override
  Future<Message> sendMessage(
    String id,
    String body, {
    String? replyToId,
    String? photoId,
    String? photoUrl,
  }) async {
    final msg = Message(
      id: 'staff-${_seq++}',
      sender: 'staff',
      authorName: 'Você',
      body: body,
      replyToId: replyToId,
      photoId: photoId,
      photoUrl: photoUrl,
    );
    _threads[id] = [...?_threads[id], msg];
    _conversations[id] = _conversations[id]!.copyWith(
      lastMessage: body,
      lastMessageSender: 'staff',
      lastMessageRead: false,
      staffUnread: 0,
    );
    return msg;
  }

  @override
  Future<void> markRead(String id) async {
    _conversations[id] = _conversations[id]!.copyWith(staffUnread: 0);
  }
}
