import 'dart:convert';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/features/expenses/data/fake_expenses_repository.dart';
import 'package:orbixhub_front/features/expenses/data/local_first_expenses_repository.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_models.dart';

/// Despesas offline-first.
///
/// Era a única feature do app fora da camada offline — e contas a pagar é
/// justamente o que se consulta no balcão, no celular, com rede ruim.
///
/// A regra mais importante que estes testes protegem: **dar baixa offline NÃO
/// cria o lançamento no caixa localmente**. Quem cria é o servidor no replay;
/// inventar um espelho local geraria DOIS lançamentos e o livro caixa mentiria.
LocalDb _memDb() => LocalDb(NativeDatabase.memory());

void main() {
  late LocalDb db;
  late FakeExpensesRepository fake;
  var online = false;

  final agora = DateTime.utc(2026, 8, 15);

  LocalFirstExpensesRepository repo() => LocalFirstExpensesRepository(
        inner: fake,
        db: db,
        clock: TrustedClock(clock: () => agora),
        isOnline: () => online,
        currentUserId: () => 'user-1',
      );

  setUp(() {
    db = _memDb();
    fake = FakeExpensesRepository();
    online = false;
  });

  tearDown(() => db.close());

  /// Ops enfileiradas no outbox, na ordem.
  Future<List<({String entity, String op, Map<String, dynamic> payload})>>
      fila() async {
    final ms = await db.pendingFor('user-1');
    return [
      for (final m in ms)
        (
          entity: m.entity,
          op: m.op,
          payload: jsonDecode(m.payload) as Map<String, dynamic>,
        ),
    ];
  }

  test('online: listarMes espelha contas e categorias para uso offline',
      () async {
    online = true;
    await repo().criar(
      const ExpenseDraft(
        description: 'Aluguel',
        amount: 2500,
        dueDate: '2026-08-10T00:00:00.000Z',
      ),
    );
    final r = repo();
    await r.listarMes(ano: 2026, mes: 8);

    // Agora offline, o mês tem de abrir do espelho.
    online = false;
    final local = await r.listarMes(ano: 2026, mes: 8);
    expect(local.items.any((e) => e.description == 'Aluguel'), isTrue);
    expect(local.categories, isNotEmpty);
  });

  test('offline: criar vai para o outbox e aparece na lista na hora', () async {
    final r = repo();
    final criada = await r.criar(
      const ExpenseDraft(
        description: 'Internet',
        amount: 120,
        dueDate: '2026-08-20T00:00:00.000Z',
      ),
    );

    final f = await fila();
    expect(f.single.entity, 'expense');
    expect(f.single.op, 'create');
    // O uuid viaja NO payload: o replay preserva o id gerado offline.
    expect(f.single.payload['id'], criada.id);

    final mes = await r.listarMes(ano: 2026, mes: 8);
    expect(mes.items.single.description, 'Internet');
    expect(mes.totalEmAberto, 120);
  });

  test('offline: totais do mês são DERIVADOS (servidor não somou)', () async {
    final r = repo();
    await r.criar(const ExpenseDraft(
      description: 'vencida',
      amount: 300,
      dueDate: '2026-08-05T00:00:00.000Z',
    ));
    await r.criar(const ExpenseDraft(
      description: 'futura',
      amount: 200,
      dueDate: '2026-08-28T00:00:00.000Z',
    ));

    final mes = await r.listarMes(ano: 2026, mes: 8);
    expect(mes.totalPrevisto, 500);
    expect(mes.totalEmAberto, 500);
    // "hoje" é 15/08 pelo relógio confiável.
    expect(mes.totalVencido, 300);
  });

  test('offline: dar baixa NÃO cria lançamento de caixa local', () async {
    final r = repo();
    final c = await r.criar(const ExpenseDraft(
      description: 'Luz',
      amount: 180,
      dueDate: '2026-08-10T00:00:00.000Z',
    ));
    final paga = await r.marcarPaga(c.id, valor: 180, forma: 'pix');

    expect(paga.paidAt, isNotNull);
    expect(paga.paidAmount, 180);
    // A ligação com o caixa fica NULA até o replay: quem cria o `cash_entry` é o
    // servidor. Um espelho local aqui geraria dois lançamentos.
    expect(paga.cashEntryId, isNull);

    final ops = (await fila()).map((m) => m.op).toList();
    expect(ops, ['create', 'pay']);
  });

  test('offline: desmarcar paga devolve para em aberto e enfileira unpay',
      () async {
    final r = repo();
    final c = await r.criar(const ExpenseDraft(
      description: 'Água',
      amount: 90,
      dueDate: '2026-08-12T00:00:00.000Z',
    ));
    await r.marcarPaga(c.id);
    final aberta = await r.desmarcarPaga(c.id);

    expect(aberta.paidAt, isNull);
    expect(aberta.paidAmount, isNull);
    expect((await fila()).last.op, 'unpay');

    final mes = await r.listarMes(ano: 2026, mes: 8);
    expect(mes.totalPago, 0);
    expect(mes.totalEmAberto, 90);
  });

  test('offline: excluir tira da lista JÁ (não espera o sync)', () async {
    final r = repo();
    final c = await r.criar(const ExpenseDraft(
      description: 'Erro',
      amount: 10,
      dueDate: '2026-08-10T00:00:00.000Z',
    ));
    await r.cancelar(c.id);

    final mes = await r.listarMes(ano: 2026, mes: 8);
    expect(mes.items, isEmpty);
    expect((await fila()).last.op, 'cancel');
  });

  test('offline: editar altera o espelho e enfileira update', () async {
    final r = repo();
    final c = await r.criar(const ExpenseDraft(
      description: 'Contador',
      amount: 400,
      dueDate: '2026-08-10T00:00:00.000Z',
    ));
    final editada = await r.editar(c.id, const ExpenseDraft(amount: 450));

    expect(editada.amount, 450);
    expect(editada.description, 'Contador', reason: 'patch não apaga o resto');
    expect((await fila()).last.op, 'update');
  });

  test('offline: criar categoria entra na lista local e no outbox', () async {
    final r = repo();
    final cat = await r.criarCategoria(name: 'Seguro', icon: 'outros');
    expect(cat.name, 'Seguro');

    final f = await fila();
    expect(f.single.entity, 'expense_category');
    expect(f.single.op, 'create');

    final cats = await r.categorias();
    expect(cats.any((c) => c.name == 'Seguro'), isTrue);
  });

  test('offline: parcelado cria N linhas locais mas UMA op na fila', () async {
    final r = repo();
    await r.criar(const ExpenseDraft(
      description: 'Compressor',
      amount: 100, // total; o rateio é 33,34 + 33,33 + 33,33
      dueDate: '2026-08-10T00:00:00.000Z',
      parcelas: 3,
    ));

    // Uma op só: o grupo nasce inteiro ou não nasce. Três ops poderiam aplicar
    // duas e falhar a terceira, deixando meia compra parcelada.
    final f = await fila();
    expect(f, hasLength(1));
    expect(f.single.op, 'create');
    expect(f.single.payload['parcelas'], 3);

    // Os ids viajam no payload: sem isso o servidor geraria OUTROS 3 no replay e
    // o pull seguinte mostraria 6 parcelas de uma compra em 3x.
    final ids = (f.single.payload['installmentIds'] as List).cast<String>();
    expect(ids, hasLength(3));
    expect(f.single.payload['installmentGroupId'], isNotNull);
    // O id da op é o da PRIMEIRA parcela (a linha que a tela acabou de mostrar).
    expect(f.single.payload['id'], ids.first);

    final mes = await r.listarMes(ano: 2026, mes: 8);
    expect(mes.items.single.rotuloParcela, '1/3',
        reason: 'só a 1ª parcela vence em agosto');
    expect(mes.items.single.amount, 33.34, reason: 'resto na primeira');

    // As outras duas existem no espelho, nos meses seguintes.
    expect((await r.listarMes(ano: 2026, mes: 9)).items.single.amount, 33.33);
    expect((await r.listarMes(ano: 2026, mes: 10)).items.single.rotuloParcela,
        '3/3');
  });

  test('offline: detalhe monta do espelho (conta + irmãs), sem rede', () async {
    final r = repo();
    final primeira = await r.criar(const ExpenseDraft(
      description: 'Compressor',
      amount: 900,
      dueDate: '2026-08-10T00:00:00.000Z',
      parcelas: 3,
    ));

    final d = await r.detalhe(primeira.id);
    expect(d.expense.id, primeira.id);
    expect(d.parcelas, hasLength(3));
    // Total é a SOMA das irmãs — não existe coluna de total, de propósito.
    expect(d.totalParcelado, 900);
    expect(d.parcelas.map((p) => p.installmentNo), [1, 2, 3]);
  });

  test('mês sem nada offline devolve zeros, não erro', () async {
    final mes = await repo().listarMes(ano: 2026, mes: 12);
    expect(mes.items, isEmpty);
    expect(mes.totalPrevisto, 0);
  });
}
