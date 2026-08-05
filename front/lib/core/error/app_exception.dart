import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Domain-level error mapped from the backend's `{ statusCode, error, message }`
/// envelope. The UI shows [message] (already generic/anti-enumeration on auth
/// routes) and may branch on [statusCode] (e.g. 403 → "sem acesso").
class AppException implements Exception {
  const AppException({
    this.statusCode,
    required this.error,
    required this.message,
    this.debugDetails,
  });

  final int? statusCode;
  final String error;
  final String message;

  /// A mensagem TÉCNICA original, quando [message] foi trocada por uma
  /// genérica (ver [fromDio]). Só para depuração — a UI nunca mostra isto.
  final String? debugDetails;

  bool get isForbidden => statusCode == 403;
  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  /// Maps a low-level [DioException] into an [AppException]. Never leaks the raw
  /// dio/network message as if it were a backend detail.
  ///
  /// O NestJS devolve `message` de dois jeitos, e a diferença IMPORTA:
  ///  - **string**: uma exceção escrita à mão (`throw new BadRequestException(
  ///    'CNPJ inválido.')`) — sempre pensada para o usuário ler, mostra direto;
  ///  - **array**: o `ValidationPipe` reagindo a um DTO (`class-validator`), com
  ///    frases em INGLÊS e nome de CAMPO cru ("property description should not
  ///    exist", "name must be longer than..."). Isso é o retrato de um bug do
  ///    app (campo que o front manda e o backend não espera, ou vice-versa) —
  ///    nunca uma mensagem pensada para quem está usando o sistema. Mostrar
  ///    "property X should not exist" para o dono da oficina foi exatamente o
  ///    que aconteceu ao cadastrar um produto com a build antiga do app: feio,
  ///    incompreensível, e sem ação nenhuma que a pessoa possa tomar.
  ///
  /// A mensagem técnica não é descartada — vai em [AppException.debugDetails],
  /// para quem estiver investigando (nunca renderizado na UI).
  factory AppException.fromDio(DioException e) {
    final res = e.response;
    final data = res?.data;
    if (data is Map) {
      final msg = data['message'];
      final erro = (data['error'] ?? 'Error').toString();
      if (msg is List) {
        final tecnico = msg.join(', ');
        if (kDebugMode) {
          // ignore: avoid_print
          print('AppException: mensagem técnica do backend suprimida da UI: '
              '$tecnico');
        }
        return AppException(
          statusCode: res?.statusCode,
          error: erro,
          message: 'Não foi possível concluir. Verifique os dados e tente '
              'novamente.',
          debugDetails: tecnico,
        );
      }
      return AppException(
        statusCode: res?.statusCode,
        error: erro,
        message: (msg ?? 'Algo deu errado.').toString(),
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
