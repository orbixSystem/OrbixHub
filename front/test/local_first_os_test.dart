import 'dart:convert';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/data/local_first_os_repository.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';

/// B8 — repository LocalFirst da OS: número provisório `OS-P<n>` offline, itens
/// otimistas + outbox, fotos como BLOB pendente (S6) e os métodos online-only.
LocalDb _memDb() => LocalDb(NativeDatabase.memory());

void main() {
  late LocalDb db;
  late FakeOsRepository fake;
  var online = false;

  LocalFirstOsRepository repo() => LocalFirstOsRepository(
        inner: fake,
        db: db,
        clock: TrustedClock(clock: () => DateTime.utc(2026, 7, 13)),
        isOnline: () => online,
        currentUserId: () => 'user-1',
      );

  setUp(() {
    db = _memDb();
    fake = FakeOsRepository(
      customers: const [CustomerOption(id: 'cus-1', name: 'Maria')],
    );
    online = false;
  });

  tearDown(() => db.close());

  Future<ServiceOrder> createOffline(LocalFirstOsRepository r) =>
      r.createOrder(const OrderDraft(customerId: 'cus-1', complaint: 'Barulho'));

  test('offline create: número provisório OS-P1, row-store + outbox service_order.create',
      () async {
    final r = repo();
    final order = await createOffline(r);

    expect(order.number, 'OS-P1');
    expect(order.status, 'aberta');
    expect(order.customerId, 'cus-1');
    expect(order.events, isNotEmpty); // evento 'created' local

    final outbox = await db.pendingFor('user-1');
    expect(outbox.single.entity, 'service_order');
    expect(outbox.single.op, 'create');
    expect(outbox.single.authorUserId, 'user-1');
    expect(
      (jsonDecode(outbox.single.payload) as Map<String, dynamic>)['id'],
      order.id,
    );

    // A 2ª OS offline pega o próximo número provisório.
    final second = await createOffline(r);
    expect(second.number, 'OS-P2');
  });

  test('offline create com cliente novo: enfileira customer.create ANTES da OS',
      () async {
    final r = repo();
    final order = await r.createOrder(
      const OrderDraft(
        newCustomerName: 'João',
        newCustomerPhone: '9999',
        newSubjectIdentifier: 'ABC1D23',
      ),
    );

    expect(order.customerName, 'João');
    final outbox = await db.pendingFor('user-1');
    expect(
      outbox.map((m) => '${m.entity}.${m.op}'),
      ['customer.create', 'subject.create', 'service_order.create'],
    );
    expect(order.subjectId, isNotNull);
  });

  test('offline list + getOrder: saem do row-store', () async {
    final r = repo();
    final order = await createOffline(r);

    final page = await r.listOrders();
    expect(page.total, 1);
    expect(page.items.single.number, 'OS-P1');

    final fetched = await r.getOrder(order.id);
    expect(fetched.complaint, 'Barulho');
  });

  test('offline addItem: item otimista, total recalculado e outbox cresce',
      () async {
    final r = repo();
    final order = await createOffline(r);

    final updated = await r.addItem(
      order.id,
      const OrderItemDraft(kind: 'service', name: 'Troca de óleo',
          quantity: 2, unitPrice: 50),
    );

    expect(updated.items.single.name, 'Troca de óleo');
    expect(updated.total, '100.00');

    final outbox = await db.pendingFor('user-1');
    expect(outbox.last.op, 'addItem');
    expect(
      (jsonDecode(outbox.last.payload) as Map<String, dynamic>)['id'],
      order.id,
    );
  });

  test('offline changeStatus: status local + evento + outbox', () async {
    final r = repo();
    final order = await createOffline(r);
    final updated = await r.changeStatus(order.id, 'em_execucao');

    expect(updated.status, 'em_execucao');
    final outbox = await db.pendingFor('user-1');
    expect(outbox.last.op, 'changeStatus');
    expect((await r.getOrder(order.id)).status, 'em_execucao');
  });

  test('offline addPhoto: BLOB em pendingUploads + foto otimista na OS', () async {
    final r = repo();
    final order = await createOffline(r);

    final updated = await r.addPhoto(
      order.id,
      bytes: const [1, 2, 3, 4],
      filename: 'foto.jpg',
      contentType: 'image/jpeg',
      caption: 'Antes',
    );

    expect(updated.photos.single.caption, 'Antes');

    final uploads = await db.listPendingUploads();
    expect(uploads, hasLength(1));
    expect(uploads.single.orderId, order.id);
    expect(uploads.single.filename, 'foto.jpg');
    expect(uploads.single.bytes, [1, 2, 3, 4]);
  });

  test('online read: passthrough para a impl real E espelha a OS no row-store',
      () async {
    online = true;
    final r = repo();
    final order = await createOffline(r);
    expect(order.number, isNot(startsWith('OS-P')));
    expect(await db.pendingFor('user-1'), isEmpty);

    await r.addItem(order.id, const OrderItemDraft(name: 'Peça', quantity: 1, unitPrice: 10));

    online = false;
    final offline = await r.getOrder(order.id);
    expect(offline.items.single.name, 'Peça');
    expect((await r.listOrders()).total, 1);
  });

  test('offline: emitInvoice / deleteOrder / listMembers lançam "Requer conexão"',
      () async {
    final r = repo();
    final order = await createOffline(r);

    Matcher requerConexao() => throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            startsWith('Requer conexão'),
          ),
        );

    await expectLater(r.emitInvoice(order.id), requerConexao());
    await expectLater(r.deleteOrder(order.id), requerConexao());
    await expectLater(r.listMembers(), requerConexao());
    await expectLater(
      r.createTemplate(const OsTemplateDraft(name: 'Revisão')),
      requerConexao(),
    );
    await expectLater(r.listPhotoComments(order.id, 'p1'), requerConexao());
  });
}
