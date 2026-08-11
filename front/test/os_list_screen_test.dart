import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/presentation/os_providers.dart';
import 'package:orbixhub_front/features/os/presentation/os_list_screen.dart';

/// Sessão fixa (autenticada) para isolar o teste dos canais de plataforma
/// (secure storage) que o controller real toca no bootstrap.
class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'a@b.c', fullName: 'A'),
          role: 'owner',
          permissions: ['os.write', 'os.approve'],
          modules: ['os'],
        ),
      );
}

void main() {
  testWidgets('lista mostra nº, cliente e chip de status', (tester) async {
    final fake = FakeOsRepository(
      orders: const [
        ServiceOrder(
          id: 'os-1',
          number: 'OS-0001',
          customerId: 'c1',
          customerName: 'João da Silva',
          subjectLabel: 'Gol 2012',
          status: 'em_execucao',
          total: '150.00',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          osRepositoryProvider.overrideWithValue(fake),
          sessionControllerProvider.overrideWith(_FakeSession.new),
        ],
        child: const MaterialApp(home: Scaffold(body: OsListScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OS-0001'), findsOneWidget);
    expect(find.textContaining('João da Silva'), findsOneWidget);
    // Pill forte de status — 'em_execucao' cai no grupo simplificado "Em
    // andamento" (a lista não mostra mais os 7 status reais).
    expect(find.text('Em andamento'), findsWidgets);
    // Total formatado.
    expect(find.text('R\$ 150,00'), findsOneWidget);
    // Botão "Nova OS" visível (os.write).
    expect(find.text('Nova OS'), findsOneWidget);
  });
}
