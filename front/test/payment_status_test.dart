import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/presentation/os_list_screen.dart';
import 'package:orbixhub_front/features/os/presentation/os_providers.dart';
import 'package:orbixhub_front/features/os/presentation/payment_status.dart';

class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'a@b.c', fullName: 'A'),
          role: 'owner',
          permissions: ['os.write', 'os.read'],
          modules: ['os'],
        ),
      );
}

void main() {
  group('PaymentTag', () {
    Future<void> pumpTag(WidgetTester tester, String status) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Center(child: PaymentTag(status: status))),
        ));

    testWidgets('a_receber → "A receber"', (tester) async {
      await pumpTag(tester, 'a_receber');
      expect(find.text('A receber'), findsOneWidget);
    });

    testWidgets('parcial → "Parcial"', (tester) async {
      await pumpTag(tester, 'parcial');
      expect(find.text('Parcial'), findsOneWidget);
    });

    testWidgets('pago → "Paga"', (tester) async {
      await pumpTag(tester, 'pago');
      expect(find.text('Paga'), findsOneWidget);
    });
  });

  testWidgets('listagem de OS exibe a tag de pagamento', (tester) async {
    final fake = FakeOsRepository(
      orders: const [
        ServiceOrder(
          id: 'os-1',
          number: 'OS-0001',
          customerId: 'c1',
          customerName: 'João da Silva',
          status: 'em_execucao',
          paymentStatus: 'a_receber',
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
    // Tag de pagamento na linha da listagem.
    expect(find.text('A receber'), findsOneWidget);
  });

  test('emitInvoice guarda o snapshot fiscal (fake) sem mexer no pagamento', () async {
    final fake = FakeOsRepository(
      orders: const [
        ServiceOrder(
          id: 'os-1',
          number: 'OS-0001',
          customerId: 'c1',
          status: 'concluida',
          paymentStatus: 'a_receber',
          total: '150.00',
        ),
      ],
    );

    final updated = await fake.emitInvoice('os-1');
    expect(updated.fiscalStatus, 'emitida');
    // Emitir nota NÃO altera o status de pagamento.
    expect(updated.paymentStatus, 'a_receber');
  });
}
