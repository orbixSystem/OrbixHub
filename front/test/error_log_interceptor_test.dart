import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/network/error_log_interceptor.dart';

/// Toda falha de HTTP precisa deixar UMA linha no console do app dizendo
/// método, rota, status, causa e o `requestId` que o servidor logou. Sem isso a
/// tela quebra em silêncio e não há por onde começar a investigar.
void main() {
  DioException falha({
    int? status,
    Object? data,
    String path = '/public/track/abc',
    String method = 'GET',
    DioExceptionType type = DioExceptionType.badResponse,
  }) {
    final req = RequestOptions(
      path: path,
      method: method,
      baseUrl: 'http://localhost:4500/api',
    );
    return DioException(
      requestOptions: req,
      type: type,
      response: status == null
          ? null
          : Response(requestOptions: req, statusCode: status, data: data),
    );
  }

  test('linha de 5xx traz método, rota, status e requestId', () {
    final linha = formatFalhaHttp(falha(
      status: 500,
      data: {
        'statusCode': 500,
        'error': 'Internal Server Error',
        'message': 'Internal server error',
        'requestId': 'req-abc',
      },
    ));
    expect(linha, contains('GET'));
    expect(linha, contains('/public/track/abc'));
    expect(linha, contains('500'));
    expect(linha, contains('req-abc'));
    expect(linha, contains('Internal server error'));
  });

  test('sem resposta do servidor a linha diz isso explicitamente', () {
    final linha = formatFalhaHttp(
      falha(type: DioExceptionType.connectionError),
    );
    expect(linha.toLowerCase(), contains('sem resposta'));
    expect(linha, contains('connectionError'));
    // Não pode fingir um status que nunca existiu.
    expect(linha, isNot(contains('500')));
  });

  test('mensagem em array (ValidationPipe) aparece inteira no log', () {
    final linha = formatFalhaHttp(falha(
      status: 400,
      method: 'POST',
      path: '/inventory',
      data: {
        'message': ['property description should not exist'],
      },
    ));
    expect(linha, contains('POST'));
    expect(linha, contains('property description should not exist'));
  });

  test('o interceptor emite a linha e repassa o erro adiante', () {
    final linhas = <String>[];
    final interceptor = ErrorLogInterceptor(sink: linhas.add);
    final e = falha(status: 503, data: {'message': 'fora do ar'});

    var repassado = false;
    interceptor.onError(
      e,
      _HandlerEspiao(onNext: () => repassado = true),
    );

    expect(linhas, hasLength(1));
    expect(linhas.single, contains('503'));
    // Logar não pode engolir o erro — a tela ainda precisa reagir a ele.
    expect(repassado, isTrue);
  });
}

class _HandlerEspiao extends ErrorInterceptorHandler {
  _HandlerEspiao({required this.onNext});
  final void Function() onNext;

  @override
  void next(DioException err) => onNext();
}
