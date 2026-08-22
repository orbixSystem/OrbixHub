import 'package:dio/dio.dart';

import '../domain/support_models.dart';
import '../domain/support_repository.dart';

class SupportRepositoryImpl implements SupportRepository {
  SupportRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<SupportTicket>> tickets() async {
    final res = await _dio.get<Object?>('/support/tickets');
    final list = (res.data as List<dynamic>? ?? const []);
    return list
        .map((e) => SupportTicket.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<SupportMessage>> mensagens(String ticketId) async {
    final res = await _dio.get<Object?>('/support/tickets/$ticketId/messages');
    final list = (res.data as List<dynamic>? ?? const []);
    return list
        .map((e) => SupportMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<SupportTicket> abrir(String subject, String body) async {
    final res = await _dio.post<Object?>('/support/tickets',
        data: {'subject': subject, 'body': body});
    return SupportTicket.fromJson((res.data as Map).cast<String, dynamic>());
  }

  @override
  Future<SupportMessage> responder(String ticketId, String body) async {
    final res = await _dio.post<Object?>('/support/tickets/$ticketId/messages',
        data: {'body': body});
    return SupportMessage.fromJson((res.data as Map).cast<String, dynamic>());
  }

  @override
  Future<void> resolver(String ticketId) async {
    await _dio.post<Object?>('/support/tickets/$ticketId/resolve');
  }

  @override
  Future<int> unread() async {
    final res = await _dio.get<Object?>('/support/unread');
    return ((res.data as Map)['count'] as num?)?.toInt() ?? 0;
  }
}
