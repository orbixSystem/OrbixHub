import 'dart:convert';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/sync_engine.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/sale/data/local_first_sale_repository.dart';
import 'package:orbixhub_front/features/sale/domain/sale_models.dart';

/// Venda de balcão OFFLINE — o caso "preciso vender agora e a internet caiu".
///
/// A venda vive no espelho + outbox (`sale.create`); o servidor decide o número
/// e a baixa de estoque no replay. Estes testes fixam o que o cliente PODE
/// decidir sozinho (itens, total, desconto, pagamento derivado do caixa) e o que
/// ele NÃO deve tentar adivinhar.

LocalDb _memDb() => LocalDb(NativeDatabase.memory());

void main() {
  late LocalDb db;
  late FakeSaleRepository fake;
  var online = false;
  var nudges = 0;

  LocalFirstSaleRepository repo() => LocalFirstSaleRepository(
        inner: fake,
        db: db,
        clock: TrustedClock(clock: () => DateTime.utc(2026, 7, 20, 14)),
        isOnline: () => online,
        currentUserId: () => 'u1',
        onWrite: () => nudges++,
      );

  Future<void> gravar(String entity, Map<String, dynamic> payload) =>
      db.upsertRows(entity, [
        (
          id: payload['id'] as String,
          payload: jsonEncode(payload),
          updatedAt: DateTime.utc(2026, 7, 20),
        ),
      ]);

  setUp(() {
    db = _memDb();
    fake = FakeSaleRepository();
    online = false;
    nudges = 0;
  });

  tearDown(() => db.close());

  group('observação da venda', () {
    // A cliente escreve ali quem levou / a placa do veículo quando o comprador
    // não é cadastrado ("venda rápida, uma luz, paga na hora"). O texto ia só
    // para o extrato do caixa e não voltava em lugar nenhum — agora é da venda,
    // e é o que sai no comprovante.
    test('offline: fica no espelho e viaja no payload da mutação', () async {
      final venda = await repo().createSale(const SaleDraft(
        description: 'Trator Massey nº 4292 — levou o rapaz do sítio',
        items: [
          SaleItemDraft(name: 'Bateria', kind: 'product', quantity: 1, unitPrice: 250),
        ],
      ));
      expect(venda.description, 'Trator Massey nº 4292 — levou o rapaz do sítio');

      final payload =
          jsonDecode((await db.pendingFor('u1')).single.payload)
              as Map<String, dynamic>;
      expect(payload['description'], 'Trator Massey nº 4292 — levou o rapaz do sítio');

      // Sobrevive à releitura do espelho (não era só o retorno da chamada).
      expect((await repo().getSale(venda.id)).description, isNotNull);
    });

    test('offline: editar troca o texto e enfileira sale.update', () async {
      final venda = await repo().createSale(const SaleDraft(
        description: 'texto errado',
        items: [
          SaleItemDraft(name: 'Bateria', kind: 'product', quantity: 1, unitPrice: 250),
        ],
      ));
      final editada =
          await repo().updateSale(venda.id, description: 'Placa GDY8B74');
      expect(editada.description, 'Placa GDY8B74');
    });

    test('offline: string vazia APAGA a observação', () async {
      // Corrigir um texto errado é tão legítimo quanto escrevê-lo — e é por isso
      // que a chave vazia não pode ser confundida com "não mexe".
      final venda = await repo().createSale(const SaleDraft(
        description: 'anotação a remover',
        items: [
          SaleItemDraft(name: 'Bateria', kind: 'product', quantity: 1, unitPrice: 250),
        ],
      ));
      final limpa = await repo().updateSale(venda.id, description: '');
      expect(limpa.description, isNull);
    });

    test('venda sem observação continua sem o campo no payload', () async {
      await repo().createSale(const SaleDraft(items: [
        SaleItemDraft(name: 'Palheta', kind: 'product', quantity: 1, unitPrice: 40),
      ]));
      final payload =
          jsonDecode((await db.pendingFor('u1')).single.payload)
              as Map<String, dynamic>;
      expect(payload.containsKey('description'), isFalse);
    });
  });

  group('criar venda offline', () {
    test('grava no espelho e enfileira sale.create com o uuid do cliente',
        () async {
      final venda = await repo().createSale(const SaleDraft(items: [
        SaleItemDraft(name: 'Palheta', kind: 'product', quantity: 2, unitPrice: 40),
      ]));

      expect(venda.total, '80.00');
      expect(venda.items.single.name, 'Palheta');

      final outbox = await db.pendingFor('u1');
      expect(outbox.single.entity, 'sale');
      expect(outbox.single.op, 'create');
      final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;
      // O id vai NO PAYLOAD (o DTO do backend declara `id`) — é assim que a
      // venda mantém identidade depois do replay.
      expect(payload['id'], venda.id);
      expect(nudges, 1, reason: 'o SyncEngine tem de ser cutucado');
    });

    test('número provisório VND-P e contador local', () async {
      final r = repo();
      final v1 = await r.createSale(const SaleDraft(
        items: [SaleItemDraft(name: 'A', quantity: 1, unitPrice: 10)],
      ));
      final v2 = await r.createSale(const SaleDraft(
        items: [SaleItemDraft(name: 'B', quantity: 1, unitPrice: 10)],
      ));
      expect(v1.number, 'VND-P1');
      expect(v2.number, 'VND-P2');
    });

    test('desconto abate o total e é clampado ao bruto', () async {
      final r = repo();
      final comDesconto = await r.createSale(const SaleDraft(
        discount: 15,
        items: [SaleItemDraft(name: 'A', quantity: 1, unitPrice: 100)],
      ));
      expect(comDesconto.total, '85.00');
      expect(comDesconto.discount, '15.00');

      // Desconto maior que a venda não pode virar total negativo (o servidor
      // clampa igual — ver `applySaleDiscount`).
      final exagerado = await r.createSale(const SaleDraft(
        discount: 500,
        items: [SaleItemDraft(name: 'B', quantity: 1, unitPrice: 100)],
      ));
      expect(exagerado.total, '0.00');
      expect(exagerado.discount, '100.00');
    });

    test('soma várias linhas com quantidade fracionada', () async {
      final venda = await repo().createSale(const SaleDraft(items: [
        SaleItemDraft(name: 'Óleo', quantity: 2.5, unitPrice: 32),
        SaleItemDraft(name: 'Filtro', quantity: 1, unitPrice: 45),
      ]));
      expect(venda.total, '125.00'); // 2.5×32 + 45
      expect(venda.items, hasLength(2));
    });

    test('online NÃO enfileira: vai direto no servidor', () async {
      online = true;
      await repo().createSale(const SaleDraft(
        items: [SaleItemDraft(name: 'A', quantity: 1, unitPrice: 10)],
      ));
      expect(await db.pendingFor('u1'), isEmpty);
    });
  });

  group('pagamento derivado do caixa (a venda não guarda quanto pagou)', () {
    /// Semeia uma venda do servidor e um recebimento no caixa.
    Future<void> vendaComRecebimento(String? recebido) async {
      await gravar('sale', {
        'id': 's1',
        'number': 'VND-0007',
        'status': 'active',
        'total': '200.00',
        'discount': '0',
        'created_at': '2026-07-20T10:00:00Z',
      });
      if (recebido != null) {
        await gravar('cash_entry', {
          'id': 'e1',
          'direction': 'in',
          'amount': recebido,
          'method': 'dinheiro',
          'category': 'sale_payment',
          'sale_kind': 'sale',
          'sale_id': 's1',
          'reversed_at': null,
          'created_at': '2026-07-20T11:00:00Z',
        });
      }
    }

    test('sem recebimento → a_receber (é o fiado de balcão)', () async {
      await vendaComRecebimento(null);
      expect((await repo().getSale('s1')).paymentStatus, 'a_receber');
    });

    test('recebimento parcial → parcial', () async {
      await vendaComRecebimento('50.00');
      expect((await repo().getSale('s1')).paymentStatus, 'parcial');
    });

    test('recebimento integral → pago', () async {
      await vendaComRecebimento('200.00');
      expect((await repo().getSale('s1')).paymentStatus, 'pago');
    });

    test('resíduo de centavo já conta como pago (mesmo EPS do backend)',
        () async {
      await vendaComRecebimento('199.999');
      expect((await repo().getSale('s1')).paymentStatus, 'pago');
    });

    test('estorno devolve a venda para a_receber', () async {
      await vendaComRecebimento('200.00');
      await gravar('cash_entry', {
        'id': 'e1',
        'direction': 'in',
        'amount': '200.00',
        'method': 'dinheiro',
        'category': 'sale_payment',
        'sale_kind': 'sale',
        'sale_id': 's1',
        'reversed_at': '2026-07-20T12:00:00Z',
        'created_at': '2026-07-20T11:00:00Z',
      });
      expect((await repo().getSale('s1')).paymentStatus, 'a_receber');
    });

    test('venda cancelada não pergunta o caixa', () async {
      await vendaComRecebimento('200.00');
      await gravar('sale', {
        'id': 's1',
        'number': 'VND-0007',
        'status': 'canceled',
        'total': '200.00',
        'created_at': '2026-07-20T10:00:00Z',
      });
      expect((await repo().getSale('s1')).paymentStatus, 'cancelada');
    });
  });

  group('histórico offline', () {
    Future<void> semear() async {
      for (final (id, num_, cliente, total, criada, status) in [
        ('s1', 'VND-0001', 'Ana', '100.00', '2026-07-01T10:00:00Z', 'active'),
        ('s2', 'VND-0002', 'Bruno', '250.00', '2026-07-15T10:00:00Z', 'active'),
        ('s3', 'VND-0003', 'Ana', '70.00', '2026-07-20T10:00:00Z', 'canceled'),
      ]) {
        await gravar('sale', {
          'id': id,
          'number': num_,
          'customer_name': cliente,
          'customer_id': cliente == 'Ana' ? 'c1' : 'c2',
          'status': status,
          'total': total,
          'created_at': criada,
        });
      }
    }

    test('mais recente primeiro (mesma ordem do servidor)', () async {
      await semear();
      final page = await repo().listSales();
      expect(page.items.map((s) => s.number), ['VND-0003', 'VND-0002', 'VND-0001']);
      expect(page.total, 3);
    });

    test('filtra por status', () async {
      await semear();
      final page = await repo().listSales(status: 'canceled');
      expect(page.items.single.number, 'VND-0003');
    });

    test('filtra por cliente', () async {
      await semear();
      final page = await repo().listSales(customerId: 'c1');
      expect(page.items.map((s) => s.number), ['VND-0003', 'VND-0001']);
    });

    test('busca por número OU nome do cliente, sem caso', () async {
      await semear();
      expect((await repo().listSales(q: 'bruno')).items.single.number,
          'VND-0002');
      expect((await repo().listSales(q: 'VND-0001')).items.single.number,
          'VND-0001');
      expect((await repo().listSales(q: 'inexistente')).items, isEmpty);
    });

    test('recorta por período', () async {
      await semear();
      final page = await repo().listSales(
        from: '2026-07-10T00:00:00Z',
        to: '2026-07-16T00:00:00Z',
      );
      expect(page.items.single.number, 'VND-0002');
    });

    test('venda criada offline aparece no histórico com seus itens', () async {
      final criada = await repo().createSale(const SaleDraft(items: [
        SaleItemDraft(name: 'Palheta', quantity: 1, unitPrice: 40),
      ]));
      final page = await repo().listSales();
      final achada = page.items.firstWhere((s) => s.id == criada.id);
      expect(achada.number, 'VND-P1');
      expect(achada.items.single.name, 'Palheta');
    });
  });

  group('cancelar offline', () {
    test('marca cancelada e enfileira sale.cancel com o motivo', () async {
      await gravar('sale', {
        'id': 's1',
        'number': 'VND-0001',
        'status': 'active',
        'total': '100.00',
        'created_at': '2026-07-20T10:00:00Z',
      });
      final v = await repo().cancelSale('s1', reason: 'cliente desistiu');
      expect(v.status, 'canceled');

      final outbox = await db.pendingFor('u1');
      expect('${outbox.single.entity}.${outbox.single.op}', 'sale.cancel');
      final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;
      expect(payload['id'], 's1');
      expect(payload['reason'], 'cliente desistiu');
    });

    test('cancelar duas vezes dá 409 aqui, não uma falha só no replay',
        () async {
      await gravar('sale', {
        'id': 's1',
        'number': 'VND-0001',
        'status': 'canceled',
        'total': '100.00',
        'created_at': '2026-07-20T10:00:00Z',
      });
      await expectLater(
        repo().cancelSale('s1'),
        throwsA(isA<AppException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
      expect(await db.pendingFor('u1'), isEmpty);
    });
  });

  group('o que NÃO funciona offline (e falha com mensagem clara)', () {
    test('emitir nota exige conexão', () async {
      await expectLater(
        repo().emitInvoice('s1'),
        throwsA(isA<AppException>()
            .having((e) => e.message, 'message', contains('Requer conexão'))),
      );
    });

    test('emitir nota de venda ainda na fila avisa que falta sincronizar',
        () async {
      final criada = await repo().createSale(const SaleDraft(
        items: [SaleItemDraft(name: 'A', quantity: 1, unitPrice: 10)],
      ));
      online = true;
      await expectLater(
        repo().emitInvoice(criada.id),
        throwsA(isA<AppException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', contains('sincronizad'))),
      );
    });
  });

  group('reconciliação com o servidor', () {
    test('itens locais são podados quando a cópia do servidor chega', () async {
      // Cria offline (item com uuid local), depois "sincroniza": o servidor
      // recria o item com OUTRO id. Sem a poda, o detalhe mostraria 2 itens.
      final criada = await repo().createSale(const SaleDraft(items: [
        SaleItemDraft(name: 'Palheta', quantity: 1, unitPrice: 40),
      ]));
      expect((await repo().getSale(criada.id)).items, hasLength(1));

      // O engine confirma a mutação e o pull traz a venda oficial.
      for (final m in await db.pendingFor('u1')) {
        await db.markOutbox(m.clientMutationId, 'applied');
      }
      online = true;
      fake = FakeSaleRepository(sales: [
        Sale(
          id: criada.id,
          number: 'VND-0009',
          total: '40.00',
          items: const [
            SaleItem(id: 'servidor-1', name: 'Palheta', quantity: '1',
                unitPrice: '40.00', subtotal: '40.00'),
          ],
        ),
      ]);

      final doServidor = await repo().getSale(criada.id);
      expect(doServidor.number, 'VND-0009');
      expect(doServidor.items, hasLength(1),
          reason: 'o item local tem de ser podado, não somado ao do servidor');
      expect(doServidor.items.single.id, 'servidor-1');
    });

    test('venda criada offline sobrevive à volta da rede na listagem',
        () async {
      final criada = await repo().createSale(const SaleDraft(
        items: [SaleItemDraft(name: 'A', quantity: 1, unitPrice: 10)],
      ));
      online = true; // servidor ainda não conhece esta venda
      final page = await repo().listSales();
      expect(page.items.map((s) => s.id), contains(criada.id));
    });
  });

  test('sale e sale_item estão nas entidades replicadas', () {
    // Sem isto o pull nunca traria a venda e o espelho ficaria só com o que
    // este aparelho criou.
    expect(SyncEngine.entities, containsAll(['sale', 'sale_item']));
  });
}
