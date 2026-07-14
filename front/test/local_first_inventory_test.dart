import 'dart:convert';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/data/local_first_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/domain/inventory_models.dart';

/// B8 — repository LocalFirst do Estoque. Mesma costura do teste de Clientes.
LocalDb _memDb() => LocalDb(NativeDatabase.memory());

void main() {
  late LocalDb db;
  late FakeInventoryRepository fake;
  var online = false;
  var nudges = 0;

  LocalFirstInventoryRepository repo() => LocalFirstInventoryRepository(
        inner: fake,
        db: db,
        clock: TrustedClock(clock: () => DateTime.utc(2026, 7, 13)),
        isOnline: () => online,
        currentUserId: () => 'user-1',
        onWrite: () => nudges++,
      );

  setUp(() {
    db = _memDb();
    fake = FakeInventoryRepository();
    online = false;
    nudges = 0;
  });

  tearDown(() => db.close());

  test('offline create: row-store + outbox (inventory_item.create) com o uuid do cliente',
      () async {
    final item = await repo().createItem(
      const ItemDraft(name: 'Filtro de óleo', sku: 'FIL-01', salePrice: 30),
    );

    expect(item.name, 'Filtro de óleo');
    expect(item.salePrice, '30.00');
    expect(await db.rowsOf('inventory_item'), hasLength(1));

    final outbox = await db.pendingFor('user-1');
    expect(outbox.single.entity, 'inventory_item');
    expect(outbox.single.op, 'create');
    expect(outbox.single.authorUserId, 'user-1');
    expect(
      (jsonDecode(outbox.single.payload) as Map<String, dynamic>)['id'],
      item.id,
    );
    expect(nudges, 1);
  });

  test('offline list: devolve o item local e filtra pela busca', () async {
    final r = repo();
    await r.createItem(const ItemDraft(name: 'Filtro de óleo'));
    await r.createItem(const ItemDraft(name: 'Pastilha de freio'));

    expect((await r.listItems()).total, 2);
    final busca = await r.listItems(q: 'pastilha');
    expect(busca.items.single.name, 'Pastilha de freio');
  });

  test('offline update de item criado local: espelho reflete + 2ª entrada no outbox',
      () async {
    final r = repo();
    final created = await r.createItem(const ItemDraft(name: 'Filtro'));

    final updated = await r.updateItem(
      created.id,
      const ItemDraft(name: 'Filtro premium', salePrice: 45),
    );
    expect(updated.name, 'Filtro premium');
    expect(updated.salePrice, '45.00');
    expect((await r.getItem(created.id)).name, 'Filtro premium');

    final outbox = await db.pendingFor('user-1');
    expect(outbox, hasLength(2));
    expect(outbox.last.op, 'update');
  });

  test('online read: passthrough + espelho no row-store', () async {
    online = true;
    final r = repo();
    await r.createItem(const ItemDraft(name: 'Do servidor'));
    expect(await db.pendingFor('user-1'), isEmpty);

    final page = await r.listItems();
    expect(page.items.single.name, 'Do servidor');
    expect(await db.rowsOf('inventory_item'), hasLength(1));

    online = false;
    expect((await r.listItems()).items.single.name, 'Do servidor');
  });

  test('offline lookup: acha pelo código local; sem match, "Requer conexão"',
      () async {
    final r = repo();
    await r.createItem(const ItemDraft(name: 'Filtro', barcode: '789123'));

    final hit = await r.lookup('789123');
    expect(hit.source, 'internal');
    expect(hit.item!.name, 'Filtro');

    await expectLater(
      r.lookup('000000'),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          startsWith('Requer conexão'),
        ),
      ),
    );
  });

  test('offline lowStock + suggestSku locais', () async {
    final r = repo();
    await r.createItem(
      const ItemDraft(name: 'Filtro', currentStock: 1, minStock: 2),
    );
    await r.createItem(
      const ItemDraft(name: 'Óleo', currentStock: 10, minStock: 2),
    );

    final low = await r.lowStock();
    expect(low.single.name, 'Filtro');
    expect(await r.suggestSku('Pastilha'), 'PASTILHA');
  });
}
