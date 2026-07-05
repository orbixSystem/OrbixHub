import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../domain/tracking_models.dart';
import '../domain/tracking_repository.dart';

/// [TrackingRepository] real para a página PÚBLICA `/t/:token`.
///
/// Usa um Dio LIMPO (sem interceptor de bearer/refresh) — esses endpoints são
/// `@Public` no backend e NÃO devem receber Authorization. Cria o Dio
/// internamente para que a tela pública seja autossuficiente.
class TrackingRepositoryImpl implements TrackingRepository {
  TrackingRepositoryImpl([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

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
  Future<PublicTrack> track(String token) => _guard(() async {
        final res = await _dio.get<Object?>('/public/track/$token');
        return PublicTrack.fromJson(_asMap(res.data));
      });

  @override
  Future<List<PublicMessage>> messages(String token) => _guard(() async {
        final res = await _dio.get<Object?>('/public/track/$token/messages');
        final data = res.data;
        // Aceita uma lista direta ou `{ items: [...] }`.
        final raw = data is Map
            ? (data.cast<String, dynamic>()['items'] as List? ?? const [])
            : (data as List? ?? const []);
        return raw
            .cast<Map<String, dynamic>>()
            .map(PublicMessage.fromJson)
            .toList();
      });

  @override
  Future<void> sendMessage(
    String token,
    String body, {
    String? authorName,
    String? replyToId,
    String? photoId,
  }) =>
      _guard(() async {
        await _dio.post<Object?>(
          '/public/track/$token/messages',
          data: {
            'body': body,
            if (authorName != null && authorName.isNotEmpty)
              'authorName': authorName,
            'replyToId': ?replyToId,
            'photoId': ?photoId,
          },
        );
      });

  @override
  Future<List<PublicPhotoComment>> photoComments(
    String token,
    String photoId,
  ) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/public/track/$token/photos/$photoId/comments',
        );
        final raw = res.data as List? ?? const [];
        return raw
            .cast<Map<String, dynamic>>()
            .map(PublicPhotoComment.fromJson)
            .toList();
      });

  @override
  Future<PublicPhotoComment> addPhotoComment(
    String token,
    String photoId,
    String body, {
    String? authorName,
  }) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/public/track/$token/photos/$photoId/comments',
          data: {
            'body': body,
            if (authorName != null && authorName.isNotEmpty)
              'authorName': authorName,
          },
        );
        return PublicPhotoComment.fromJson(_asMap(res.data));
      });
}
