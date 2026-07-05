import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/team/data/fake_team_repository.dart';
import 'package:orbixhub_front/features/team/presentation/team_screen.dart';

const _me = Me(
  user: User(id: 'u1', email: 'dono@teste.com', fullName: 'Dono Teste'),
  activeTenant: Tenant(id: 't1', slug: 's1', name: 'Oficina'),
  role: 'owner',
  permissions: ['users.manage'],
  modules: ['os'],
  memberships: [Membership(tenantId: 't1', tenantSlug: 's1', role: 'owner')],
);

class _AuthedSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(_me);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('TeamScreen lays out without exception and shows its sections',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_AuthedSession.new),
          teamRepositoryProvider.overrideWithValue(FakeTeamRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: TeamScreen())),
      ),
    );
    // Let the FutureProviders (employees/invites/roles) resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // The FilledButton-in-a-Row infinite-width bug threw here before the fix.
    expect(tester.takeException(), isNull);
    expect(find.text('Equipe'), findsOneWidget);
    expect(find.text('Convidar'), findsOneWidget);
    // Abas do redesign: Funcionários (aba+lista) e Convites (aba; pode ter
    // contagem no rótulo, ex.: "Convites (2)").
    expect(find.text('Funcionários'), findsWidgets);
    expect(find.textContaining('Convites'), findsWidgets);
  });
}
