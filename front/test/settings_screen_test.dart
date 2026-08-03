import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/settings/data/fake_settings_repository.dart';
import 'package:orbixhub_front/features/settings/domain/settings_models.dart';
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

/// Repositório que expõe uma seção de módulo (Caixa) e registra o que foi salvo.
class _SpySettings extends FakeSettingsRepository {
  _SpySettings({required this.editable});

  final bool editable;
  final salvos = <({String key, Map<String, dynamic> values})>[];

  @override
  Future<SettingsBundle> fetch() async => SettingsBundle(
        company: const {},
        sections: [
          SettingsSection(
            key: 'cashier',
            title: 'Caixa',
            moduleKey: 'cashier',
            editable: editable,
            fields: const [
              SettingsField(
                key: 'requireOpenSession',
                label: 'Exigir caixa aberto para lançar',
                type: 'bool',
              ),
            ],
            values: const {'requireOpenSession': false},
          ),
        ],
      );

  @override
  Future<Map<String, dynamic>> updateSection(
    String key,
    Map<String, dynamic> values,
  ) async {
    salvos.add((key: key, values: values));
    return values;
  }
}

Widget _app(SettingsRepository repo) => ProviderScope(
      overrides: [
        onlineConnOverride,
        settingsRepositoryProvider.overrideWithValue(repo),
        sessionControllerProvider.overrideWith(_FakeSession.new),
      ],
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );

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
  group('toggle de config de módulo', () {
    testWidgets('seção editável: o toggle é clicável e SALVA', (tester) async {
      // O bug: a seção dinâmica nascia toda somente-leitura (`onChanged: null`),
      // então não havia como ligar "Exigir caixa aberto" pela tela.
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _SpySettings(editable: true);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Caixa'));
      await tester.pumpAndSettle();

      final sw = find.byType(Switch).first;
      expect(tester.widget<Switch>(sw).onChanged, isNotNull,
          reason: 'seção editável tem de aceitar toque');

      await tester.tap(sw);
      await tester.pumpAndSettle();

      expect(repo.salvos, hasLength(1));
      expect(repo.salvos.single.key, 'cashier');
      expect(repo.salvos.single.values['requireOpenSession'], isTrue);
    });

    testWidgets('seção só de leitura mantém o toggle desabilitado',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _SpySettings(editable: false);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Caixa'));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch).first).onChanged, isNull);
      expect(repo.salvos, isEmpty);
    });
  });
}
