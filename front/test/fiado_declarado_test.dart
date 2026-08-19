import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/presentation/os_providers.dart';
import 'package:orbixhub_front/features/receivables/data/fake_receivables_repository.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_tab.dart';
import 'package:orbixhub_front/features/receivables/presentation/receive_title_dialog.dart';

/// Fiado DECLARADO — o título só entra na carteira depois de passar pelo caixa.
///
/// Antes, fiado era derivado do saldo: uma OS entrava na cobrança no instante
/// em que era aberta, antes do serviço e de qualquer conversa sobre pagamento.
/// Agora existe uma decisão, e ela precisa de duas garantias na tela:
///
///  1. quem foi entregue e NÃO passou pelo caixa não some — vira aviso;
///  2. o operador consegue declarar fiado recebendo ZERO (o caso que a trava
///     de "valor maior que zero" tornava irregistrável).

class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

/// OS que registra se o carimbo de fiado foi pedido.
class _SpyOs extends FakeOsRepository {
  final declaradas = <String>[];

  @override
  Future<ServiceOrder> markFiado(String id) {
    declaradas.add(id);
    return super.markFiado(id);
  }
}

/// Caixa que registra o que foi lançado — para provar que declarar fiado NÃO
/// põe dinheiro na gaveta.
class _SpyCashier extends FakeCashierRepository {
  final lancados = <EntryDraft>[];

  @override
  Future<CashEntry> createEntry(EntryDraft draft) {
    lancados.add(draft);
    return super.createEntry(draft);
  }
}

void main() {
  group('aviso de entregue sem acerto', () {
    Widget app(FakeReceivablesRepository repo) => ProviderScope(
          overrides: [
            connectivityControllerProvider.overrideWith(_OnlineConn.new),
            receivablesRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ReceivablesTab(canWrite: true)),
          ),
        );

    testWidgets('conta os títulos finalizados que não passaram pelo caixa',
        (tester) async {
      await tester.pumpWidget(app(FakeReceivablesRepository(
        pendingSettlement: const PendingSettlement(count: 3, total: 250),
      )));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('3 títulos finalizados'),
        findsOneWidget,
        reason: 'o número precisa ser interpolado, não sair literal na tela',
      );
    });

    testWidgets('no singular fala de UM título', (tester) async {
      await tester.pumpWidget(app(FakeReceivablesRepository(
        pendingSettlement: const PendingSettlement(count: 1, total: 32),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 título finalizado'), findsOneWidget);
    });

    testWidgets('sem pendências não polui a tela', (tester) async {
      await tester.pumpWidget(app(FakeReceivablesRepository()));
      await tester.pumpAndSettle();
      expect(find.textContaining('não passaram pelo caixa'), findsNothing);
      expect(find.textContaining('não passou pelo caixa'), findsNothing);
    });

    testWidgets('aparece MESMO com a carteira vazia', (tester) async {
      // O caso perigoso: sem nenhum fiado a tela mostrava só o vazio — e a OS
      // entregue e esquecida não teria onde aparecer.
      await tester.pumpWidget(app(FakeReceivablesRepository(
        titulos: const [],
        pendingSettlement: const PendingSettlement(count: 2, total: 90),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum fiado em aberto'), findsOneWidget);
      expect(find.textContaining('2 títulos finalizados'), findsOneWidget);
    });
  });

  group('declarar fiado no diálogo de receber', () {
    late _SpyOs os;
    late _SpyCashier caixa;

    const titulo = ReceivableTitle(
      id: 'os-1',
      origin: 'os',
      number: 'OS-0008',
      total: 32,
      paid: 0,
      balance: 32,
      status: 'a_receber',
      items: [],
    );

    Future<void> abrir(WidgetTester tester) async {
      os = _SpyOs();
      caixa = _SpyCashier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityControllerProvider.overrideWith(_OnlineConn.new),
            osRepositoryProvider.overrideWithValue(os),
            cashierRepositoryProvider.overrideWithValue(caixa),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showReceiveTitleDialog(
                      ctx,
                      ref,
                      config: const CashierConfig(),
                      title: titulo,
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    Future<void> digitar(WidgetTester tester, String valor) async {
      await tester.enterText(find.byType(TextFormField).first, valor);
      await tester.pumpAndSettle();
    }

    testWidgets('o botão se nomeia pelo valor digitado', (tester) async {
      await abrir(tester);
      // Abre pré-preenchido com o saldo: quitação simples.
      expect(find.text('Registrar'), findsOneWidget);

      await digitar(tester, '10');
      expect(find.text('Registrar e deixar o resto fiado'), findsOneWidget);

      await digitar(tester, '0');
      expect(find.text('Deixar fiado'), findsOneWidget);
    });

    testWidgets('zero declara fiado e NÃO lança dinheiro no caixa',
        (tester) async {
      await abrir(tester);
      await digitar(tester, '0');
      await tester.tap(find.text('Deixar fiado'));
      await tester.pumpAndSettle();

      expect(os.declaradas, ['os-1'],
          reason: 'o carimbo é a única prova da passagem pelo caixa');
      expect(caixa.lancados, isEmpty,
          reason: 'nada foi recebido — a gaveta não pode acusar entrada');
    });

    testWidgets('recebimento parcial não precisa do carimbo', (tester) async {
      // O próprio lançamento de caixa já prova a passagem.
      await abrir(tester);
      await digitar(tester, '10');
      await tester.tap(find.text('Registrar e deixar o resto fiado'));
      await tester.pumpAndSettle();

      expect(caixa.lancados.single.amount, 10);
      expect(os.declaradas, isEmpty);
    });
  });
}
