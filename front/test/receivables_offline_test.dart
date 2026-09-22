import 'dart:convert';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_query.dart';
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
  Future<DebtorsPage> listDebtors(DebtorsQuery query) =>
      throw StateError('offline não deve chamar a rede');

  @override
  Future<DebtorDetail> titlesOf(String? customerId, {String? apelido}) =>
      throw StateError('offline não deve chamar a rede');

  @override
  Future<OpenTitlesPage> listOpenTitles() =>
      throw StateError('offline não deve chamar a rede');

  @override
  Future<OpenTitlesPage> listPendingSettlement() =>
      throw StateError('offline não deve chamar a rede');
}

/// Inner que responde, para o caso online.
class _InnerOnline implements ReceivablesRepository {
  var chamado = false;

  @override
  Future<DebtorsPage> listDebtors(DebtorsQuery query) async {
    chamado = true;
    return const DebtorsPage(totalDue: 999);
  }

  @override
  Future<DebtorDetail> titlesOf(String? customerId, {String? apelido}) async {
    chamado = true;
    return const DebtorDetail(customerName: 'do servidor');
  }

  @override
  Future<OpenTitlesPage> listOpenTitles() async {
    chamado = true;
    return const OpenTitlesPage(totalDue: 999);
  }

  @override
  Future<OpenTitlesPage> listPendingSettlement() async {
    chamado = true;
    return const OpenTitlesPage(totalDue: 999);
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
    // Fiado é DECLARADO: sem passagem pelo caixa o título não é dívida. A
    // fixture padrão representa dívida legítima, então nasce declarada — os
    // cenários que testam a regra de passagem passam `fiadoAt: null`.
    String? fiadoAt = '2026-07-10T11:00:00Z',
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
      'fiado_at': fiadoAt,
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
      final page = await repo(online: true, inner: inner).listDebtors(const DebtorsQuery());
      expect(inner.chamado, isTrue);
      expect(page.totalDue, 999); // veio do servidor, não do SQLite
    });
  });

  group('offline deriva do espelho local', () {
    test('OS sem recebimento é fiado pelo total', () async {
      await semear(osId: '1', total: '295.60');
      final page = await repo(online: false).listDebtors(const DebtorsQuery());

      expect(page.items, hasLength(1));
      expect(page.items.single.customerName, 'João Silva');
      expect(page.items.single.totalDue, 295.6);
      expect(page.items.single.titleCount, 1);
    });

    test('desconta o que já foi recebido (parcial)', () async {
      await semear(osId: '1', total: '300.00', recebido: '100.00');
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items.single.totalDue, 200);

      final d = await repo(online: false).titlesOf('c1');
      expect(d.items.single.status, 'parcial');
      expect(d.items.single.paid, 100);
      expect(d.items.single.balance, 200);
    });

    test('OS quitada NÃO é fiado', () async {
      await semear(osId: '1', total: '100.00', recebido: '100.00');
      expect((await repo(online: false).listDebtors(const DebtorsQuery())).items, isEmpty);
    });

    test('recebimento ESTORNADO volta a ser dívida', () async {
      // Estorno é a correção de um recebimento errado: o dinheiro não entrou.
      await semear(
        osId: '1',
        total: '100.00',
        recebido: '100.00',
        estornado: true,
      );
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items.single.totalDue, 100);
    });

    test('OS cancelada não é dívida', () async {
      await semear(osId: '1', total: '100.00', status: 'cancelada');
      expect((await repo(online: false).listDebtors(const DebtorsQuery())).items, isEmpty);
    });

    test('resíduo de centavo não vira dívida', () async {
      await semear(osId: '1', total: '100.00', recebido: '99.998');
      expect((await repo(online: false).listDebtors(const DebtorsQuery())).items, isEmpty);
    });

    test('soma várias OS do mesmo cliente', () async {
      await semear(osId: '1', total: '100.00');
      await semear(osId: '2', total: '250.00', criada: '2026-07-20T10:00:00Z');
      final page = await repo(online: false).listDebtors(const DebtorsQuery());

      expect(page.items, hasLength(1));
      expect(page.items.single.totalDue, 350);
      expect(page.items.single.titleCount, 2);
      // Guarda o mais antigo ("deve desde quando").
      expect(page.items.single.oldestAt, '2026-07-10T10:00:00Z');
    });

    test('ordena do maior devedor para o menor', () async {
      await semear(osId: '1', total: '100.00', clienteId: 'c1', clienteNome: 'Ana');
      await semear(osId: '2', total: '500.00', clienteId: 'c2', clienteNome: 'Bruno');
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items.map((d) => d.customerName), ['Bruno', 'Ana']);
    });

    test('carteira offline sai INTEIRA (não é mais um recorte)', () async {
      // Com `sale`/`sale_item` no sync, o espelho tem as duas origens de dívida:
      // não há mais motivo para avisar que a lista está parcial.
      await semear(osId: '1', total: '100.00');
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.truncated, isFalse);
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
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items.single.customerId, isNull);
      expect(page.items.single.customerName, 'Sem cliente');

      final d = await repo(online: false).titlesOf(null);
      expect(d.items, hasLength(1));
    });

    test('carteira vazia não explode', () async {
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items, isEmpty);
      expect(page.totalDue, 0);
    });

  });

  group('venda de balcão em fiado entra na carteira', () {
    /// Semeia uma venda do espelho (como o pull de `sale`/`sale_item` traria).
    Future<void> semearVenda({
      required String id,
      required String total,
      String status = 'active',
      String? clienteId = 'c1',
      String? clienteNome = 'João Silva',
      String criada = '2026-07-15T10:00:00Z',
      String? recebido,
      String? fiadoAt = '2026-07-15T11:00:00Z',
      List<Map<String, dynamic>> itens = const [],
    }) async {
      await gravar('sale', {
        'id': id,
        'number': 'VND-000$id',
        'status': status,
        'customer_id': clienteId,
        'customer_name': clienteNome,
        'total': total,
        'discount': '0',
        'created_at': criada,
        'fiado_at': fiadoAt,
      });
      for (final i in itens) {
        await gravar('sale_item', {'sale_id': id, ...i});
      }
      if (recebido != null) {
        await gravar('cash_entry', {
          'id': 'ev-$id',
          'direction': 'in',
          'amount': recebido,
          'method': 'dinheiro',
          'category': 'sale_payment',
          'sale_kind': 'sale',
          'sale_id': id,
          'reversed_at': null,
          'created_at': '2026-07-15T12:00:00Z',
        });
      }
    }

    test('venda sem recebimento é fiado', () async {
      await semearVenda(id: '9', total: '150.00');
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items.single.totalDue, 150);

      final d = await repo(online: false).titlesOf('c1');
      expect(d.items.single.origin, 'sale');
      expect(d.items.single.number, 'VND-0009');
    });

    test('venda quitada não é fiado', () async {
      await semearVenda(id: '9', total: '150.00', recebido: '150.00');
      expect((await repo(online: false).listDebtors(const DebtorsQuery())).items, isEmpty);
    });

    test('venda cancelada não é dívida', () async {
      await semearVenda(id: '9', total: '150.00', status: 'canceled');
      expect((await repo(online: false).listDebtors(const DebtorsQuery())).items, isEmpty);
    });

    test('OS e venda do MESMO cliente somam num saldo só', () async {
      // É a pergunta do balcão: "quanto o João me deve, no total?" — não importa
      // se a dívida nasceu de uma OS ou de uma venda rápida.
      await semear(osId: '1', total: '200.00');
      await semearVenda(id: '9', total: '150.00');
      final page = await repo(online: false).listDebtors(const DebtorsQuery());

      expect(page.items, hasLength(1));
      expect(page.items.single.totalDue, 350);
      expect(page.items.single.titleCount, 2);

      final d = await repo(online: false).titlesOf('c1');
      expect(d.items.map((t) => t.origin), ['os', 'sale']); // mais antigo 1º
      expect(d.totalDue, 350);
    });

    test('itens da venda detalham a dívida (subtotal, não total)', () async {
      // A linha da venda guarda `subtotal`; a da OS, `total`. Ler a coluna errada
      // mostraria R$ 0,00 em cada item.
      await semearVenda(id: '9', total: '150.00', itens: [
        {
          'id': 'i1',
          'name': 'Palheta',
          'kind': 'product',
          'quantity': '2',
          'unit_price': '75.00',
          'subtotal': '150.00',
        },
      ]);
      final d = await repo(online: false).titlesOf('c1');
      expect(d.items.single.items.single.name, 'Palheta');
      expect(d.items.single.items.single.total, 150);
    });

    test('venda parcial mostra quanto falta', () async {
      await semearVenda(id: '9', total: '150.00', recebido: '50.00');
      final d = await repo(online: false).titlesOf('c1');
      expect(d.items.single.status, 'parcial');
      expect(d.items.single.paid, 50);
      expect(d.items.single.balance, 100);
    });
  });

  group('filtros offline usam a MESMA regra do servidor', () {
    test('vencidos devolve só quem passou do prazo COMBINADO', () async {
      // Ana: prazo combinado e descumprido. É o prazo que decide, não a idade
      // da dívida — por isso a OS dela também tem parcela, só que vencida.
      await semear(
        osId: '1',
        total: '100.00',
        clienteId: 'c1',
        clienteNome: 'Ana',
        criada: '2020-01-01T10:00:00Z',
      );
      await gravar('receivable_installment', {
        'id': 'p1',
        'sale_kind': 'os',
        'sale_id': '1',
        'due_date': '2020-02-01',
        'paid_at': null,
      });
      // Bruno: OS com parcela local futura ⇒ NÃO vencida.
      await semear(
        osId: '2',
        total: '200.00',
        clienteId: 'c2',
        clienteNome: 'Bruno',
        criada: '2026-07-20T10:00:00Z',
      );
      await gravar('receivable_installment', {
        'id': 'p2',
        'sale_kind': 'os',
        'sale_id': '2',
        'due_date': '2099-01-01',
        'paid_at': null,
      });

      // Carlos: dívida VELHA e sem prazo combinado — não é atraso, ninguém
      // combinou data. Antes ele entraria aqui só por ser antigo.
      await semear(
        osId: '3',
        total: '300.00',
        clienteId: 'c3',
        clienteNome: 'Carlos',
        criada: '2019-01-01T10:00:00Z',
      );

      final page = await repo(online: false).listDebtors(
        const DebtorsQuery(vencimento: VencimentoFiltro.vencidos),
      );
      expect(page.items.map((d) => d.customerName), ['Ana']);

      // E ele continua na carteira, só que sem vencimento.
      final todos = await repo(online: false).listDebtors(const DebtorsQuery());
      final carlos =
          todos.items.firstWhere((d) => d.customerName == 'Carlos');
      expect(carlos.nextDueAt, isNull);
      expect(carlos.overdue, isFalse);
    });

    test('busca por apelido sem acento acha "Célia" com "celia"', () async {
      await semear(osId: '1', total: '80.00', clienteId: null, clienteNome: 'Célia');
      final page = await repo(online: false).listDebtors(
        const DebtorsQuery(q: 'celia'),
      );
      expect(page.items, hasLength(1));
      expect(page.items.single.customerName, 'Célia');
    });

    test('totalDue não muda ao filtrar (é da carteira inteira)', () async {
      await semear(osId: '1', total: '100.00', clienteId: 'c1', clienteNome: 'Ana');
      await semear(osId: '2', total: '200.00', clienteId: 'c2', clienteNome: 'Bruno');
      final semFiltro = await repo(online: false).listDebtors(const DebtorsQuery());
      final comFiltro = await repo(online: false).listDebtors(
        const DebtorsQuery(q: 'ana'),
      );
      expect(comFiltro.items, hasLength(1));
      expect(comFiltro.totalDue, semFiltro.totalDue);
      expect(comFiltro.totalDue, 300);
    });

    test('OS em a_receber conta como finalizada (antes só concluida/entregue)',
        () async {
      // Sem fiado_at (não passou pelo caixa) e status 'a_receber' com saldo:
      // antes do fix caía em nenhum balde (nem dívida, nem pendente).
      await semear(
        osId: '1',
        total: '100.00',
        status: 'a_receber',
        fiadoAt: null,
      );
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items, isEmpty); // não é fiado: não passou pelo caixa

      final pendentes = await repo(online: false).listPendingSettlement();
      expect(pendentes.items, hasLength(1)); // mas aparece como pendente de acerto
    });
  });


  /// Offline o app lê JSON CRU do espelho (o mesmo payload que o pull gravou).
  /// Campo faltando, tipo trocado ou data inválida não podem derrubar a
  /// carteira: sem rede, esta tela é a única fonte de cobrança que o operador
  /// tem — melhor uma linha a menos do que uma tela de erro.
  group('espelho local com dado sujo não derruba a carteira', () {
    test('linha sem id é ignorada, o resto continua', () async {
      await gravar('sale', {
        'id': 'sem-campos', // o row-store exige id; o RESTO vem faltando
        'fiado_at': '2026-07-10T11:00:00Z',
      });
      await semear(osId: '1', total: '100.00');

      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items.single.totalDue, 100);
    });

    test('total não numérico vira zero, não exceção', () async {
      await gravar('sale', {
        'id': 'v-ruim',
        'number': 'VND-9',
        'status': 'active',
        'customer_id': 'c9',
        'customer_name': 'Estranho',
        'total': 'abc',
        'created_at': '2026-07-15T10:00:00Z',
        'fiado_at': '2026-07-15T11:00:00Z',
      });
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      // Saldo zero não é dívida — a linha some da cobrança, mas a tela vive.
      expect(page.items, isEmpty);
      expect(page.totalDue, 0);
    });

    test('recebimento com valor sujo não inventa nem apaga dívida', () async {
      await semear(osId: '1', total: '300.00');
      await gravar('cash_entry', {
        'id': 'e-sujo',
        'direction': 'in',
        'amount': 'xx',
        'method': 'dinheiro',
        'category': 'os_payment',
        'sale_kind': 'os',
        'sale_id': '1',
        'reversed_at': null,
        'created_at': '2026-07-10T12:00:00Z',
      });
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items.single.totalDue, 300);
    });

    test('parcela com due_date inválido não quebra a classificação', () async {
      await semear(osId: '1', total: '100.00');
      await gravar('receivable_installment', {
        'id': 'p-ruim',
        'sale_kind': 'os',
        'sale_id': '1',
        'due_date': 'nao-e-data',
        'paid_at': null,
      });
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items, hasLength(1));
      // Data ilegível não vira atraso: acusar vencimento por lixo de dado seria
      // pior do que não acusar nada.
      expect(page.items.single.overdue, isFalse);
    });

    test('parcela PAGA não define o vencimento; a em aberto define', () async {
      await semear(osId: '1', total: '200.00');
      await gravar('receivable_installment', {
        'id': 'p1',
        'sale_kind': 'os',
        'sale_id': '1',
        'due_date': '2020-01-01',
        'paid_at': '2020-01-02T10:00:00Z',
      });
      await gravar('receivable_installment', {
        'id': 'p2',
        'sale_kind': 'os',
        'sale_id': '1',
        'due_date': '2099-01-01',
        'paid_at': null,
      });
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items.single.nextDueAt, '2099-01-01');
      expect(page.items.single.overdue, isFalse);
    });

    test('entre várias em aberto, vale a MAIS PRÓXIMA', () async {
      await semear(osId: '1', total: '300.00');
      for (final d in ['2099-05-01', '2098-01-01', '2099-01-01']) {
        await gravar('receivable_installment', {
          'id': 'p-$d',
          'sale_kind': 'os',
          'sale_id': '1',
          'due_date': d,
          'paid_at': null,
        });
      }
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items.single.nextDueAt, '2098-01-01');
    });

    test('parcela de VENDA não vira vencimento de OS de mesmo id', () async {
      // `sale_kind` faz parte da chave justamente por isto: os ids vivem em
      // tabelas diferentes e podem coincidir.
      await semear(osId: 'x', total: '100.00', clienteId: 'c1', clienteNome: 'Ana');
      await gravar('receivable_installment', {
        'id': 'p-venda',
        'sale_kind': 'sale',
        'sale_id': 'x', // MESMO id, outra origem
        'due_date': '2020-01-01',
        'paid_at': null,
      });
      final page = await repo(online: false).listDebtors(const DebtorsQuery());
      expect(page.items.single.nextDueAt, isNull);
      expect(page.items.single.overdue, isFalse);
    });

    test('carteira grande continua paginando certo', () async {
      for (var i = 0; i < 25; i++) {
        await semear(
          osId: 'os$i',
          total: '${10 * (i + 1)}.00',
          clienteId: 'c$i',
          clienteNome: 'Cliente $i',
        );
      }
      final p1 = await repo(online: false)
          .listDebtors(const DebtorsQuery(pageSize: 20));
      final p2 = await repo(online: false)
          .listDebtors(const DebtorsQuery(page: 2, pageSize: 20));
      expect(p1.items, hasLength(20));
      expect(p2.items, hasLength(5));
      expect(p1.total, 25);
      // Ninguém repetido entre páginas.
      final nomes = [...p1.items, ...p2.items].map((d) => d.customerName);
      expect(nomes.toSet().length, 25);
    });
  });

  group('receber offline abate a dívida na hora', () {
    test('lançamento feito pelo caixa offline some da carteira', () async {
      // O usuário cobra o cliente na oficina sem internet: o recebimento entra
      // pelo LocalFirstCashierRepository e a carteira — derivada das MESMAS
      // linhas locais — tem de refletir isso sem esperar o sync.
      await semear(osId: '1', total: '300.00');
      expect((await repo(online: false).listDebtors(const DebtorsQuery())).items.single.totalDue, 300);

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

      final page = await repo(online: false).listDebtors(const DebtorsQuery());
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

      expect((await repo(online: false).listDebtors(const DebtorsQuery())).items, isEmpty);
    });
  });
}
