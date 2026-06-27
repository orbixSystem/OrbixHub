import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/messages_models.dart';
import '../domain/messages_repository.dart';

/// Real [MessagesRepository] backed by dio.
class MessagesRepositoryImpl implements MessagesRepository {
  MessagesRepositoryImpl(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Map<String, dynamic> _asMap(Object? data) =>
      (data as Map).cast<String, dynamic>();

  @override
  Future<ConversationPage> listConversations({String? q, int page = 1}) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/messages/conversations',
          queryParameters: {
            if (q != null && q.isNotEmpty) 'q': q,
            'page': page,
          },
        );
        final data = res.data;
        // O backend devolve `{ items: [...], total, page, pageSize }`. Toleramos
        // também um array cru `[ {...}, ... ]` por robustez (formato antigo).
        if (data is List) {
          final items = data
              .map(
                  (e) => Conversation.fromJson((e as Map).cast<String, dynamic>()))
              .toList();
          return ConversationPage(
            items: items,
            total: items.length,
            page: page,
          );
        }
        return ConversationPage.fromJson(_asMap(data));
      });

  @override
  Future<ConversationThread> getThread(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/messages/conversations/$id');
        return ConversationThread.fromJson(_asMap(res.data));
      });

  @override
  Future<Message> sendMessage(String id, String body) => _guard(() async {
        final res = await _dio.post<Object?>(
          '/messages/conversations/$id/messages',
          data: {'body': body},
        );
        return Message.fromJson(_asMap(res.data));
      });

  @override
  Future<void> markRead(String id) => _guard(() async {
        // Não há endpoint dedicado: abrir o thread reseta `staff_unread` no
        // servidor. Re-buscar é idempotente e cumpre a marcação de leitura.
        await _dio.get<Object?>('/messages/conversations/$id');
      });
}
