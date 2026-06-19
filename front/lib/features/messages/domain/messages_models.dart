import 'package:freezed_annotation/freezed_annotation.dart';

part 'messages_models.freezed.dart';
part 'messages_models.g.dart';

/// Uma conversa (thread) no inbox do staff. Genérica — aponta para a entidade de
/// origem só por `ref_type`/`ref_id` (ex.: 'os'/'order' + id), nunca lê a tabela
/// alheia. `staff_unread` é resetado no servidor ao abrir o thread.
@freezed
abstract class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    String? title,
    @JsonKey(name: 'ref_label') String? refLabel,
    @JsonKey(name: 'ref_type') String? refType,
    @JsonKey(name: 'ref_id') String? refId,
    @JsonKey(name: 'staff_unread') @Default(0) int staffUnread,
    @JsonKey(name: 'last_message_at') String? lastMessageAt,
    @JsonKey(name: 'last_message') String? lastMessage,
    @JsonKey(name: 'last_message_sender') String? lastMessageSender,
    @JsonKey(name: 'last_message_read') @Default(false) bool lastMessageRead,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}

/// Uma mensagem dentro de um thread. `sender ∈ 'customer'|'staff'`.
@freezed
abstract class Message with _$Message {
  const factory Message({
    required String id,
    @Default('customer') String sender, // 'customer' | 'staff'
    @JsonKey(name: 'author_name') String? authorName,
    @Default('') String body,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'read_at') String? readAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

/// Thread completo: a conversa + suas mensagens (`GET /messages/conversations/:id`).
@freezed
abstract class ConversationThread with _$ConversationThread {
  const factory ConversationThread({
    required Conversation conversation,
    @Default(<Message>[]) List<Message> messages,
  }) = _ConversationThread;

  /// O backend devolve `{ conversation: {...}, messages: [...] }` (aninhado).
  /// Toleramos também o formato plano `{ ...campos, messages: [...] }`.
  factory ConversationThread.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List?)
            ?.map((e) => Message.fromJson((e as Map).cast<String, dynamic>()))
            .toList() ??
        const <Message>[];
    final nested = json['conversation'];
    final convJson = nested is Map
        ? nested.cast<String, dynamic>()
        : (Map<String, dynamic>.from(json)..remove('messages'));
    return ConversationThread(
      conversation: Conversation.fromJson(convJson),
      messages: messages,
    );
  }
}

/// Página de conversas (`GET /messages/conversations`).
@freezed
abstract class ConversationPage with _$ConversationPage {
  const factory ConversationPage({
    @Default(<Conversation>[]) List<Conversation> items,
  }) = _ConversationPage;

  factory ConversationPage.fromJson(Map<String, dynamic> json) =>
      _$ConversationPageFromJson(json);
}
