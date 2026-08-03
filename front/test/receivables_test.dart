import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/receivables/data/fake_receivables_repository.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_tab.dart';

/// Aba "Fiado" — controle de contas a receber.
///
/// A tela responde, nesta ordem: quanto a oficina tem na rua, quem deve, e de
/// quais serviços é a dívida. Os dois primeiros são o agregado; o terceiro exige
/// abrir o cliente.

Widget _app(ReceivablesRepositoryOverride override, {bool canWrite = true}) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(_OnlineConn.new),
      receivablesRepositoryProvider.overrideWithValue(override.repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: ReceivablesTab(canWrite: canWrite)),
    ),
  );
}

/// Açúcar para deixar claro no teste qual carteira está em jogo.
class ReceivablesRepositoryOverride {
  ReceivablesRepositoryOverride(this.repo);
  final FakeReceivablesRepository repo;
}

/// Online por padrão: sem isto a tela mostra o aviso "Fiado precisa de conexão"
/// (o estado inicial do controller não é `online`).
class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

void main() {
  group('carteira de fiado', () {
    testWidgets('mostra o total na rua e quantos clientes devem',
        (tester) async {
      await tester.pumpWidget(
        _app(ReceivablesRepositoryOverride(FakeReceivablesRepository())),
      );
      await tester.pumpAndSettle();

      // Exemplo do fake: João 480+200 = 680; Maria 150. Total 830.
      expect(find.text('A receber'), findsOneWidget);
      expect(find.text('R\$ 830,00'), findsOneWidget);
      expect(find.text('de 2 clientes'), findsOneWidget);
    });

    testWidgets('lista devedores do maior saldo para o menor', (tester) async {
      await tester.pumpWidget(
        _app(ReceivablesRepositoryOverride(FakeReceivablesRepository())),
      );
      await tester.pumpAndSettle();

      final joao = tester.getTopLeft(find.text('João Silva')).dy;
      final maria = tester.getTopLeft(find.text('Maria Souza')).dy;
      expect(joao, lessThan(maria), reason: 'quem deve mais aparece primeiro');
    });

    testWidgets('soma OS e vendas do mesmo cliente num saldo só',
        (tester) async {
      await tester.pumpWidget(
        _app(ReceivablesRepositoryOverride(FakeReceivablesRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('R\$ 680,00'), findsOneWidget); // 480 + 200
      expect(find.textContaining('2 títulos'), findsOneWidget);
    });

    testWidgets('carteira vazia ensina o que apareceria ali', (tester) async {
      await tester.pumpWidget(
        _app(ReceivablesRepositoryOverride(
          FakeReceivablesRepository(titulos: const []),
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum fiado em aberto'), findsOneWidget);
    });

    testWidgets('avisa quando a lista está parcial (nunca cap silencioso)',
        (tester) async {
      await tester.pumpWidget(
        _app(ReceivablesRepositoryOverride(
          FakeReceivablesRepository(truncated: true),
        )),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('parcial'), findsOneWidget);
    });
  });

  group('títulos de um cliente', () {
    testWidgets('abre os títulos separados com os itens de cada',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(ReceivablesRepositoryOverride(FakeReceivablesRepository())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('João Silva'));
      await tester.pumpAndSettle();

      // Os dois títulos, cada um com seu número...
      expect(find.text('OS-0042'), findsOneWidget);
      expect(find.text('OS-0051'), findsOneWidget);
      // ...e o que foi vendido em cada (a pergunta "de quais serviços?").
      expect(find.text('Troca de óleo'), findsOneWidget);
      expect(find.text('4× Óleo 5W30'), findsOneWidget);
      expect(find.text('Alinhamento'), findsOneWidget);
    });

    testWidgets('título parcial mostra quanto já foi pago', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(ReceivablesRepositoryOverride(FakeReceivablesRepository())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('João Silva'));
      await tester.pumpAndSettle();

      expect(find.text('Parcial'), findsOneWidget);
      // OS-0051: total 300, pago 100 → deve 200.
      expect(find.text('Deve R\$ 200,00'), findsOneWidget);
      expect(
        find.textContaining('já pagou R\$ 100,00'),
        findsOneWidget,
      );
    });

    testWidgets('sem cashier.write não oferece receber', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          ReceivablesRepositoryOverride(FakeReceivablesRepository()),
          canWrite: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('João Silva'));
      await tester.pumpAndSettle();

      expect(find.text('Receber'), findsNothing);
    });
  });

  group('regras do agregado (fake espelha o servidor)', () {
    test('só conta o saldo em aberto, não o total do título', () async {
      final repo = FakeReceivablesRepository();
      final page = await repo.listDebtors();
      final joao = page.items.firstWhere((d) => d.customerName == 'João Silva');
      // OS-0042 deve 480 (total 480) + OS-0051 deve 200 (total 300) = 680.
      expect(joao.totalDue, 680);
      expect(joao.titleCount, 2);
    });

    test('guarda a data do título mais antigo', () async {
      final repo = FakeReceivablesRepository();
      final page = await repo.listDebtors();
      final joao = page.items.firstWhere((d) => d.customerName == 'João Silva');
      expect(joao.oldestAt, '2026-07-02T10:00:00Z');
    });

    test('títulos de um cliente vêm do mais antigo para o mais novo', () async {
      final repo = FakeReceivablesRepository();
      final d = await repo.titlesOf('c1');
      expect(d.items.map((t) => t.number), ['OS-0042', 'OS-0051']);
      expect(d.totalDue, 680);
    });

    test('cliente sem dívida devolve lista vazia', () async {
      final repo = FakeReceivablesRepository();
      final d = await repo.titlesOf('inexistente');
      expect(d.items, isEmpty);
      expect(d.totalDue, 0);
    });
  });

  group('modelos', () {
    test('ReceivableTitle desserializa o payload do servidor', () {
      final t = ReceivableTitle.fromJson(const {
        'id': 'x',
        'origin': 'sale',
        'number': '15',
        'createdAt': '2026-07-25T09:00:00Z',
        'total': 150,
        'paid': 50,
        'balance': 100,
        'status': 'parcial',
        'items': [
          {
            'name': 'Palheta',
            'kind': 'product',
            'quantity': 2,
            'unitPrice': 75,
            'total': 150,
          },
        ],
      });
      expect(t.balance, 100);
      expect(t.status, 'parcial');
      expect(t.items.single.unitPrice, 75);
    });

    test('DebtorsPage tolera payload mínimo', () {
      final p = DebtorsPage.fromJson(const {'items': []});
      expect(p.items, isEmpty);
      expect(p.totalDue, 0);
      expect(p.truncated, isFalse);
    });
  });

  group('offline — carteira derivada do SQLite', () {
    testWidgets('avisa que a lista é parcial e diz o motivo certo',
        (tester) async {
      // Offline o `LocalFirstReceivablesRepository` deriva a carteira do espelho
      // local (OS + recebimentos) e marca `truncated`, porque venda de balcão
      // não está no sync. O aviso precisa dizer ESSE motivo — não o de carteira
      // grande — senão o usuário procura um problema que não existe.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Sem override de conectividade: o estado inicial não é `online`.
            receivablesRepositoryProvider.overrideWithValue(
              FakeReceivablesRepository(truncated: true),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ReceivablesTab(canWrite: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A carteira APARECE (não é mais bloqueio) ...
      expect(find.text('João Silva'), findsOneWidget);
      // ... e o aviso explica o recorte offline.
      expect(find.textContaining('cobre as OS'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
