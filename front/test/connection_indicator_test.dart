import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/offline/widgets/connection_banner.dart';
import 'package:orbixhub_front/core/offline/widgets/connection_chip.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/shell/presentation/app_shell.dart';

/// Fake controlável do B2: sobrescreve `build()` (nunca assina o platform
/// channel real de conectividade) e expõe [emit] para o teste empurrar
/// estados diretamente — o padrão pedido pelo brief ("override the
/// controller with a fake notifier").
class _FakeConnectivityController extends ConnectivityController {
  _FakeConnectivityController(this._initial);
  final ConnState _initial;

  @override
  ConnState build() => _initial;

  void emit(ConnState next) => state = next;
}

/// Sessão fixa (autenticada, sem módulos) para montar o AppShell real sem
/// tocar canais de plataforma — mesmo padrão de os_list_screen_test.dart.
class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono Teste'),
          role: 'owner',
          permissions: [],
          modules: [],
        ),
      );
}

Widget _wrap(Widget child, _FakeConnectivityController controller) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(() => controller),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('ConnectionChip', () {
    testWidgets('shows green "Online" when status is online', (tester) async {
      final controller =
          _FakeConnectivityController(const ConnState(status: ConnStatus.online));
      await tester.pumpWidget(_wrap(const ConnectionChip(), controller));

      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('shows amber "Sincronizando…" with a progress affordance '
        'when status is syncing', (tester) async {
      final controller = _FakeConnectivityController(
          const ConnState(status: ConnStatus.syncing));
      await tester.pumpWidget(_wrap(const ConnectionChip(), controller));

      expect(find.text('Sincronizando…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows "Offline • N pendentes" with the pending count',
        (tester) async {
      final controller = _FakeConnectivityController(
        const ConnState(status: ConnStatus.offline, pendingCount: 3),
      );
      await tester.pumpWidget(_wrap(const ConnectionChip(), controller));

      expect(find.text('Offline • 3 pendentes'), findsOneWidget);
    });

    testWidgets('sem pendências o rótulo é só "Offline" (nada de "0 pendentes")',
        (tester) async {
      final controller = _FakeConnectivityController(
        const ConnState(status: ConnStatus.offline),
      );
      await tester.pumpWidget(_wrap(const ConnectionChip(), controller));

      expect(find.text('Offline'), findsOneWidget);
      expect(find.textContaining('pendente'), findsNothing);
    });

    testWidgets('singularizes "1 pendente"', (tester) async {
      final controller = _FakeConnectivityController(
        const ConnState(status: ConnStatus.offline, pendingCount: 1),
      );
      await tester.pumpWidget(_wrap(const ConnectionChip(), controller));

      expect(find.text('Offline • 1 pendente'), findsOneWidget);
    });

    testWidgets('reacts live to state changes pushed by the controller',
        (tester) async {
      final controller =
          _FakeConnectivityController(const ConnState(status: ConnStatus.online));
      await tester.pumpWidget(_wrap(const ConnectionChip(), controller));
      expect(find.text('Online'), findsOneWidget);

      controller.emit(
        const ConnState(status: ConnStatus.offline, pendingCount: 5),
      );
      await tester.pump();

      expect(find.text('Online'), findsNothing);
      expect(find.text('Offline • 5 pendentes'), findsOneWidget);
    });

    testWidgets('tooltip mentions mutations pending from other authors',
        (tester) async {
      final controller = _FakeConnectivityController(
        const ConnState(
          status: ConnStatus.offline,
          pendingCount: 2,
          pendingOtherAuthors: 4,
        ),
      );
      await tester.pumpWidget(_wrap(const ConnectionChip(), controller));

      final tooltip =
          tester.widget<Tooltip>(find.byType(Tooltip).first);
      expect(tooltip.message, contains('4 aguardando login de outro usuário'));
    });

    testWidgets('collapsed mode degrades to a dot with a Tooltip, no label',
        (tester) async {
      final controller =
          _FakeConnectivityController(const ConnState(status: ConnStatus.online));
      await tester.pumpWidget(
        _wrap(const ConnectionChip(collapsed: true), controller),
      );

      expect(find.text('Online'), findsNothing);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).first);
      expect(tooltip.message, contains('Online'));
    });
  });

  group('ConnectionBanner', () {
    testWidgets('never shows anything when it has been online all along',
        (tester) async {
      final controller =
          _FakeConnectivityController(const ConnState(status: ConnStatus.online));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: false), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('offline'), findsNothing);
      expect(find.textContaining('Sincronizando'), findsNothing);
      expect(find.textContaining('restabelecida'), findsNothing);
    });

    testWidgets('shows the offline message (non-web) while offline',
        (tester) async {
      final controller = _FakeConnectivityController(
          const ConnState(status: ConnStatus.offline));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: false), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'Você está offline — alterações serão enviadas ao reconectar',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the web-specific offline message when isWeb is true',
        (tester) async {
      final controller = _FakeConnectivityController(
          const ConnState(status: ConnStatus.offline));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: true), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'Você está offline — o Orbix precisa de conexão no navegador',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Você está offline — alterações serão enviadas ao reconectar',
        ),
        findsNothing,
      );
    });

    testWidgets('mostra "Sincronizando" quando há alteração DESTE usuário',
        (tester) async {
      final controller = _FakeConnectivityController(
          const ConnState(status: ConnStatus.syncing, pendingCount: 2));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: false), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sincronizando alterações…'), findsOneWidget);
    });

    testWidgets('rodada de rotina (nada pendente) NÃO pinta banner',
        (tester) async {
      // O engine marca `syncing` a cada 60s, inclusive nas rodadas que só puxam
      // novidades. Anunciar isso pintava um banner de minuto em minuto com a
      // internet intacta e nada do usuário esperando.
      final controller = _FakeConnectivityController(
          const ConnState(status: ConnStatus.syncing));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: false), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sincronizando alterações…'), findsNothing);
    });

    testWidgets('rodada de sync NÃO anuncia "conexão restabelecida"',
        (tester) async {
      // Era o bug relatado: `syncing → online` a cada rodada disparava o aviso
      // verde de reconexão sem a internet nunca ter caído. Só uma queda real
      // (`offline`) justifica o aviso.
      final controller =
          _FakeConnectivityController(const ConnState(status: ConnStatus.online));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: false), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Duas rodadas seguidas, como o engine faz de 60 em 60 segundos.
      for (var i = 0; i < 2; i++) {
        controller.emit(const ConnState(status: ConnStatus.syncing));
        await tester.pump(const Duration(milliseconds: 300));
        controller.emit(const ConnState(status: ConnStatus.online));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.textContaining('restabelecida'), findsNothing);
    });

    testWidgets('queda REAL seguida de sync ainda anuncia a reconexão',
        (tester) async {
      // A correção não pode calar o aviso legítimo: caiu, voltou, sincronizou.
      final controller = _FakeConnectivityController(
          const ConnState(status: ConnStatus.online));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: false), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));

      controller.emit(const ConnState(status: ConnStatus.offline));
      await tester.pump(const Duration(milliseconds: 300));
      // Ao voltar, o engine passa por `syncing` antes de `online`.
      controller.emit(const ConnState(status: ConnStatus.syncing));
      await tester.pump(const Duration(milliseconds: 300));
      controller.emit(const ConnState(status: ConnStatus.online));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('restabelecida'), findsOneWidget);
    });

    testWidgets(
        'flashes green "reconectado" for ~3s after going offline→online, '
        'then hides', (tester) async {
      final controller = _FakeConnectivityController(
          const ConnState(status: ConnStatus.offline));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: false), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text(
          'Você está offline — alterações serão enviadas ao reconectar',
        ),
        findsOneWidget,
      );

      controller.emit(const ConnState(status: ConnStatus.online));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Conexão restabelecida — dados sincronizados'),
        findsOneWidget,
      );

      // Ainda dentro da janela de 3s: continua visível.
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('Conexão restabelecida — dados sincronizados'),
        findsOneWidget,
      );

      // Passa dos 3s + tempo de animação de saída: some.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Conexão restabelecida — dados sincronizados'),
        findsNothing,
      );
    });

    testWidgets(
        'nova queda DURANTE o flash de reconexão: o flash cede lugar à '
        'mensagem de offline (sem sobrepor)', (tester) async {
      final controller = _FakeConnectivityController(
          const ConnState(status: ConnStatus.offline));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: false), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Reconecta: flash verde aparece.
      controller.emit(const ConnState(status: ConnStatus.online));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Conexão restabelecida — dados sincronizados'),
        findsOneWidget,
      );

      // Cai de novo ANTES dos 3s: o flash some e o aviso de offline assume.
      await tester.pump(const Duration(seconds: 1));
      controller.emit(const ConnState(status: ConnStatus.offline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Conexão restabelecida — dados sincronizados'),
        findsNothing,
      );
      expect(
        find.text(
          'Você está offline — alterações serão enviadas ao reconectar',
        ),
        findsOneWidget,
      );

      // O Timer do flash foi cancelado na queda: avançar o relógio não pode
      // ressuscitar o flash nem deixar timer pendente no teardown.
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.text('Conexão restabelecida — dados sincronizados'),
        findsNothing,
      );
    });
  });

  group('integração no shell (header mobile)', () {
    testWidgets(
        'chip com contagem enorme num telefone estreito não estoura o Row '
        'do header (trunca com reticências)', (tester) async {
      tester.view.physicalSize = const Size(320, 690);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _FakeConnectivityController(
        const ConnState(status: ConnStatus.offline, pendingCount: 999999999),
      );
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SizedBox()),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityControllerProvider.overrideWith(() => controller),
            sessionControllerProvider.overrideWith(_FakeSession.new),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      // A regressão exata da sidebar, no segundo ponto de integração: sem um
      // Flexible NO HEADER o chip recebe largura ilimitada do Row e o
      // Flexible interno nunca ativa → RenderFlex overflow.
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Offline'), findsOneWidget);
    });
  });
}
