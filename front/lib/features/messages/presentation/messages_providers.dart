import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/messages_models.dart';
import '../domain/messages_repository.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  throw UnimplementedError(
      'messagesRepositoryProvider must be overridden in di.dart');
});

/// Termo de busca corrente do inbox (título / número da OS).
class ConversationQueryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setQuery(String value) =>
      state = value.trim().isEmpty ? null : value.trim();
}

final conversationQueryProvider =
    NotifierProvider<ConversationQueryNotifier, String?>(
        ConversationQueryNotifier.new);

/// Estado da lista paginada de conversas: itens acumulados + se há mais lotes.
class ConversationListState {
  const ConversationListState({
    required this.items,
    required this.total,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<Conversation> items;
  final int total;
  final bool hasMore;
  final bool loadingMore;

  ConversationListState copyWith({
    List<Conversation>? items,
    int? total,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      ConversationListState(
        items: items ?? this.items,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Lista de conversas paginada (scroll infinito). `build` carrega a 1ª página e
/// reage à busca (mudar o termo reinicia da página 1); [loadMore] anexa o próximo
/// lote ao chegar perto do fim. autoDispose: re-busca ao reentrar na tela.
class ConversationListNotifier extends AsyncNotifier<ConversationListState> {
  int _page = 1;
  String? _query;

  @override
  Future<ConversationListState> build() async {
    _query = ref.watch(conversationQueryProvider);
    _page = 1;
    final page = await _fetch(1);
    return ConversationListState(
      items: page.items,
      total: page.total,
      hasMore: page.items.length < page.total,
    );
  }

  Future<ConversationPage> _fetch(int page) =>
      ref.read(messagesRepositoryProvider).listConversations(
            q: _query,
            page: page,
          );

  /// Carrega o próximo lote e anexa. No-op se já carregando, sem mais páginas, ou
  /// ainda sem o 1º lote. Em erro, mantém os itens e para o spinner.
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(_page + 1);
      _page += 1;
      final merged = [...current.items, ...next.items];
      state = AsyncData(ConversationListState(
        items: merged,
        total: next.total,
        hasMore: merged.length < next.total && next.items.isNotEmpty,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

/// Lista de conversas do inbox (paginada). autoDispose + refresh ao reentrar.
/// O listener de tempo real invalida este provider a cada mensagem nova, o que
/// recarrega a página 1 (badges/prévia atualizam na hora).
final conversationsProvider = AsyncNotifierProvider.autoDispose<
    ConversationListNotifier, ConversationListState>(
  ConversationListNotifier.new,
);

/// Soma de não-lidos do staff nas conversas carregadas — alimenta o badge do menu.
/// 0 quando ainda carregando/erro (badge some).
final unreadConversationsCountProvider = Provider.autoDispose<int>((ref) {
  final async = ref.watch(conversationsProvider);
  return async.maybeWhen(
    data: (state) =>
        state.items.fold<int>(0, (sum, c) => sum + c.staffUnread),
    orElse: () => 0,
  );
});

/// Thread de uma conversa (por id).
final threadProvider =
    FutureProvider.autoDispose.family<ConversationThread, String>((ref, id) {
  return ref.read(messagesRepositoryProvider).getThread(id);
});
