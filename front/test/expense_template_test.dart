import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/domain/expense_template_fill.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';

/// Despesas fixas: o que o atalho preenche e o que ele NÃO deve preencher.
///
/// A regra central: o modelo é um preset. Ele sugere; a config do caixa e as
/// regras de gaveta mandam. E valor 0 não é "grátis", é "varia" — a diferença
/// decide se o operador confirma direto ou digita antes.
void main() {
  const todasFormas = ['pix', 'dinheiro', 'cartao_credito', 'cartao_debito', 'outro'];

  group('fillFromTemplate', () {
    test('modelo com valor preenche nome, valor e forma sugerida', () {
      const tpl = ExpenseTemplate(
        id: 't1',
        name: 'Aluguel',
        amount: '1200',
        method: 'pix',
      );
      final fill = fillFromTemplate(
        tpl,
        paymentMethods: todasFormas,
        currentMethod: 'dinheiro',
      );
      expect(fill.description, 'Aluguel');
      expect(fill.amountText, '1200');
      expect(fill.method, 'pix');
      expect(fill.category, 'despesa');
      expect(fill.pedeValor, isFalse);
    });

    test('valor 0 = "varia": não preenche valor e pede para digitar', () {
      const tpl = ExpenseTemplate(id: 't2', name: 'Conta de luz');
      final fill = fillFromTemplate(
        tpl,
        paymentMethods: todasFormas,
        currentMethod: 'pix',
      );
      expect(fill.description, 'Conta de luz');
      expect(fill.amountText, isEmpty);
      expect(fill.pedeValor, isTrue);
      // Sem sugestão no modelo: mantém a forma que já estava selecionada.
      expect(fill.method, 'pix');
    });

    test('centavos são preservados; valor redondo não vira "1200,00"', () {
      const redondo = ExpenseTemplate(id: 'a', name: 'A', amount: '1200.00');
      const quebrado = ExpenseTemplate(id: 'b', name: 'B', amount: '89.90');
      expect(
        fillFromTemplate(redondo, paymentMethods: todasFormas, currentMethod: 'pix')
            .amountText,
        '1200',
      );
      expect(
        fillFromTemplate(quebrado, paymentMethods: todasFormas, currentMethod: 'pix')
            .amountText,
        '89.90',
      );
    });

    test('forma desativada na config é IGNORADA (não deixa dropdown inválido)', () {
      // O tenant cadastrou "Aluguel · Pix" e depois desligou o Pix na config.
      const tpl = ExpenseTemplate(
        id: 't3',
        name: 'Aluguel',
        amount: '1200',
        method: 'pix',
      );
      final fill = fillFromTemplate(
        tpl,
        paymentMethods: const ['dinheiro', 'cartao_debito'],
        currentMethod: 'dinheiro',
      );
      expect(fill.method, 'dinheiro');
    });

    test('sangria é gaveta: sempre dinheiro, ignorando a sugestão do modelo', () {
      const tpl = ExpenseTemplate(
        id: 't4',
        name: 'Retirada do dono',
        amount: '300',
        category: 'sangria',
        method: 'pix', // sugestão incoerente, gravada por engano
      );
      final fill = fillFromTemplate(
        tpl,
        paymentMethods: todasFormas,
        currentMethod: 'cartao_credito',
      );
      expect(fill.category, 'sangria');
      expect(fill.method, 'dinheiro');
    });
  });

  group('ExpenseTemplate — leitura', () {
    test('temValor distingue valor fechado de "varia"', () {
      expect(const ExpenseTemplate(id: 'a', name: 'A', amount: '10').temValor, isTrue);
      expect(const ExpenseTemplate(id: 'b', name: 'B').temValor, isFalse);
      expect(
        const ExpenseTemplate(id: 'c', name: 'C', amount: '0.00').temValor,
        isFalse,
      );
    });

    test('ativo reflete o status', () {
      expect(const ExpenseTemplate(id: 'a', name: 'A').ativo, isTrue);
      expect(
        const ExpenseTemplate(id: 'b', name: 'B', status: 'disabled').ativo,
        isFalse,
      );
    });
  });

  group('ExpenseTemplateDraft — o que vai no corpo da requisição', () {
    test('só envia o que foi informado (patch parcial de verdade)', () {
      const d = ExpenseTemplateDraft(amount: 1350);
      expect(d.toJson(), {'amount': 1350.0});
    });

    test('limparMethod manda null explícito; ausência não manda nada', () {
      // Os dois casos precisam ser distinguíveis: "usar o default do caixa"
      // (limpar) ≠ "não mexer na forma já gravada".
      expect(
        const ExpenseTemplateDraft(limparMethod: true).toJson(),
        {'method': null},
      );
      expect(const ExpenseTemplateDraft(name: 'X').toJson(), {'name': 'X'});
    });

    test('method informado ganha de limparMethod=false', () {
      expect(
        const ExpenseTemplateDraft(method: 'pix').toJson(),
        {'method': 'pix'},
      );
    });
  });

  group('FakeCashierRepository — despesas fixas', () {
    test('vem semeado com um modelo de valor variável', () async {
      final repo = FakeCashierRepository();
      final lista = await repo.listExpenseTemplates();
      expect(lista.any((t) => t.temValor), isTrue);
      expect(lista.any((t) => !t.temValor), isTrue);
    });

    test('nome repetido entre ativos é 409', () async {
      final repo = FakeCashierRepository();
      await expectLater(
        repo.createExpenseTemplate(
          const ExpenseTemplateDraft(name: 'aluguel', amount: 10),
        ),
        throwsA(
          isA<AppException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('desativar tira da listagem padrão e mantém em includeDisabled', () async {
      final repo = FakeCashierRepository();
      await repo.disableExpenseTemplate('tpl-aluguel');
      final ativos = await repo.listExpenseTemplates();
      final todos = await repo.listExpenseTemplates(includeDisabled: true);
      expect(ativos.any((t) => t.id == 'tpl-aluguel'), isFalse);
      expect(todos.any((t) => t.id == 'tpl-aluguel'), isTrue);
    });

    test('editar valor não mexe no resto', () async {
      final repo = FakeCashierRepository();
      final novo = await repo.updateExpenseTemplate(
        'tpl-aluguel',
        const ExpenseTemplateDraft(amount: 1350),
      );
      expect(novo.name, 'Aluguel');
      expect(novo.method, 'pix');
      expect(novo.valor, 1350);
    });

    test('limparMethod apaga a forma sugerida', () async {
      final repo = FakeCashierRepository();
      final novo = await repo.updateExpenseTemplate(
        'tpl-aluguel',
        const ExpenseTemplateDraft(limparMethod: true),
      );
      expect(novo.method, isNull);
    });
  });
}
