import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_screen.dart';
import 'package:orbixhub_front/features/receivables/data/fake_receivables_repository.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_providers.dart';

/// "A receber" no Caixa é INFORMAÇÃO que leva ao detalhe, não um botão de ação.
///
/// Era um cartão no grid junto de "Venda avulsa" e "Receber OS": os dois
/// resolvem ali mesmo num modal, e ele teleportava para outra tela — um cartão
/// que ensina a coisa errada sobre os vizinhos. Como resumo, ele ainda cumpre o
/// que faltava: saber quanto se tem na rua sem sair do Caixa.

class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

class _Dono extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
          role: 'owner',
          permissions: ['cashier.read', 'cashier.write', 'sale.write'],
          modules: ['cashier', 'sale'],
        ),
      );
}

/// Sem `cashier.read` não há carteira para resumir.
class _SemCarteira extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u2', email: 'c@b.c', fullName: 'Caixa'),
          role: 'caixa',
          permissions: ['cashier.write'],
          modules: ['cashier'],
        ),
      );
}

Future<void> _abrir(
  WidgetTester tester, {
  required FakeReceivablesRepository carteira,
  bool comCarteira = true,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final caixa = FakeCashierRepository();
  await caixa.updateConfig(requireOpenSession: false);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectivityControllerProvider.overrideWith(_OnlineConn.new),
        sessionControllerProvider
            .overrideWith(comCarteira ? _Dono.new : _SemCarteira.new),
        cashierRepositoryProvider.overrideWithValue(caixa),
        saleRepositoryProvider.overrideWithValue(FakeSaleRepository()),
        receivablesRepositoryProvider.overrideWithValue(carteira),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CashierScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra quanto há na rua sem sair do Caixa', (tester) async {
    // Exemplo do fake: João 680 + Maria 150 = 830, em 2 clientes.
    await _abrir(tester, carteira: FakeReceivablesRepository());

    expect(find.textContaining('R\$ 830,00'), findsOneWidget);
    expect(find.textContaining('2 clientes'), findsOneWidget);
  });

  testWidgets('sem nada vencido, não fala de vencimento', (tester) async {
    await _abrir(
      tester,
      carteira: FakeReceivablesRepository(titulos: const [
        ReceivableTitle(
          id: 'x1',
          origin: 'sale',
          number: 'VND-1',
          customerId: 'c1',
          customerName: 'João Silva',
          total: 100,
          balance: 100,
        ),
      ]),
    );
    expect(find.textContaining('vencido'), findsNothing);
  });

  testWidgets('com prazo descumprido, o resumo destaca o vencido',
      (tester) async {
    await _abrir(
      tester,
      carteira: FakeReceivablesRepository(
        titulos: const [
          ReceivableTitle(
            id: 'x1',
            origin: 'sale',
            number: 'VND-1',
            customerId: 'c1',
            customerName: 'João Silva',
            total: 100,
            balance: 100,
          ),
        ],
        vencimentos: {'x1': '2020-01-10'}, // combinado e descumprido
      ),
    );
    expect(find.textContaining('vencido'), findsOneWidget);
  });

  testWidgets('sem cashier.read o resumo não aparece', (tester) async {
    await _abrir(
      tester,
      carteira: FakeReceivablesRepository(),
      comCarteira: false,
    );
    expect(find.textContaining('R\$ 830,00'), findsNothing);
  });
}
