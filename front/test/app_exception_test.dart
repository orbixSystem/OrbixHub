import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';

/// Mapeamento de erro do backend — a régua contra a barra "feia" que o usuário
/// via: cadastrar um produto e receber literalmente "property description
/// should not exist" numa mensagem na tela.
///
/// A distinção que importa: o NestJS devolve `message` como STRING para
/// exceções escritas à mão (`throw new BadRequestException('CNPJ inválido.')`)
/// — sempre pensadas para quem usa o sistema, mostra direto. E como ARRAY para
/// o `ValidationPipe` reagindo a um DTO (`class-validator`) — frases em inglês
/// com nome de campo cru, o retrato de um bug do app, nunca de uma mensagem
/// pensada para o usuário. Essa é suprimida da UI (mas preservada em
/// `debugDetails`, para quem investiga).
void main() {
  DioException dioComResposta(int status, Object? data) {
    final req = RequestOptions(path: '/x');
    return DioException(
      requestOptions: req,
      response: Response(requestOptions: req, statusCode: status, data: data),
    );
  }

  group('mensagem escrita à mão (string) — mostra direto', () {
    test('BadRequestException com string aparece sem alteração', () {
      final e = AppException.fromDio(dioComResposta(400, {
        'statusCode': 400,
        'error': 'Bad Request',
        'message': 'CNPJ inválido.',
      }));
      expect(e.message, 'CNPJ inválido.');
      expect(e.debugDetails, isNull);
    });

    test('mensagem ausente cai num genérico, não em null/vazio', () {
      final e = AppException.fromDio(
        dioComResposta(400, {'statusCode': 400, 'error': 'Bad Request'}),
      );
      expect(e.message, 'Algo deu errado.');
    });
  });

  group('mensagem do ValidationPipe (array) — NUNCA aparece crua', () {
    test('"property X should not exist" não vaza para a UI', () {
      final e = AppException.fromDio(dioComResposta(400, {
        'statusCode': 400,
        'error': 'Bad Request',
        'message': ['property description should not exist'],
      }));
      expect(e.message, isNot(contains('property')));
      expect(e.message, isNot(contains('should not exist')));
      // Guardada para quem investiga, não escondida de vez.
      expect(e.debugDetails, contains('property description should not exist'));
    });

    test('array com várias mensagens também vira o genérico', () {
      final e = AppException.fromDio(dioComResposta(400, {
        'statusCode': 400,
        'error': 'Bad Request',
        'message': [
          'name must be longer than or equal to 2 characters',
          'salePrice must be a positive number',
        ],
      }));
      expect(e.message, isNot(contains('must be')));
      expect(e.debugDetails, contains('salePrice must be a positive number'));
    });

    test('mensagem genérica é a mesma para qualquer array — previsível', () {
      final a = AppException.fromDio(dioComResposta(400, {'message': ['x']}));
      final b = AppException.fromDio(dioComResposta(400, {'message': ['y', 'z']}));
      expect(a.message, b.message);
    });
  });

  group('sem resposta do servidor', () {
    test('erro de rede tem mensagem de conexão, statusCode nulo', () {
      final e = AppException.fromDio(
        DioException(requestOptions: RequestOptions(path: '/x')),
      );
      expect(e.isNetwork, isTrue);
      expect(e.message, contains('conexão'));
    });

    test('resposta sem corpo (não é Map) cai no genérico', () {
      final e = AppException.fromDio(dioComResposta(500, 'erro cru em texto'));
      expect(e.message, 'Algo deu errado.');
    });
  });

  test('toString() é a mensagem exibível, nunca a técnica', () {
    final e = AppException.fromDio(dioComResposta(400, {
      'message': ['property x should not exist'],
    }));
    expect(e.toString(), e.message);
    expect(e.toString(), isNot(contains('should not exist')));
  });
}
