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
  Future<List<Conversation>> listConversations() => _guard(() async {
        final res = await _dio.get<Object?>('/messages/conversations');
        final items = (_asMap(res.data)['items'] as List? ?? const [])
            .map((e) => Conversation.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        return items;
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
