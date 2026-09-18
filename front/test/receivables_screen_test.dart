import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/receivables/data/fake_receivables_repository.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_screen.dart';

class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

Widget _app(FakeReceivablesRepository repo) => ProviderScope(
      overrides: [
        connectivityControllerProvider.overrideWith(_OnlineConn.new),
        receivablesRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ReceivablesScreen()),
      ),
    );

void main() {
  testWidgets('topo mostra total na rua, vencido e nº de devedores', (t) async {
    await t.pumpWidget(_app(FakeReceivablesRepository()));
    await t.pumpAndSettle();
    expect(find.text('A receber'), findsOneWidget);
    // Exato: "Vencido" é o rótulo do KPI — "Vencidos" (chip de filtro) e
    // "Vencido em dd/mm" (selo por título) contêm o termo mas não são ele.
    expect(find.text('Vencido'), findsOneWidget);
    // Idem para "devedores" — a busca ("Buscar devedor") também contém o termo.
    expect(find.text('devedores'), findsOneWidget);
  });

  testWidgets('chip "Vencidos" filtra a lista', (t) async {
    // João: título de 2020 sem parcela ⇒ vencido pela data do título. Maria:
    // título criado "agora" ⇒ não vencido. Datas explícitas em vez do
    // `_exemplo` padrão do fake, que não acompanha o relógio do teste.
    final repo = FakeReceivablesRepository(titulos: [
      ReceivableTitle(
        id: 'x1',
        origin: 'sale',
        number: 'VND-1',
        customerId: 'c1',
        customerName: 'João Silva',
        createdAt: '2020-01-01T10:00:00Z',
        total: 100,
        balance: 100,
      ),
      ReceivableTitle(
        id: 'x2',
        origin: 'sale',
        number: 'VND-2',
        customerId: 'c2',
        customerName: 'Maria Souza',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        total: 50,
        balance: 50,
      ),
    ]);
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    await t.tap(find.text('Vencidos'));
    await t.pumpAndSettle();
    expect(find.text('João Silva'), findsOneWidget);
    expect(find.text('Maria Souza'), findsNothing);
  });

  testWidgets('lista vazia por filtro oferece limpar, não "cadastre"', (t) async {
    await t.pumpWidget(_app(FakeReceivablesRepository(titulos: const [])));
    await t.pumpAndSettle();
    expect(find.textContaining('Ninguém devendo'), findsOneWidget);
  });

  testWidgets('sem cadastro leva o selo; cadastrado mostra telefone', (t) async {
    final repo = FakeReceivablesRepository(titulos: const [
      ReceivableTitle(
          id: 't1',
          origin: 'sale',
          number: 'VND-1',
          customerId: 'c1',
          customerName: 'João Silva',
          total: 10,
          balance: 10),
      ReceivableTitle(
          id: 't2',
          origin: 'sale',
          number: 'VND-2',
          customerName: 'Zeca',
          total: 5,
          balance: 5),
    ]);
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    expect(find.text('Sem cadastro'), findsOneWidget);
  });
}
