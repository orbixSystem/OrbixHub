import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/settings/data/fake_settings_repository.dart';
import 'package:orbixhub_front/features/settings/domain/settings_repository.dart';
import 'package:orbixhub_front/features/settings/presentation/settings_screen.dart';

import 'support/online_conn.dart';

/// Session controller fixo com permissão settings.manage, sem tocar plataforma.
class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'owner@test.com', fullName: 'Dono Teste'),
          activeTenant: Tenant(id: 't1', slug: 'demo', name: 'Oficina Demo'),
          role: 'owner',
          permissions: ['settings.manage', 'billing.manage', 'users.manage'],
          modules: [],
        ),
      );
}

/// Session controller fixo SEM permissão settings.manage (mecânico).
class _FakeSessionNoAccess extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u2', email: 'mech@test.com', fullName: 'Mecânico'),
          activeTenant: Tenant(id: 't1', slug: 'demo', name: 'Oficina Demo'),
          role: 'mechanic',
          permissions: ['os.read'],
          modules: [],
        ),
      );
}

void main() {
  testWidgets('SettingsScreen renderiza sem lançar exceção com permissão',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineConnOverride,
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository() as SettingsRepository,
          ),
          sessionControllerProvider.overrideWith(_FakeSession.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    // Loading state.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Settle async data.
    await tester.pumpAndSettle();

    // Must show the page header.
    expect(find.text('Configurações'), findsWidgets);
    // Owner com settings.manage vê a seção de empresa (no nav-rail e, quando
    // selecionada, também no cabeçalho de conteúdo — master-detail).
    expect(find.text('Empresa & Identidade visual'), findsWidgets);
    // Aparência sempre visível.
    expect(find.text('Aparência'), findsWidgets);
  });

  testWidgets('SettingsScreen sem settings.manage mostra apenas Aparência (sem acesso negado)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineConnOverride,
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository() as SettingsRepository,
          ),
          sessionControllerProvider.overrideWith(_FakeSessionNoAccess.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // NÃO mostra mais "Acesso negado" — a seção Aparência é pública.
    expect(find.text('Acesso negado'), findsNothing);
    // Seção Aparência sempre visível (nav-rail + cabeçalho de conteúdo).
    expect(find.text('Aparência'), findsWidgets);
    // Seção de empresa NÃO deve aparecer para não-owners.
    expect(find.text('Empresa & Identidade visual'), findsNothing);
  });
}
