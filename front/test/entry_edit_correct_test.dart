import 'dart:convert';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/data/local_first_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/presentation/entry_edit_dialogs.dart';

/// **Editar** × **corrigir** um lançamento — inclusive offline.
///
/// A regra: o livro caixa não sobrescreve dinheiro. Descrição e categoria de
/// mesma direção são edição; valor e forma são correção (estorna + relança).
/// Trocar despesa (saída) por suprimento (entrada) mudaria o saldo sem registro,
/// e é recusado no cliente — não só no servidor, senão o usuário só descobriria
/// o erro depois de sincronizar.

LocalDb _memDb() => LocalDb(NativeDatabase.memory());

void main() {
  group('categorias oferecidas na edição (mesma direção)', () {
    test('saída só oferece saídas', () {
      expect(categoriasDaMesmaDirecao('despesa'), ['despesa', 'sangria']);
      expect(categoriasDaMesmaDirecao('sangria'), ['despesa', 'sangria']);
    });

    test('entrada só oferece entradas', () {
      final entradas = categoriasDaMesmaDirecao('os_payment');
      expect(entradas, contains('suprimento'));
      expect(entradas, isNot(contains('despesa')));
      expect(entradas, isNot(contains('sangria')));
    });
  });

  group('offline', () {
    late LocalDb db;
    late FakeCashierRepository fake;
    var online = false;

    LocalFirstCashierRepository repo() => LocalFirstCashierRepository(
          inner: fake,
          deviceId: () async => 'device-1',
          db: db,
          clock: TrustedClock(clock: () => DateTime.utc(2026, 8, 3, 15)),
          isOnline: () => online,
          currentUserId: () => 'u1',
        );

    Future<void> semearDespesa({String? estornadoEm}) => db.upsertRows(
          'cash_entry',
          [
            (
              id: 'e1',
              payload: jsonEncode({
                'id': 'e1',
                'cash_session_id': 's1',
                'direction': 'out',
                'amount': '50.00',
                'method': 'pix',
                'category': 'despesa',
                'description': 'Oleo do fornecedor',
                'sale_kind': null,
                'sale_id': null,
                'reversed_at': estornadoEm,
                'created_at': '2026-08-03T12:00:00Z',
              }),
              updatedAt: DateTime.utc(2026, 8, 3, 12),
            ),
          ],
        );

    setUp(() {
      db = _memDb();
      fake = FakeCashierRepository();
      online = false;
    });

    tearDown(() => db.close());

    test('editar descrição enfileira cash_entry.update e não muda o valor',
        () async {
      await semearDespesa();
      final editado =
          await repo().updateEntry('e1', description: 'Oleo 5W30 - nota 123');

      expect(editado.description, 'Oleo 5W30 - nota 123');
      expect(editado.amount, '50.00', reason: 'editar não mexe em dinheiro');

      final outbox = await db.pendingFor('u1');
      expect('${outbox.single.entity}.${outbox.single.op}', 'cash_entry.update');
    });

    test('editar aceita despesa → sangria (ambas saída)', () async {
      await semearDespesa();
      final editado = await repo().updateEntry('e1', category: 'sangria');
      expect(editado.category, 'sangria');
    });

    test('editar RECUSA despesa → suprimento (inverte a direção)', () async {
      await semearDespesa();
      await expectLater(
        repo().updateEntry('e1', category: 'suprimento'),
        throwsA(isA<AppException>()
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
      // E não deixa lixo na fila para o servidor recusar depois.
      expect(await db.pendingFor('u1'), isEmpty);
    });

    test('editar RECUSA lançamento estornado', () async {
      await semearDespesa(estornadoEm: '2026-08-03T13:00:00Z');
      await expectLater(
        repo().updateEntry('e1', description: 'x'),
        throwsA(isA<AppException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('corrigir estorna o original e cria o novo, numa op só', () async {
      await semearDespesa();
      final novo = await repo()
          .correctEntry('e1', reason: 'valor errado', amount: 45);

      expect(novo.amount, '45.00');
      expect(novo.id, isNot('e1'));
      expect(novo.category, 'despesa');
      expect(novo.method, 'pix');
      expect(novo.direction, 'out', reason: 'a direção segue a categoria');

      // UMA mutação: `reverse` + `create` separadas poderiam falhar no meio e
      // deixar o caixa com dinheiro duplicado ou estorno sem contrapartida.
      final outbox = await db.pendingFor('u1');
      expect(outbox, hasLength(1));
      expect('${outbox.single.entity}.${outbox.single.op}',
          'cash_entry.correct');
      final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;
      expect(payload['id'], 'e1', reason: 'aponta o original');
      expect(payload['newId'], novo.id, reason: 'uuid do novo, gerado aqui');
      expect(payload['reason'], 'valor errado');
    });

    test('o original fica estornado no espelho, com o motivo', () async {
      await semearDespesa();
      await repo().correctEntry('e1', reason: 'valor errado', amount: 45);

      final page = await repo().listEntries();
      final original = page.items.firstWhere((e) => e.id == 'e1');
      expect(original.reversedAt, isNotNull);
      expect(original.amount, '50.00', reason: 'o valor errado NÃO é apagado');
      // Os dois convivem: é isso que faz o caixa fechar.
      expect(page.items.map((e) => e.amount), containsAll(['50.00', '45.00']));
    });

    test('corrigir RECUSA o que já foi estornado', () async {
      await semearDespesa(estornadoEm: '2026-08-03T13:00:00Z');
      await expectLater(
        repo().correctEntry('e1', reason: 'tarde demais'),
        throwsA(isA<AppException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('online delega ao servidor (nada de outbox)', () async {
      online = true;
      // O fake exige sessão aberta para lançar (espelha o servidor com a
      // exigência ligada).
      await fake.openSession(openingAmount: 0);
      final criado = await fake.createEntry(
        const EntryDraft(amount: 10, method: 'dinheiro', category: 'despesa'),
      );
      await repo().updateEntry(criado.id, description: 'no servidor');
      expect(await db.pendingFor('u1'), isEmpty);
    });
  });
}
