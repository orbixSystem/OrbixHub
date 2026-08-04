import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_models.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_status.dart';

/// Parsing do formato REAL devolvido por `GET /api/expenses`.
///
/// O payload abaixo foi copiado da resposta do servidor, não inventado — é o que
/// pega as três armadilhas do contrato:
///   1. as linhas são cruas do Prisma, em `snake_case`;
///   2. `Decimal` do Postgres vira **String** no JSON (`"2500"`), não número;
///   3. `date` chega em ISO completo (`...T00:00:00.000Z`), não `YYYY-MM-DD`.
void main() {
  final json = <String, dynamic>{
    'items': [
      {
        'id': 'b3062621-a5da-4d9e-aae8-0a4bd1916b40',
        'tenant_id': '11be3111-6ac6-4da9-be6e-c97c7e1f0c5c',
        'description': 'Aluguel do galpao',
        'amount': '2500',
        'due_date': '2026-08-10T00:00:00.000Z',
        'category_id': '27847d39-abc2-454f-b192-1a294fa1b10f',
        'recurrence_id': '0c0c27a3-4106-4cd1-ab81-fb2e2dc59567',
        'occurrence_on': '2026-08-10T00:00:00.000Z',
        'paid_at': '2026-08-04T19:45:17.084Z',
        'paid_amount': '2612.5',
        'paid_method': 'dinheiro',
        'cash_entry_id': '3f3ed58b-7004-4bd8-914d-cbbfd4880c99',
        'notes': null,
        'status': 'active',
        'created_by': 'a242edb2-c4fa-4b32-8ca5-5af943d24949',
        'created_at': '2026-08-04T19:44:28.768Z',
        'updated_at': '2026-08-04T19:45:17.084Z',
      },
      {
        'id': 'c1000000-0000-4000-8000-000000000001',
        'description': 'Conta de luz',
        'amount': '0',
        'due_date': '2026-08-20T00:00:00.000Z',
        'category_id': null,
        'recurrence_id': null,
        'occurrence_on': null,
        'paid_at': null,
        'paid_amount': null,
        'paid_method': null,
        'cash_entry_id': null,
        'notes': 'Fatura ainda não chegou',
        'status': 'active',
      },
    ],
    'categories': [
      {
        'id': '27847d39-abc2-454f-b192-1a294fa1b10f',
        'tenant_id': '11be3111-6ac6-4da9-be6e-c97c7e1f0c5c',
        'name': 'Aluguel',
        'icon': 'aluguel',
        'color': '#F97316',
        'status': 'active',
        'created_at': '2026-08-04T19:00:00.000Z',
        'updated_at': '2026-08-04T19:00:00.000Z',
      },
    ],
    'totalPrevisto': 2500,
    'totalPago': 2612.5,
    'totalEmAberto': 0,
    'totalVencido': 0,
  };

  group('ExpensesMonth.fromJson — payload real do servidor', () {
    late ExpensesMonth mes;
    setUp(() => mes = ExpensesMonth.fromJson(json));

    test('lê a lista, as categorias e os totais', () {
      expect(mes.items, hasLength(2));
      expect(mes.categories.single.name, 'Aluguel');
      expect(mes.totalPago, 2612.5);
    });

    test('Decimal em String vira num', () {
      // A armadilha: `'2500' > 0` nem compila, e `num` cru estouraria no parse.
      expect(mes.items.first.amount, 2500);
      expect(mes.items.first.paidAmount, 2612.5);
      expect(mes.items.first.temValor, isTrue);
    });

    test('amount "0" continua significando "a confirmar"', () {
      final luz = mes.items[1];
      expect(luz.amount, 0);
      expect(luz.temValor, isFalse);
    });

    test('paid_amount nulo cai no previsto', () {
      expect(mes.items[1].valorEfetivo, 0);
      expect(mes.items.first.valorEfetivo, 2612.5);
    });

    test('snake_case chega nos campos certos', () {
      final a = mes.items.first;
      expect(a.categoryId, '27847d39-abc2-454f-b192-1a294fa1b10f');
      expect(a.recurrenceId, isNotNull);
      expect(a.cashEntryId, '3f3ed58b-7004-4bd8-914d-cbbfd4880c99');
      expect(a.paidMethod, 'dinheiro');
    });

    test('due_date em ISO completo vira a data civil certa', () {
      // O 'Z' faz o parse devolver UTC; ler `.day` dali não escorrega de dia.
      final venc = mes.items.first.vencimento;
      expect([venc.year, venc.month, venc.day], [2026, 8, 10]);
    });

    test('a situação sai do paid_at, não de um campo de status', () {
      final hoje = DateTime(2026, 8, 25);
      expect(mes.items.first.situacao(hoje), ExpenseStatus.pago);
      // A luz vence em 20/08 e não foi paga: em 25/08 está vencida.
      expect(mes.items[1].situacao(hoje), ExpenseStatus.vencido);
    });
  });
}
