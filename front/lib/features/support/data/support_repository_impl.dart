import 'package:dio/dio.dart';

import '../domain/support_models.dart';
import '../domain/support_repository.dart';

class SupportRepositoryImpl implements SupportRepository {
  SupportRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<SupportMessage>> thread() async {
    final res = await _dio.get<Object?>('/support/messages');
    final list = (res.data as List<dynamic>? ?? const []);
    return list
        .map((e) => SupportMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<int> unread() async {
    final res = await _dio.get<Object?>('/support/unread');
    return ((res.data as Map)['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<SupportMessage> enviar(String body) async {
    final res = await _dio.post<Object?>('/support/messages', data: {'body': body});
    return SupportMessage.fromJson((res.data as Map).cast<String, dynamic>());
  }
}
