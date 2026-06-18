import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/messages_models.dart';
import '../domain/messages_repository.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  throw UnimplementedError(
      'messagesRepositoryProvider must be overridden in di.dart');
});

/// Lista de conversas do inbox. autoDispose + refresh ao reentrar.
final conversationsProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) {
  return ref.read(messagesRepositoryProvider).listConversations();
});

/// Soma de não-lidos do staff em todas as conversas — alimenta o badge do menu.
/// 0 quando ainda carregando/erro (badge some).
final unreadConversationsCountProvider = Provider.autoDispose<int>((ref) {
  final async = ref.watch(conversationsProvider);
  return async.maybeWhen(
    data: (items) =>
        items.fold<int>(0, (sum, c) => sum + c.staffUnread),
    orElse: () => 0,
  );
});

/// Thread de uma conversa (por id).
final threadProvider =
    FutureProvider.autoDispose.family<ConversationThread, String>((ref, id) {
  return ref.read(messagesRepositoryProvider).getThread(id);
});
