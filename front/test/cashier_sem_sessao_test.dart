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

/// Monta a tela com um repositório de caixa específico (para inspecionar como o
/// extrato do dia foi pedido).
Future<void> _montar(WidgetTester tester, FakeCashierRepository repo) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

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
      // Despesa NÃO é mais ação do caixa: conta a pagar virou o módulo
      // `Despesas`, e o lançamento aqui nasce da baixa lá. Duas portas para o
      // mesmo dinheiro deixariam saída no livro sem conta do outro lado.
      expect(find.text('Despesa / sangria'), findsNothing);
    });

    testWidgets('NÃO oferece conferência de gaveta', (tester) async {
      await _abrirTela(tester, exigeAbertura: false);

      // A config decide, sem meio-caminho: desligada = livro de lançamentos,
      // sem nada de contar gaveta. Quem quer conferência liga a exigência.
      expect(find.text('Conferir gaveta'), findsNothing);
      expect(find.text('Encerrar conferência'), findsNothing);
      expect(find.text('Fechar caixa'), findsNothing);
    });

    testWidgets('mostra os ÚLTIMOS lançamentos (confirmação, não extrato)',
        (tester) async {
      // O extrato completo é o Histórico. Aqui a lista serve para o operador
      // confirmar que o que ele acabou de lançar entrou.
      await _abrirTela(tester, exigeAbertura: false);
      expect(find.text('Últimos lançamentos'), findsOneWidget);
      expect(find.text('Lançamentos de hoje'), findsNothing);
    });

    testWidgets('as ações vêm em grid, com alvo de toque grande',
        (tester) async {
      await _abrirTela(tester, exigeAbertura: false);
      // As DUAS ações do caixa sem gaveta (dono vê todas). Eram três até a
      // despesa sair para o módulo `Despesas`; sangria/suprimento só aparecem
      // quando há controle de gaveta, que é onde operação de gaveta pertence.
      expect(find.text('Venda avulsa'), findsOneWidget);
      expect(find.text('Receber OS'), findsOneWidget);
      expect(find.text('Despesa / sangria'), findsNothing);
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
  group('recorte do "Caixa do dia"', () {
    /// Caixa que registra COMO o extrato foi pedido (por sessão ou por data).
    testWidgets('sem cerimônia, recorta por DATA mesmo com sessão implícita',
        (tester) async {
      // Com `requireOpenSession: false` o backend cria uma sessão IMPLÍCITA no
      // primeiro lançamento e nunca a fecha. Escolher o recorte por ela fazia
      // "Caixa do dia" mostrar tudo desde aquela sessão — semanas de movimento —
      // e nunca virar de data.
      final caixa = _EspiaCaixa(requireOpenSession: false, comSessaoAberta: true);
      await _montar(tester, caixa);

      expect(caixa.pedidoPorSessao, isFalse,
          reason: 'a sessão implícita não pode definir o dia');
      expect(caixa.ultimoFrom, isNotNull);
      final from = DateTime.parse(caixa.ultimoFrom!).toLocal();
      final agora = DateTime.now();
      expect(from.year, agora.year);
      expect(from.month, agora.month);
      expect(from.day, agora.day);
      expect(from.hour, 0, reason: 'meia-noite LOCAL');
      expect(from.minute, 0);
    });

    testWidgets('COM cerimônia, o caixa é a sessão (atravessa a meia-noite)',
        (tester) async {
      // Aqui a gaveta ainda não foi conferida: o extrato é o da sessão, não o do
      // dia, senão o fechamento perderia os lançamentos de antes da virada.
      final caixa = _EspiaCaixa(requireOpenSession: true, comSessaoAberta: true);
      await _montar(tester, caixa);

      expect(caixa.pedidoPorSessao, isTrue);
    });
  });

  group('lista curta do dia', () {
    testWidgets('mostra no máximo 5 lançamentos e oferece "Ver tudo"',
        (tester) async {
      final caixa = _EspiaCaixa(
        requireOpenSession: false,
        comSessaoAberta: false,
        lancamentos: [
          for (var i = 0; i < 9; i++)
            CashEntry(
              id: 'e$i',
              direction: 'out',
              amount: '10.00',
              method: 'pix',
              category: 'despesa',
              description: 'Despesa $i',
              createdAt: '2026-08-03T12:00:00Z',
            ),
        ],
      );
      await _montar(tester, caixa);

      // 9 lançamentos, 5 na tela: o resto está no Histórico.
      expect(find.textContaining('Despesa 0'), findsOneWidget);
      expect(find.textContaining('Despesa 4'), findsOneWidget);
      expect(find.textContaining('Despesa 5'), findsNothing);
      expect(find.text('Ver tudo'), findsOneWidget);
    });

    testWidgets('"Ver tudo" leva para a aba Histórico', (tester) async {
      final caixa = _EspiaCaixa(
        requireOpenSession: false,
        comSessaoAberta: false,
      );
      await _montar(tester, caixa);

      await tester.tap(find.text('Ver tudo'));
      await tester.pumpAndSettle();
      // O Histórico tem o seu próprio recorte por período.
      expect(find.text('Últimos lançamentos'), findsNothing);
    });
  });

  group('config mudou enquanto o app estava aberto', () {
    testWidgets('desligar a exigência e voltar NÃO manda abrir o caixa',
        (tester) async {
      // Fluxo relatado: fecha o caixa, desliga "exigir caixa aberto" em
      // Configurações, volta à tela — e ela pedia para abrir. O provider não era
      // autoDispose, então guardava a config do primeiro mount.
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = FakeCashierRepository();
      await repo.updateConfig(requireOpenSession: true);

      // Um switch externo controla se a tela do caixa está montada, para simular
      // sair para Configurações e voltar.
      final mostrando = ValueNotifier<bool>(true);
      addTearDown(mostrando.dispose);

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
            home: ValueListenableBuilder<bool>(
              valueListenable: mostrando,
              builder: (_, visivel, _) =>
                  visivel ? const CashierScreen() : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Caixa fechado + exigência ligada: pede para abrir (correto aqui).
      expect(find.textContaining('Abrir caixa'), findsWidgets);

      // Sai da tela (vai para Configurações) e desliga a exigência.
      mostrando.value = false;
      await tester.pumpAndSettle();
      await repo.updateConfig(requireOpenSession: false);

      // Volta.
      mostrando.value = true;
      await tester.pumpAndSettle();

      expect(find.textContaining('Abrir caixa'), findsNothing,
          reason: 'com a exigência desligada não se pede abertura');
      expect(find.text('Últimos lançamentos'), findsOneWidget);
    });
  });

  group('linha de venda no extrato do dia', () {
    testWidgets('não tem menu de 3 pontinhos — a linha abre a venda',
        (tester) async {
      // O menu era um segundo caminho para agir sobre a venda, escondido atrás
      // de três pontinhos. A linha inteira abre o detalhe, que é onde tudo mora.
      final caixa = _EspiaCaixa(
        requireOpenSession: false,
        comSessaoAberta: false,
        lancamentos: const [
          CashEntry(
            id: 'e-venda',
            direction: 'in',
            amount: '150.00',
            method: 'dinheiro',
            category: 'venda_avulsa',
            saleKind: 'sale',
            saleId: 's1',
            createdAt: '2026-08-03T12:00:00Z',
          ),
        ],
      );
      await _montar(tester, caixa);

      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
      // A afordância de que a linha leva a algum lugar continua.
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
    });

    testWidgets('despesa MANTÉM o menu (não há detalhe para abrir)',
        (tester) async {
      final caixa = _EspiaCaixa(
        requireOpenSession: false,
        comSessaoAberta: false,
        lancamentos: const [
          CashEntry(
            id: 'e-despesa',
            direction: 'out',
            amount: '50.00',
            method: 'pix',
            category: 'despesa',
            createdAt: '2026-08-03T12:00:00Z',
          ),
        ],
      );
      await _montar(tester, caixa);

      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });
  });
}

/// Caixa fake que expõe COMO o extrato do dia foi pedido.
class _EspiaCaixa extends FakeCashierRepository {
  _EspiaCaixa({
    required this.requireOpenSession,
    required this.comSessaoAberta,
    this.lancamentos = const [],
  });

  final bool requireOpenSession;
  final bool comSessaoAberta;
  final List<CashEntry> lancamentos;

  bool pedidoPorSessao = false;
  String? ultimoFrom;

  @override
  Future<CashierConfig> fetchConfig() async => CashierConfig(
        paymentMethods: const ['dinheiro', 'pix'],
        requireOpenSession: requireOpenSession,
        countCashOnly: true,
      );

  @override
  Future<CashSession?> currentSession() async => comSessaoAberta
      ? const CashSession(
          id: 'sessao-implicita',
          status: 'open',
          openingAmount: '0',
        )
      : null;

  @override
  Future<EntryPage> listEntries({
    String? sessionId,
    String? q,
    String? direction,
    String? method,
    String? category,
    String? saleKind,
    String? saleId,
    String? from,
    String? to,
    int page = 1,
  }) async {
    if (sessionId != null) pedidoPorSessao = true;
    ultimoFrom = from;
    return EntryPage(items: lancamentos, total: lancamentos.length);
  }
}
