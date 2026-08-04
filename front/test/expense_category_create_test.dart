import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/features/expenses/data/fake_expenses_repository.dart';
import 'package:orbixhub_front/features/expenses/presentation/expense_visuals.dart';

/// Criação de categoria de despesa.
///
/// O que estes testes protegem: as opções de ícone oferecidas na tela têm de ser
/// exatamente as que o backend aceita (`ICON_KEYS` no `category.dto.ts`). Uma
/// lista paralela escrita à mão divergiria no primeiro ícone novo, e o formulário
/// ofereceria uma chave que a API recusa.
void main() {
  group('chaves de ícone', () {
    // Espelho da whitelist do backend (back/src/modules/expenses/dto/category.dto.ts).
    const doBackend = [
      'aluguel',
      'energia',
      'agua',
      'internet',
      'telefone',
      'impostos',
      'fornecedor',
      'produto',
      'salarios',
      'manutencao',
      'outros',
    ];

    test('a tela oferece EXATAMENTE as chaves que a API aceita', () {
      expect(chavesDeIcone..sort(), doBackend.toList()..sort());
    });

    test('toda chave oferecida tem ícone próprio (nenhuma cai no neutro)', () {
      final neutro = iconeDaCategoria('chave-que-nao-existe');
      for (final chave in chavesDeIcone) {
        expect(
          iconeDaCategoria(chave),
          isNot(neutro),
          reason: '"$chave" cairia no ícone neutro — ou falta no mapa, ou sobra '
              'na lista de opções',
        );
      }
    });

    test('chave desconhecida degrada para o neutro, sem quebrar', () {
      // Categoria criada antes de um ícone novo entrar no mapa.
      expect(iconeDaCategoria('cripto'), isNotNull);
      expect(iconeDaCategoria(null), isNotNull);
    });
  });

  group('corHex', () {
    test('hex válido vira cor; inválido cai no cinza neutro', () {
      expect(corHex('#F97316').toARGB32(), 0xFFF97316);
      // Cor é decoração — valor podre não pode derrubar a tela.
      expect(corHex('laranja').toARGB32(), 0xFF6B7280);
      expect(corHex(null).toARGB32(), 0xFF6B7280);
    });
  });

  group('criarCategoria (fake espelhando o servidor)', () {
    test('cria e passa a aparecer na listagem', () async {
      final repo = FakeExpensesRepository();
      final antes = (await repo.categorias()).length;

      final nova = await repo.criarCategoria(
        name: '  Contador  ',
        icon: 'impostos',
        color: '#22C55E',
      );

      expect(nova.name, 'Contador', reason: 'nome é aparado');
      expect(nova.icon, 'impostos');
      expect(nova.color, '#22C55E');
      expect((await repo.categorias()).length, antes + 1);
    });

    test('sem ícone/cor cai nos defaults do servidor', () async {
      final repo = FakeExpensesRepository();
      final nova = await repo.criarCategoria(name: 'Seguro');
      expect(nova.icon, 'outros');
      expect(nova.color, '#6B7280');
    });

    test('nome repetido entre ativas é 409 (não cria duplicata silenciosa)',
        () async {
      final repo = FakeExpensesRepository();
      final existente = (await repo.categorias()).first;
      await expectLater(
        repo.criarCategoria(name: existente.name.toUpperCase()),
        throwsA(
          isA<AppException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });
  });
}
