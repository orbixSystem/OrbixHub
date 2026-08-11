import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/features/expenses/data/fake_expenses_repository.dart';
import 'package:orbixhub_front/features/expenses/data/local_first_expenses_repository.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_models.dart';

/// Lixeira das despesas: excluir (soft), listar, restaurar e apagar de vez.
///
/// O que estes testes travam é o ALCANCE: numa compra parcelada, excluir e
/// restaurar valem para o grupo INTEIRO. Excluir a 3ª de 6 sozinha deixava as
/// irmãs para trás e o total da compra encolhia sem ninguém pedir.
LocalDb _memDb() => LocalDb(NativeDatabase.memory());

void main() {
  final agora = DateTime.utc(2026, 8, 15);

  group('fake (o contrato que a tela enxerga)', () {
    late FakeExpensesRepository fake;

    // O fake nasce SEMEADO (é o mesmo que desenhou a tela), então nada aqui
    // afirma sobre a lista inteira — só sobre as contas que o teste criou.
    setUp(() => fake = FakeExpensesRepository(hoje: agora));

    Future<List<Expense>> criarParcelada() async {
      final primeira = await fake.criar(
        const ExpenseDraft(
          description: 'Compressor',
          amount: 900,
          dueDate: '2026-08-10',
          parcelas: 6,
        ),
      );
      return (await fake.detalhe(primeira.id)).parcelas;
    }

    /// Ids do grupo presentes na lista do mês (em qualquer mês da compra).
    Future<Set<String>> naListaEmAgosto(Iterable<String> ids) async {
      final mes = await fake.listarMes(ano: 2026, mes: 8);
      return mes.items.map((e) => e.id).where(ids.contains).toSet();
    }

    test('excluir uma parcela leva a compra INTEIRA para a lixeira', () async {
      final parcelas = await criarParcelada();
      expect(parcelas, hasLength(6));
      final ids = parcelas.map((p) => p.id).toSet();

      // Exclui pela 3ª, não pela 1ª: o alcance é o grupo inteiro, não "desta
      // para a frente".
      await fake.cancelar(parcelas[2].id);

      expect(
        await naListaEmAgosto(ids),
        isEmpty,
        reason: 'nenhuma parcela da compra pode sobrar na lista',
      );
      for (final p in parcelas) {
        expect((await fake.detalhe(p.id)).expense.status, 'canceled');
      }
    });

    test('a compra excluída aparece na lixeira', () async {
      final parcelas = await criarParcelada();
      await fake.cancelar(parcelas.first.id);

      final lixeira = await fake.listarExcluidas(ano: 2026, mes: 8);
      // Só a que vence em agosto — as outras 5 caem nos meses seguintes.
      expect(lixeira.items.map((e) => e.id), contains(parcelas.first.id));
      expect(lixeira.items.every((e) => e.status == 'canceled'), isTrue);
    });

    test('restaurar devolve a compra inteira para a lista', () async {
      final parcelas = await criarParcelada();
      final ids = parcelas.map((p) => p.id).toSet();
      await fake.cancelar(parcelas.first.id);
      expect(await naListaEmAgosto(ids), isEmpty);

      await fake.restaurar(parcelas[3].id);

      expect(await naListaEmAgosto(ids), contains(parcelas.first.id));
      for (final p in parcelas) {
        expect((await fake.detalhe(p.id)).expense.status, 'active');
      }
    });

    test('apagar de vez remove as linhas — não volta mais', () async {
      final parcelas = await criarParcelada();
      await fake.cancelar(parcelas.first.id);

      await fake.excluirDeVez(parcelas.first.id);

      final lixeira = await fake.listarExcluidas(ano: 2026, mes: 8);
      expect(lixeira.items.map((e) => e.id), isNot(contains(parcelas.first.id)));
      // Some de verdade: nem o detalhe encontra mais, nem as irmãs sobraram.
      for (final p in parcelas) {
        await expectLater(fake.detalhe(p.id), throwsA(isA<AppException>()));
      }
    });

    test('conta avulsa: excluir mexe só nela', () async {
      final a = await fake.criar(
        const ExpenseDraft(
          description: 'Aluguel do galpão',
          amount: 2500,
          dueDate: '2026-08-05',
        ),
      );
      final b = await fake.criar(
        const ExpenseDraft(
          description: 'Energia do galpão',
          amount: 300,
          dueDate: '2026-08-20',
        ),
      );

      await fake.cancelar(a.id);

      expect(await naListaEmAgosto({a.id, b.id}), {b.id});
      final lixeira = await fake.listarExcluidas(ano: 2026, mes: 8);
      expect(lixeira.items.map((e) => e.id), contains(a.id));
      expect(lixeira.items.map((e) => e.id), isNot(contains(b.id)));
    });

    test('os totais do mês IGNORAM o que está na lixeira', () async {
      // "Quanto tenho a pagar" não muda por causa do que foi excluído — somar o
      // lixo faria a previsão de gasto mentir.
      final antes = (await fake.listarMes(ano: 2026, mes: 8)).totalPrevisto;

      final a = await fake.criar(
        const ExpenseDraft(
          description: 'Aluguel do galpão',
          amount: 2500,
          dueDate: '2026-08-05',
        ),
      );
      expect((await fake.listarMes(ano: 2026, mes: 8)).totalPrevisto,
          antes + 2500);

      await fake.cancelar(a.id);

      expect((await fake.listarMes(ano: 2026, mes: 8)).totalPrevisto, antes);
    });
  });

  group('offline (a lixeira exige rede)', () {
    late LocalDb db;
    late FakeExpensesRepository fake;
    var online = false;

    LocalFirstExpensesRepository repo() => LocalFirstExpensesRepository(
          inner: fake,
          db: db,
          clock: TrustedClock(clock: () => agora),
          isOnline: () => online,
          currentUserId: () => 'user-1',
        );

    setUp(() {
      db = _memDb();
      fake = FakeExpensesRepository(hoje: agora);
      online = false;
    });

    tearDown(() => db.close());

    test('listar a lixeira sem rede falha com mensagem clara', () async {
      // O espelho local não guarda canceladas (a exclusão remove a linha), então
      // não há o que mostrar offline. Falhar explicando é melhor que uma lista
      // vazia que parece "não tem nada excluído".
      await expectLater(
        repo().listarExcluidas(ano: 2026, mes: 8),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('conexão'),
          ),
        ),
      );
    });

    test('restaurar sem rede falha', () async {
      await expectLater(
        repo().restaurar('qualquer-id'),
        throwsA(isA<AppException>()),
      );
    });

    test('apagar de vez sem rede falha', () async {
      await expectLater(
        repo().excluirDeVez('qualquer-id'),
        throwsA(isA<AppException>()),
      );
    });

    test('online, as três delegam para o servidor', () async {
      online = true;
      final r = repo();
      final criada = await r.criar(
        const ExpenseDraft(
          description: 'Aluguel',
          amount: 2500,
          dueDate: '2026-08-05',
        ),
      );

      await r.cancelar(criada.id);
      final lixeira = await r.listarExcluidas(ano: 2026, mes: 8);
      expect(lixeira.items.map((e) => e.id), contains(criada.id));

      await r.restaurar(criada.id);
      expect((await r.listarExcluidas(ano: 2026, mes: 8)).items, isEmpty);
    });
  });
}
