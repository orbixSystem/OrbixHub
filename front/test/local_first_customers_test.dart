import 'dart:convert';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/customers/data/local_first_customers_repository.dart';
import 'package:orbixhub_front/features/customers/domain/customers_models.dart';

/// B8 — repository LocalFirst de Clientes (referência do padrão). `LocalDb` real
/// em memória (mesma costura do B5/B7) + o `FakeCustomersRepository` como impl
/// embrulhada. Cobre: create/list/update offline (row-store + outbox), leitura
/// online (passthrough + espelho) e o método online-only ("Requer conexão").
LocalDb _memDb() => LocalDb(NativeDatabase.memory());

void main() {
  late LocalDb db;
  late FakeCustomersRepository fake;
  var online = false;
  var nudges = 0;

  LocalFirstCustomersRepository repo() => LocalFirstCustomersRepository(
        inner: fake,
        db: db,
        clock: TrustedClock(clock: () => DateTime.utc(2026, 7, 13)),
        isOnline: () => online,
        currentUserId: () => 'user-1',
        onWrite: () => nudges++,
      );

  setUp(() {
    db = _memDb();
    fake = FakeCustomersRepository();
    online = false;
    nudges = 0;
  });

  tearDown(() => db.close());

  Future<List<Map<String, dynamic>>> rowsOf(String entity) async => [
        for (final r in await db.rowsOf(entity))
          jsonDecode(r.payload) as Map<String, dynamic>,
      ];

  test('offline create: grava no row-store, enfileira 1 mutação e devolve o uuid do cliente',
      () async {
    final customer =
        await repo().createCustomer(const CustomerDraft(name: 'Maria', phone: '9999'));

    expect(customer.name, 'Maria');
    expect(customer.id, isNotEmpty);
    expect(customer.status, 'active');

    final rows = await rowsOf('customer');
    expect(rows, hasLength(1));
    expect(rows.single['id'], customer.id);

    final outbox = await db.pendingFor('user-1');
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'customer');
    expect(outbox.single.op, 'create');
    expect(outbox.single.authorUserId, 'user-1');
    expect(
      (jsonDecode(outbox.single.payload) as Map<String, dynamic>)['id'],
      customer.id,
    );
    expect(nudges, 1);
  });

  test('offline list: devolve o que foi criado localmente e filtra pela busca',
      () async {
    final r = repo();
    await r.createCustomer(const CustomerDraft(name: 'Maria'));
    await r.createCustomer(const CustomerDraft(name: 'João'));

    final all = await r.listCustomers();
    expect(all.total, 2);
    expect(all.items.map((c) => c.name), containsAll(['Maria', 'João']));

    final busca = await r.listCustomers(q: 'mar');
    expect(busca.items.single.name, 'Maria');
  });

  test('offline update de um cliente criado local: row-store reflete + 2ª entrada no outbox',
      () async {
    final r = repo();
    final created = await r.createCustomer(const CustomerDraft(name: 'Maria'));

    final updated = await r.updateCustomer(
      created.id,
      const CustomerDraft(name: 'Maria Silva', phone: '1234'),
    );

    expect(updated.name, 'Maria Silva');
    expect(updated.phone, '1234');

    final rows = await rowsOf('customer');
    expect(rows.single['name'], 'Maria Silva');

    final outbox = await db.pendingFor('user-1');
    expect(outbox, hasLength(2));
    expect(outbox.last.op, 'update');
    expect(
      (jsonDecode(outbox.last.payload) as Map<String, dynamic>)['id'],
      created.id,
    );
  });

  test('offline archive: status vira archived e some da lista de ativos', () async {
    final r = repo();
    final created = await r.createCustomer(const CustomerDraft(name: 'Maria'));
    await r.archiveCustomer(created.id);

    expect((await r.listCustomers()).total, 0);
    expect((await r.listCustomers(status: 'archived')).total, 1);
    final outbox = await db.pendingFor('user-1');
    expect(outbox.last.op, 'archive');
  });

  test('online read: passthrough para a impl real E espelha no row-store', () async {
    online = true;
    final r = repo();
    await r.createCustomer(const CustomerDraft(name: 'Do servidor'));

    // O create online foi para a impl real (sem outbox) e espelhado.
    expect(await db.pendingFor('user-1'), isEmpty);

    final page = await r.listCustomers();
    expect(page.items.single.name, 'Do servidor');

    final rows = await rowsOf('customer');
    expect(rows.single['name'], 'Do servidor');

    // E agora, offline, a lista sai do espelho.
    online = false;
    final offlinePage = await r.listCustomers();
    expect(offlinePage.items.single.name, 'Do servidor');
  });

  test('offline: lookup (FIPE) lança AppException "Requer conexão"', () async {
    await expectLater(
      repo().lookup('fipe.marcas'),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          startsWith('Requer conexão'),
        ),
      ),
    );
  });

  test('offline: setSubjectPhoto lança "Requer conexão"', () async {
    await expectLater(
      repo().setSubjectPhoto(
        'sub-1',
        bytes: const [1, 2, 3],
        filename: 'a.jpg',
        contentType: 'image/jpeg',
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('offline createSubject: aponta para o cliente e enfileira subject.create',
      () async {
    final r = repo();
    final customer = await r.createCustomer(const CustomerDraft(name: 'Maria'));
    final subject = await r.createSubject(
      customer.id,
      const SubjectDraft(identifier: 'ABC1D23'),
    );

    expect(subject.customerId, customer.id);
    final page = await r.listSubjects(customerId: customer.id);
    expect(page.items.single.identifier, 'ABC1D23');

    final outbox = await db.pendingFor('user-1');
    expect(outbox.last.entity, 'subject');
    expect(outbox.last.op, 'create');
    final payload = jsonDecode(outbox.last.payload) as Map<String, dynamic>;
    expect(payload['customerId'], customer.id);
    expect(payload['id'], subject.id);
  });
}
