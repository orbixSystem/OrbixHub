import 'dart:convert';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/data/local_first_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/receivables/data/local_first_receivables_repository.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_repository.dart';

/// Fiado OFFLINE: a carteira é derivada do espelho local (OS + recebimentos).
///
/// O fiado não tem tabela própria nem no servidor — é venda/OS com saldo. Online
/// o servidor compõe; offline derivamos aqui, o que é o que permite cobrar o
/// cliente numa oficina sem internet.
///
/// Limite conhecido: `sale` não está no sync, então a carteira offline cobre as
/// OS e é marcada como parcial (a tela avisa).

/// Inner que EXPLODE se chamado — garante que offline não vai à rede.
class _InnerProibido implements ReceivablesRepository {
  @override
  Future<DebtorsPage> listDebtors() =>
      throw StateError('offline não deve chamar a rede');

  @override
  Future<DebtorDetail> titlesOf(String? customerId) =>
      throw StateError('offline não deve chamar a rede');
}

/// Inner que responde, para o caso online.
class _InnerOnline implements ReceivablesRepository {
  var chamado = false;

  @override
  Future<DebtorsPage> listDebtors() async {
    chamado = true;
    return const DebtorsPage(totalDue: 999);
  }

  @override
  Future<DebtorDetail> titlesOf(String? customerId) async {
    chamado = true;
    return const DebtorDetail(customerName: 'do servidor');
  }
}

/// Espelho local em memória (o mesmo padrão dos outros testes LocalFirst).
LocalDb _memDb() => LocalDb(NativeDatabase.memory());

void main() {
  late LocalDb db;

  /// Grava uma linha no row-store como o pull do sync faria: JSON cru da API.
  Future<void> gravar(String entity, Map<String, dynamic> payload) =>
      db.upsertRows(entity, [
        (
          id: payload['id'] as String,
          payload: jsonEncode(payload),
          updatedAt: DateTime.utc(2026, 7, 10),
        ),
      ]);

  /// Semeia o espelho local com uma OS e, opcionalmente, um recebimento.
  Future<void> semear({
    required String osId,
    required String total,
    String status = 'concluida',
    String? clienteId = 'c1',
    String? clienteNome = 'João Silva',
    String criada = '2026-07-10T10:00:00Z',
    String? recebido,
    bool estornado = false,
    List<Map<String, dynamic>> itens = const [],
  }) async {
    await gravar('service_order', {
      'id': osId,
      'number': 'OS-${osId.padLeft(4, '0')}',
      'status': status,
      'customer_id': clienteId,
      'customer_name': clienteNome,
      'total': total,
      'created_at': criada,
    });
    for (final i in itens) {
      await gravar('service_order_item', {'order_id': osId, ...i});
    }
    if (recebido != null) {
      await gravar('cash_entry', {
        'id': 'e-$osId',
        'direction': 'in',
        'amount': recebido,
        'method': 'dinheiro',
        'category': 'os_payment',
        'sale_kind': 'os',
        'sale_id': osId,
        'reversed_at': estornado ? '2026-07-11T10:00:00Z' : null,
        'created_at': '2026-07-10T12:00:00Z',
      });
    }
  }

  LocalFirstReceivablesRepository repo({
    required bool online,
    ReceivablesRepository? inner,
  }) =>
      LocalFirstReceivablesRepository(
        inner: inner ?? _InnerProibido(),
        db: db,
        clock: TrustedClock(),
        isOnline: () => online,
        currentUserId: () => 'u1',
      );

  setUp(() => db = _memDb());

  tearDown(() => db.close());

  group('online delega ao servidor', () {
    test('não deriva localmente quando há conexão', () async {
      await semear(osId: '1', total: '100.00');
      final inner = _InnerOnline();
      final page = await repo(online: true, inner: inner).listDebtors();
      expect(inner.chamado, isTrue);
      expect(page.totalDue, 999); // veio do servidor, não do SQLite
    });
  });

  group('offline deriva do espelho local', () {
    test('OS sem recebimento é fiado pelo total', () async {
      await semear(osId: '1', total: '295.60');
      final page = await repo(online: false).listDebtors();

      expect(page.items, hasLength(1));
      expect(page.items.single.customerName, 'João Silva');
      expect(page.items.single.totalDue, 295.6);
      expect(page.items.single.titleCount, 1);
    });

    test('desconta o que já foi recebido (parcial)', () async {
      await semear(osId: '1', total: '300.00', recebido: '100.00');
      final page = await repo(online: false).listDebtors();
      expect(page.items.single.totalDue, 200);

      final d = await repo(online: false).titlesOf('c1');
      expect(d.items.single.status, 'parcial');
      expect(d.items.single.paid, 100);
      expect(d.items.single.balance, 200);
    });

    test('OS quitada NÃO é fiado', () async {
      await semear(osId: '1', total: '100.00', recebido: '100.00');
      expect((await repo(online: false).listDebtors()).items, isEmpty);
    });

    test('recebimento ESTORNADO volta a ser dívida', () async {
      // Estorno é a correção de um recebimento errado: o dinheiro não entrou.
      await semear(
        osId: '1',
        total: '100.00',
        recebido: '100.00',
        estornado: true,
      );
      final page = await repo(online: false).listDebtors();
      expect(page.items.single.totalDue, 100);
    });

    test('OS cancelada não é dívida', () async {
      await semear(osId: '1', total: '100.00', status: 'cancelada');
      expect((await repo(online: false).listDebtors()).items, isEmpty);
    });

    test('resíduo de centavo não vira dívida', () async {
      await semear(osId: '1', total: '100.00', recebido: '99.998');
      expect((await repo(online: false).listDebtors()).items, isEmpty);
    });

    test('soma várias OS do mesmo cliente', () async {
      await semear(osId: '1', total: '100.00');
      await semear(osId: '2', total: '250.00', criada: '2026-07-20T10:00:00Z');
      final page = await repo(online: false).listDebtors();

      expect(page.items, hasLength(1));
      expect(page.items.single.totalDue, 350);
      expect(page.items.single.titleCount, 2);
      // Guarda o mais antigo ("deve desde quando").
      expect(page.items.single.oldestAt, '2026-07-10T10:00:00Z');
    });

    test('ordena do maior devedor para o menor', () async {
      await semear(osId: '1', total: '100.00', clienteId: 'c1', clienteNome: 'Ana');
      await semear(osId: '2', total: '500.00', clienteId: 'c2', clienteNome: 'Bruno');
      final page = await repo(online: false).listDebtors();
      expect(page.items.map((d) => d.customerName), ['Bruno', 'Ana']);
    });

    test('marca a carteira como parcial (venda de balcão não sincroniza)',
        () async {
      await semear(osId: '1', total: '100.00');
      final page = await repo(online: false).listDebtors();
      expect(
        page.truncated,
        isTrue,
        reason: 'sem isto o usuário acharia que viu toda a carteira',
      );
    });

    test('traz os itens da OS (de quais serviços é a dívida)', () async {
      await semear(osId: '1', total: '180.00', itens: [
        {
          'id': 'i1',
          'name': 'Troca de óleo',
          'kind': 'service',
          'quantity': '1',
          'unit_price': '80.00',
          'total': '80.00',
        },
        {
          'id': 'i2',
          'name': 'Óleo 5W30',
          'kind': 'product',
          'quantity': '2',
          'unit_price': '50.00',
          'total': '100.00',
        },
      ]);
      final d = await repo(online: false).titlesOf('c1');
      expect(d.items.single.items, hasLength(2));
      expect(d.items.single.items.first.name, 'Troca de óleo');
      expect(d.items.single.items[1].quantity, 2);
    });

    test('títulos de um cliente não vazam para outro', () async {
      await semear(osId: '1', total: '100.00', clienteId: 'c1', clienteNome: 'Ana');
      await semear(osId: '2', total: '200.00', clienteId: 'c2', clienteNome: 'Bruno');
      final d = await repo(online: false).titlesOf('c1');
      expect(d.customerName, 'Ana');
      expect(d.items, hasLength(1));
      expect(d.totalDue, 100);
    });

    test('OS sem cliente cai no balde "sem cliente"', () async {
      await semear(
        osId: '1',
        total: '80.00',
        clienteId: null,
        clienteNome: null,
      );
      final page = await repo(online: false).listDebtors();
      expect(page.items.single.customerId, isNull);
      expect(page.items.single.customerName, 'Sem cliente');

      final d = await repo(online: false).titlesOf(null);
      expect(d.items, hasLength(1));
    });

    test('carteira vazia não explode', () async {
      final page = await repo(online: false).listDebtors();
      expect(page.items, isEmpty);
      expect(page.totalDue, 0);
    });

    test('recebimento de VENDA de balcão não abate a dívida da OS', () async {
      // O vínculo é polimórfico: `sale_kind` diz se `sale_id` aponta p/ OS ou
      // venda. Sem checar o kind, um recebimento de venda cairia na conta da OS.
      await semear(osId: '1', total: '100.00');
      await gravar('cash_entry', {
        'id': 'e-venda',
        'direction': 'in',
        'amount': '100.00',
        'method': 'dinheiro',
        'category': 'sale_payment',
        'sale_kind': 'sale',
        'sale_id': '1', // mesmo id, outra natureza
        'reversed_at': null,
        'created_at': '2026-07-10T12:00:00Z',
      });
      final page = await repo(online: false).listDebtors();
      expect(page.items.single.totalDue, 100);
    });
  });

  group('receber offline abate a dívida na hora', () {
    test('lançamento feito pelo caixa offline some da carteira', () async {
      // O usuário cobra o cliente na oficina sem internet: o recebimento entra
      // pelo LocalFirstCashierRepository e a carteira — derivada das MESMAS
      // linhas locais — tem de refletir isso sem esperar o sync.
      await semear(osId: '1', total: '300.00');
      expect((await repo(online: false).listDebtors()).items.single.totalDue, 300);

      final caixa = LocalFirstCashierRepository(
        inner: FakeCashierRepository(),
        deviceId: () async => 'device-1',
        db: db,
        clock: TrustedClock(clock: () => DateTime.utc(2026, 7, 13)),
        isOnline: () => false,
        currentUserId: () => 'u1',
      );
      await caixa.openSession(openingAmount: 0);
      await caixa.createEntry(const EntryDraft(
        amount: 120,
        method: 'dinheiro',
        category: 'os_payment',
        saleKind: 'os',
        saleId: '1',
      ));

      final page = await repo(online: false).listDebtors();
      expect(page.items.single.totalDue, 180, reason: '300 − 120 recebidos');

      final d = await repo(online: false).titlesOf('c1');
      expect(d.items.single.status, 'parcial');
      expect(d.items.single.paid, 120);
    });

    test('quitar offline tira o cliente da carteira', () async {
      await semear(osId: '1', total: '300.00');
      final caixa = LocalFirstCashierRepository(
        inner: FakeCashierRepository(),
        deviceId: () async => 'device-1',
        db: db,
        clock: TrustedClock(clock: () => DateTime.utc(2026, 7, 13)),
        isOnline: () => false,
        currentUserId: () => 'u1',
      );
      await caixa.openSession(openingAmount: 0);
      await caixa.createEntry(const EntryDraft(
        amount: 300,
        method: 'dinheiro',
        category: 'os_payment',
        saleKind: 'os',
        saleId: '1',
      ));

      expect((await repo(online: false).listDebtors()).items, isEmpty);
    });
  });
}
