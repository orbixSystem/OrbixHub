import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/settings/data/fake_settings_repository.dart';
import 'package:orbixhub_front/features/settings/domain/settings_repository.dart';
import 'package:orbixhub_front/features/settings/presentation/appearance_section.dart';

import 'support/online_conn.dart';

/// Sessão fixa com permissão settings.manage, sem tocar plataforma.
class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'owner@test.com', fullName: 'Dono Teste'),
          role: 'owner',
          permissions: ['settings.manage', 'billing.manage'],
          modules: [],
        ),
      );
}

/// Monta [AppearanceSection] com um [ProviderScope] isolado.
Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> company,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onlineConnOverride,
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(),
        ),
        sessionControllerProvider.overrideWith(_FakeSession.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppearanceSection(company: company),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AppearanceSection exibe swatches dos presets', (tester) async {
    await _pump(tester, {'themePreset': 'tangerina'});

    // Deve mostrar labels de todos os presets
    expect(find.text('Tangerina'), findsOneWidget);
    expect(find.text('Azul'), findsOneWidget);
    expect(find.text('Verde'), findsOneWidget);
  });

  testWidgets('AppearanceSection exibe controle de modo claro/escuro/sistema',
      (tester) async {
    await _pump(tester, {'themePreset': 'tangerina'});

    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
  });

  testWidgets('AppearanceSection NÃO exibe seção de pré-visualização', (tester) async {
    await _pump(tester, {'themePreset': 'tangerina'});

    expect(find.text('Pré-visualização'), findsNothing);
  });

  testWidgets('Tocar swatch Azul chama saveAppearance com themePreset:azul',
      (tester) async {
    final fakeRepo = FakeSettingsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineConnOverride,
          settingsRepositoryProvider
              .overrideWithValue(fakeRepo as SettingsRepository),
          sessionControllerProvider.overrideWith(_FakeSession.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppearanceSection(
                company: const {'themePreset': 'tangerina'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toca no swatch 'Azul'
    await tester.tap(find.text('Azul'));
    await tester.pumpAndSettle();

    // O FakeSettingsRepository deve ter recebido o patch
    final bundle = await fakeRepo.fetch();
    expect(bundle.company['themePreset'], 'azul');
  });

  testWidgets('Tocar Escuro atualiza themeControllerProvider para ThemeMode.dark',
      (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineConnOverride,
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
          sessionControllerProvider.overrideWith(_FakeSession.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return AppearanceSection(
                    company: const {'themePreset': 'tangerina'},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toca no botão 'Escuro'
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(capturedRef.read(themeControllerProvider), ThemeMode.dark);
  });
}
