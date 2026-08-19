import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/features/tracking/presentation/tracking_error_info.dart';

/// A tela pública `/t/:token` dizia "Acompanhamento não encontrado" para
/// QUALQUER falha: servidor fora, 500 do banco, CORS, link errado. Quem abria o
/// link concluía que a OS não existe, e quem desenvolve não tinha o que
/// investigar. Cada causa precisa ter cara própria — e as que podem passar
/// sozinhas precisam de um botão para tentar de novo.
void main() {
  AppException erro(int? status, {String? requestId, String msg = 'x'}) =>
      AppException(
        statusCode: status,
        error: 'E',
        message: msg,
        requestId: requestId,
      );

  test('token malformado é link inválido, não OS inexistente', () {
    final info = trackingErrorInfo(validToken: false, error: null);
    expect(info.kind, TrackingErrorKind.linkInvalido);
    expect(info.canRetry, isFalse);
  });

  test('404 é o único caso de "não encontrado"', () {
    final info = trackingErrorInfo(validToken: true, error: erro(404));
    expect(info.kind, TrackingErrorKind.naoEncontrado);
    expect(info.title, contains('não encontrado'));
    expect(info.canRetry, isFalse);
  });

  test('servidor inalcançável vira falta de conexão, com retry', () {
    final info = trackingErrorInfo(validToken: true, error: erro(null));
    expect(info.kind, TrackingErrorKind.semConexao);
    expect(info.title.toLowerCase(), contains('conexão'));
    expect(info.canRetry, isTrue);
    // O que NÃO pode: acusar o link de errado quando o problema é a rede.
    expect(info.title.toLowerCase(), isNot(contains('não encontrado')));
  });

  test('5xx vira instabilidade do sistema, com retry', () {
    final info = trackingErrorInfo(validToken: true, error: erro(500));
    expect(info.kind, TrackingErrorKind.servidor);
    expect(info.canRetry, isTrue);
    expect(info.title.toLowerCase(), isNot(contains('não encontrado')));
  });

  test('detalhe técnico traz status e requestId para casar com o log', () {
    final info = trackingErrorInfo(
      validToken: true,
      error: erro(500, requestId: 'req-abc'),
    );
    expect(info.detail, isNotNull);
    expect(info.detail, contains('500'));
    expect(info.detail, contains('req-abc'));
  });

  test('sem requestId o detalhe ainda mostra o status', () {
    final info = trackingErrorInfo(validToken: true, error: erro(503));
    expect(info.detail, contains('503'));
  });

  test('404 não precisa de detalhe técnico — a causa é o link', () {
    final info = trackingErrorInfo(validToken: true, error: erro(404));
    expect(info.detail, isNull);
  });

  test('sem erro e sem dado ainda é não encontrado', () {
    final info = trackingErrorInfo(validToken: true, error: null);
    expect(info.kind, TrackingErrorKind.naoEncontrado);
  });

  test('4xx inesperado mostra a mensagem do backend, com retry', () {
    final info = trackingErrorInfo(
      validToken: true,
      error: erro(429, msg: 'Muitas tentativas.'),
    );
    expect(info.kind, TrackingErrorKind.outro);
    expect(info.message, contains('Muitas tentativas.'));
    expect(info.canRetry, isTrue);
  });
}
