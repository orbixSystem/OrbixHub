import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/schedule/domain/schedule_models.dart';
import 'package:orbixhub_front/features/schedule/presentation/agenda_screen.dart';
import 'package:orbixhub_front/features/schedule/presentation/schedule_providers.dart';

/// Agenda: abrir a OS pelo card e aguentar um dia cheio sem estourar layout.

class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
    Me(
      user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
      role: 'owner',
      permissions: ['os.read', 'os.write'],
      modules: ['os'],
    ),
  );
}

/// Dia cheio e com os textos mais longos que a vida real produz: nome de
/// cliente completo, veículo descrito, status de rótulo comprido.
List<AgendaItem> _diaCheio(int n) => [
      for (var i = 0; i < n; i++)
        AgendaItem(
          id: 'item-$i',
          orderId: 'os-$i',
          name: 'Revisão completa com troca de correia dentada, bomba d\'água '
              'e tensionador — motor 1.6 16V',
          assignedToName: 'Ana Carolina Rodrigues do Nascimento',
          scheduledStart: '2026-08-03T08:00:00Z',
          scheduledEnd: '2026-08-03T12:00:00Z',
          estimatedDuration: 240,
          order: AgendaOrderRef(
            id: 'os-$i',
            number: 'OS-${(i + 1).toString().padLeft(4, '0')}',
            status: 'aguardando_aprovacao',
            customerName: 'Maria Aparecida de Souza Albuquerque Filha',
            subjectLabel: 'Volkswagen CrossFox 1.6 Total Flex — ABC1D23',
          ),
        ),
    ];

Widget _wrap(List<AgendaItem> items, {List<Override> extra = const []}) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(_OnlineConn.new),
      sessionControllerProvider.overrideWith(_FakeSession.new),
      agendaProvider.overrideWith((ref) async => AgendaResult(items: items)),
      businessHoursProvider.overrideWith((ref) async => const []),
      ...extra,
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: AgendaScreen()),
    ),
  );
}

void main() {
  // A agenda formata datas em pt_BR; o app faz isto no main.dart.
  setUpAll(() => initializeDateFormatting('pt_BR', null));

  group('layout com o dia cheio', () {
    testWidgets('desktop: painel lateral estreito não estoura', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(_diaCheio(8)));
      await tester.pumpAndSettle();

      // Qualquer overflow de layout vira exceção no teste — nenhuma aqui.
      expect(tester.takeException(), isNull);
      expect(find.textContaining('OS-0001'), findsWidgets);
    });

    testWidgets('mobile: mesma carga, tela estreita', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(_diaCheio(8)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('rola a lista até o último card sem estourar', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(_diaCheio(12)));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(ListView).last,
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
