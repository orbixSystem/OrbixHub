import 'dart:convert';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/data/local_first_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';

/// B8 — repository LocalFirst do Caixa: sessão por ponto (deviceId), lançamentos
/// otimistas + outbox, resumos derivados do espelho e o método online-only.
LocalDb _memDb() => LocalDb(NativeDatabase.memory());

void main() {
  late LocalDb db;
  late FakeCashierRepository fake;
  var online = false;
  var nudges = 0;

  LocalFirstCashierRepository repo() => LocalFirstCashierRepository(
        inner: fake,
        deviceId: () async => 'device-1',
        db: db,
        clock: TrustedClock(clock: () => DateTime.utc(2026, 7, 13)),
        isOnline: () => online,
        currentUserId: () => 'user-1',
        onWrite: () => nudges++,
      );

  setUp(() {
    db = _memDb();
    fake = FakeCashierRepository();
    online = false;
    nudges = 0;
  });

  tearDown(() => db.close());

  test('offline openSession: row-store + outbox cash_session.open com deviceId',
      () async {
    final r = repo();
    final session = await r.openSession(openingAmount: 100);

    expect(session.status, 'open');
    expect(session.openingAmount, '100.00');

    final outbox = await db.pendingFor('user-1');
    expect(outbox.single.entity, 'cash_session');
    expect(outbox.single.op, 'open');
    expect(outbox.single.authorUserId, 'user-1');
    final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(payload['id'], session.id);
    expect(payload['deviceId'], 'device-1');
    expect(nudges, 1);

    // A sessão corrente sai do espelho, filtrada pelo ponto de caixa.
    final current = await r.currentSession();
    expect(current!.id, session.id);
  });

  test('offline createEntry: direção derivada da categoria + outbox cash_entry.create',
      () async {
    final r = repo();
    await r.openSession(openingAmount: 0);

    final entry = await r.createEntry(
      const EntryDraft(amount: 50, method: 'dinheiro', category: 'os_payment'),
    );
    expect(entry.direction, 'in');
    expect(entry.amount, '50.00');

    final saida = await r.createEntry(
      const EntryDraft(amount: 20, method: 'dinheiro', category: 'sangria'),
    );
    expect(saida.direction, 'out');

    final outbox = await db.pendingFor('user-1');
    expect(outbox.map((m) => '${m.entity}.${m.op}'), [
      'cash_session.open',
      'cash_entry.create',
      'cash_entry.create',
    ]);

    // Totais correntes da sessão vêm dos lançamentos locais.
    final current = await r.currentSession();
    expect(current!.totals!.inTotal, 50);
    expect(current.totals!.outTotal, 20);
    expect(current.totals!.expected, 30);

    // Extrato local.
    final page = await r.listEntries();
    expect(page.total, 2);
    expect((await r.listEntries(direction: 'out')).items.single.id, saida.id);
  });

  test('offline reverseEntry: marca reversedAt e sai dos somatórios', () async {
    final r = repo();
    await r.openSession(openingAmount: 0);
    final entry = await r.createEntry(
      const EntryDraft(amount: 50, method: 'pix', category: 'os_payment'),
    );

    final reversed = await r.reverseEntry(entry.id, 'erro de digitação');
    expect(reversed.reversedAt, isNotNull);

    final outbox = await db.pendingFor('user-1');
    expect(outbox.last.op, 'reverse');

    final current = await r.currentSession();
    expect(current!.totals!.inTotal, 0);
    final summary = await r.summary();
    expect(summary.totalIn, 0);
  });

  test('offline closeSession: calcula esperado/diferença e fecha a sessão local',
      () async {
    final r = repo();
    await r.openSession(openingAmount: 100);
    await r.createEntry(
      const EntryDraft(amount: 50, method: 'dinheiro', category: 'os_payment'),
    );

    final closed = await r.closeSession(countedAmount: 140);
    expect(closed.status, 'closed');
    expect(closed.closingAmountExpected, '150.00');
    expect(closed.difference, '-10.00');
    expect(await r.currentSession(), isNull);

    final outbox = await db.pendingFor('user-1');
    expect(outbox.last.op, 'close');
  });

  test('offline paymentSummary: saldo derivado dos recebimentos locais', () async {
    final r = repo();
    await r.openSession(openingAmount: 0);
    await r.createEntry(
      const EntryDraft(
        amount: 30,
        method: 'pix',
        category: 'os_payment',
        saleKind: 'os',
        saleId: 'os-1',
      ),
    );

    final detail = await r.paymentSummary(
      saleKind: 'os',
      saleId: 'os-1',
      total: 100,
    );
    expect(detail.paid, 30);
    expect(detail.balance, 70);
    expect(detail.status, 'parcial');
    expect(detail.entries, hasLength(1));
  });

  test('online read: passthrough + espelho no row-store', () async {
    online = true;
    final r = repo();
    final session = await r.openSession(openingAmount: 10);
    expect(await db.pendingFor('user-1'), isEmpty);
    expect(await db.rowsOf('cash_session'), hasLength(1));

    await r.createEntry(
      const EntryDraft(amount: 5, method: 'pix', category: 'os_payment'),
    );
    final page = await r.listEntries();
    expect(page.total, 1);
    expect(await db.rowsOf('cash_entry'), hasLength(1));

    // Offline, o extrato sai do espelho.
    online = false;
    expect((await r.listEntries()).total, 1);
    expect(session.status, 'open');
  });

  test('offline: filtro por data com `to` só-data inclui o último dia', () async {
    final r = repo();
    await r.openSession(openingAmount: 0);
    await r.createEntry(
      const EntryDraft(amount: 40, method: 'dinheiro', category: 'os_payment'),
    );

    // O lançamento é de 2026-07-13; um `to` data-pura desse mesmo dia deve
    // incluí-lo (fim do dia), não descartá-lo.
    final page = await r.listEntries(from: '2026-07-01', to: '2026-07-13');
    expect(page.total, 1);
    final resumo = await r.summary(from: '2026-07-01', to: '2026-07-13');
    expect(resumo.totalIn, 40);

    // E um período que termina antes não traz nada.
    expect((await r.listEntries(to: '2026-07-12')).total, 0);
  });

  test('offline: updateConfig lança AppException "Requer conexão"', () async {
    await expectLater(
      repo().updateConfig(countCashOnly: false),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          startsWith('Requer conexão'),
        ),
      ),
    );
  });

  test('offline: lançar sem caixa aberto avisa (não enfileira)', () async {
    await expectLater(
      repo().createEntry(
        const EntryDraft(amount: 10, method: 'pix', category: 'os_payment'),
      ),
      throwsA(isA<AppException>()),
    );
    expect(await db.pendingFor('user-1'), isEmpty);
  });
}
