import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/config/feature_flags.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/billing/domain/billing_models.dart';
import 'package:orbixhub_front/features/billing/presentation/billing_providers.dart';
import 'package:orbixhub_front/features/shell/presentation/dashboard_screen.dart';

/// Enquanto o fluxo de cobrança não existe de ponta a ponta, o painel não pode
/// pedir "regularize a assinatura" — o usuário não teria como fazer isso.

class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
    Me(
      user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono Teste'),
      role: 'owner',
      permissions: ['os.read'],
      modules: ['os'],
    ),
  );
}

void main() {
  testWidgets('assinatura vencida NÃO mostra o aviso de pagamento pendente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityControllerProvider.overrideWith(_OnlineConn.new),
          sessionControllerProvider.overrideWith(_FakeSession.new),
          // Pior caso: o backend diz que a assinatura está em atraso.
          subscriptionProvider.overrideWith(
            (ref) async =>
                const Subscription(planKey: 'pro', status: 'past_due'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(kBillingNoticesEnabled, isFalse);
    expect(find.textContaining('Pagamento pendente'), findsNothing);
    expect(find.textContaining('Regularize a assinatura'), findsNothing);
    // O painel em si segue de pé.
    expect(find.textContaining('Olá, Dono'), findsOneWidget);
  });
}
