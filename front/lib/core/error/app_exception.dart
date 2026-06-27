import 'package:dio/dio.dart';

/// Domain-level error mapped from the backend's `{ statusCode, error, message }`
/// envelope. The UI shows [message] (already generic/anti-enumeration on auth
/// routes) and may branch on [statusCode] (e.g. 403 → "sem acesso").
class AppException implements Exception {
  const AppException({
    this.statusCode,
    required this.error,
    required this.message,
  });

  final int? statusCode;
  final String error;
  final String message;

  bool get isForbidden => statusCode == 403;
  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  /// Maps a low-level [DioException] into an [AppException]. Never leaks the raw
  /// dio/network message as if it were a backend detail.
  factory AppException.fromDio(DioException e) {
    final res = e.response;
    final data = res?.data;
    if (data is Map) {
      final msg = data['message'];
      return AppException(
        statusCode: res?.statusCode,
        error: (data['error'] ?? 'Error').toString(),
        message: msg is List
            ? msg.join(', ')
            : (msg ?? 'Algo deu errado.').toString(),
      );
    }
    if (res != null) {
      return AppException(
        statusCode: res.statusCode,
        error: 'Error',
        message: 'Algo deu errado.',
      );
    }
    return const AppException(
      statusCode: null,
      error: 'Network',
      message: 'Sem conexão com o servidor.',
    );
  }

  @override
  String toString() => message;
}
