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

/// Session controller fixo com permissão settings.manage, sem tocar plataforma.
class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'owner@test.com', fullName: 'Dono Teste'),
          role: 'owner',
          permissions: ['settings.manage', 'billing.manage', 'users.manage'],
          modules: [],
        ),
      );
}

/// Session controller fixo SEM permissão settings.manage.
class _FakeSessionNoAccess extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u2', email: 'mech@test.com', fullName: 'Mecânico'),
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
    // Must show the company section title.
    expect(find.text('Empresa & Identidade visual'), findsOneWidget);
    // Must show the appearance placeholder card.
    expect(find.text('Aparência'), findsOneWidget);
  });

  testWidgets('SettingsScreen mostra acesso negado sem settings.manage',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

    expect(find.text('Acesso negado'), findsOneWidget);
    // The form must NOT be shown.
    expect(find.text('Empresa & Identidade visual'), findsNothing);
  });
}
