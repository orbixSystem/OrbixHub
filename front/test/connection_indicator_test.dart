import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/offline/widgets/connection_banner.dart';
import 'package:orbixhub_front/core/offline/widgets/connection_chip.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';

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

    testWidgets('shows the syncing message while syncing', (tester) async {
      final controller = _FakeConnectivityController(
          const ConnState(status: ConnStatus.syncing));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: false), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sincronizando alterações…'), findsOneWidget);
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

    testWidgets('going syncing→online also triggers the reconnect flash',
        (tester) async {
      final controller = _FakeConnectivityController(
          const ConnState(status: ConnStatus.syncing));
      await tester.pumpWidget(
        _wrap(const ConnectionBanner(isWeb: false), controller),
      );
      await tester.pump(const Duration(milliseconds: 300));

      controller.emit(const ConnState(status: ConnStatus.online));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Conexão restabelecida — dados sincronizados'),
        findsOneWidget,
      );

      // Deixa o Timer de 3s completar antes do teste terminar (senão o
      // flutter_test acusa "Timer ainda pendente" no teardown).
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
