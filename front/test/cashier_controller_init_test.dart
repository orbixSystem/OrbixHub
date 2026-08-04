import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';

/// `LateInitializationError` no caixa.
///
/// O controller guardava as dependências em `late final`, atribuídas no `build`.
/// Quando um método chegava PRIMEIRO — o caso da venda avulsa, que dispara
/// lançamento num provider `autoDispose` recém-criado — a leitura estourava
/// `LateInitializationError` e derrubava o fluxo no meio, com a venda já criada e
/// o recebimento não lançado.
///
/// Agora são getters com cache: inicializam na primeira leitura e não tocam `ref`
/// de novo (a proteção contra "ref after dispose" que motivou o `late` original).
void main() {
  ProviderContainer criar({CashierRepository? repo}) {
    final container = ProviderContainer(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(
          repo ?? FakeCashierRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('lançar SEM esperar o build não estoura LateInitializationError',
      () async {
    final container = criar();
    // Pega o notifier e chama direto, sem `await` no estado — é o que a venda
    // avulsa faz ao concluir.
    final notifier = container.read(cashierControllerProvider.notifier);
    await notifier.addEntry(
      const EntryDraft(
        amount: 50,
        method: 'dinheiro',
        category: 'venda_avulsa',
        description: 'Item avulso',
      ),
    );
    final estado = await container.read(cashierControllerProvider.future);
    expect(estado.entries.any((e) => e.description == 'Item avulso'), isTrue);
  });

  test('duas chamadas em sequência reusam a MESMA dependência (cache)',
      () async {
    // Se cada chamada relesse `ref`, voltaríamos ao erro de "ref after dispose"
    // depois de um await. O cache é o que fecha as duas pontas.
    final repo = FakeCashierRepository();
    final container = criar(repo: repo);
    final notifier = container.read(cashierControllerProvider.notifier);

    await notifier.addEntry(
      const EntryDraft(amount: 10, method: 'pix', category: 'venda_avulsa'),
    );
    await notifier.addEntry(
      const EntryDraft(amount: 20, method: 'pix', category: 'venda_avulsa'),
    );

    final estado = await container.read(cashierControllerProvider.future);
    expect(estado.entries.length, greaterThanOrEqualTo(2));
  });

  test('config default do front NÃO exige caixa aberto', () {
    // A divergência era um bug real: o front tinha `true` como default e o
    // servidor `false`. Quando a config não carregava, o app exigia abertura, a
    // venda era criada e o recebimento falhava com "Abra o caixa antes de
    // lançar" — o "vários outros erros" que vinha depois.
    expect(const CashierConfig().requireOpenSession, isFalse);
  });

  test('config vinda do servidor com `true` legado é aceita sem quebrar',
      () async {
    // O servidor normaliza, mas se um `true` chegar (cache, servidor antigo), o
    // parse não pode falhar — só não deve mais bloquear a tela.
    final cfg = CashierConfig.fromJson(const {
      'paymentMethods': ['pix'],
      'requireOpenSession': true,
      'countCashOnly': true,
    });
    expect(cfg.requireOpenSession, isTrue);
    expect(cfg.paymentMethods, ['pix']);
  });
}
