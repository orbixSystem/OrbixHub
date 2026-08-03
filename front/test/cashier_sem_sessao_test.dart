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
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_screen.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_providers.dart';

/// A cerimônia de abrir/fechar caixa existe para CONFERIR GAVETA de dinheiro.
/// Quem recebe só por Pix/cartão, ou opera sozinho, não tem gaveta para conferir
/// — e para esse caso o backend sempre aceitou lançar sem sessão
/// (`requireOpenSession = false` cria uma sessão implícita).
///
/// A tela ignorava essa config e bloqueava com "Caixa fechado / Abra o caixa",
/// tornando obrigatório um ritual que o servidor não exigia.

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
          permissions: [
            'cashier.read',
            'cashier.write',
            'cashier.manage',
            'sale.read',
            'sale.write',
          ],
          modules: ['cashier', 'sale'],
        ),
      );
}

Future<void> _abrirTela(
  WidgetTester tester, {
  required bool exigeAbertura,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = FakeCashierRepository();
  await repo.updateConfig(requireOpenSession: exigeAbertura);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectivityControllerProvider.overrideWith(_OnlineConn.new),
        sessionControllerProvider.overrideWith(_Dono.new),
        cashierRepositoryProvider.overrideWithValue(repo),
        saleRepositoryProvider.overrideWithValue(FakeSaleRepository()),
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
  group('exigindo abertura (padrão, oficina com gaveta)', () {
    testWidgets('bloqueia e pede para abrir o caixa', (tester) async {
      await _abrirTela(tester, exigeAbertura: true);

      expect(find.text('Caixa fechado'), findsOneWidget);
      expect(find.text('Abrir caixa'), findsOneWidget);
      // Sem sessão não há o que lançar.
      expect(find.text('Receber OS'), findsNothing);
    });
  });

  group('sem exigir abertura (só Pix/cartão, ou dono sozinho)', () {
    testWidgets('opera direto, sem ritual de abertura', (tester) async {
      await _abrirTela(tester, exigeAbertura: false);

      // O bloqueio desaparece...
      expect(find.text('Caixa fechado'), findsNothing);
      // ...e as ações do dia estão disponíveis de imediato.
      expect(find.text('Caixa de hoje'), findsOneWidget);
      expect(find.text('Receber OS'), findsOneWidget);
      expect(find.text('Venda avulsa'), findsOneWidget);
      expect(find.text('Despesa / sangria'), findsOneWidget);
    });

    testWidgets('NÃO oferece conferência de gaveta', (tester) async {
      await _abrirTela(tester, exigeAbertura: false);

      // A config decide, sem meio-caminho: desligada = livro de lançamentos,
      // sem nada de contar gaveta. Quem quer conferência liga a exigência.
      expect(find.text('Conferir gaveta'), findsNothing);
      expect(find.text('Encerrar conferência'), findsNothing);
      expect(find.text('Fechar caixa'), findsNothing);
    });

    testWidgets('mostra os lançamentos do dia', (tester) async {
      await _abrirTela(tester, exigeAbertura: false);
      expect(find.text('Lançamentos de hoje'), findsOneWidget);
    });
  });

  group('sessão implícita não reintroduz a cerimônia', () {
    testWidgets('após lançar, NÃO aparece "Fechar caixa" nem "Aberto desde"',
        (tester) async {
      // Com a exigência desligada o backend cria uma sessão implícita no
      // primeiro lançamento. Se a tela reagir a isso mostrando o fluxo de
      // sessão, o ritual volta pela porta dos fundos.
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = FakeCashierRepository();
      await repo.updateConfig(requireOpenSession: false);
      // Lança algo: o fake abre a sessão implícita, como o backend faz.
      await repo.createEntry(const EntryDraft(
        amount: 50,
        method: 'dinheiro',
        category: 'venda_avulsa',
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityControllerProvider.overrideWith(_OnlineConn.new),
            sessionControllerProvider.overrideWith(_Dono.new),
            cashierRepositoryProvider.overrideWithValue(repo),
            saleRepositoryProvider.overrideWithValue(FakeSaleRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CashierScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fechar caixa'), findsNothing);
      expect(find.textContaining('Aberto desde'), findsNothing);
      // Segue no modo livre, sem cerimônia de nenhum tipo.
      expect(find.text('Caixa de hoje'), findsOneWidget);
      expect(find.text('Encerrar conferência'), findsNothing);
    });

    testWidgets('com exigência LIGADA o fluxo de sessão continua', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = FakeCashierRepository();
      await repo.updateConfig(requireOpenSession: true);
      await repo.openSession(openingAmount: 100);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityControllerProvider.overrideWith(_OnlineConn.new),
            sessionControllerProvider.overrideWith(_Dono.new),
            cashierRepositoryProvider.overrideWithValue(repo),
            saleRepositoryProvider.overrideWithValue(FakeSaleRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CashierScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fechar caixa'), findsOneWidget);
      expect(find.text('Caixa do dia'), findsWidgets);
    });
  });
}
