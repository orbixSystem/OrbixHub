import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/settings/data/fake_settings_repository.dart';
import 'package:orbixhub_front/features/settings/domain/settings_repository.dart';

/// Sessão fake autenticada com tenant ativo — o build() do controller exige
/// um activeTenant para re-buscar por tenant.
class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'owner@test.com', fullName: 'Dono Teste'),
          activeTenant: Tenant(id: 't1', slug: 'demo', name: 'Oficina Demo'),
          role: 'owner',
          permissions: ['settings.manage'],
          modules: [],
        ),
      );
}

void main() {
  test('carrega e salva company via fake', () async {
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider
          .overrideWithValue(FakeSettingsRepository() as SettingsRepository),
      sessionControllerProvider.overrideWith(_FakeSession.new),
    ]);
    addTearDown(container.dispose);

    // Dispara a carga inicial e aguarda a conclusão.
    await container
        .read(settingsControllerProvider.notifier)
        .load();

    final st = container.read(settingsControllerProvider);
    // Estado deve ser AsyncData com companyName = 'Oficina Demo'.
    expect(
      st.whenOrNull(data: (b) => b.company['companyName']),
      'Oficina Demo',
    );

    await container
        .read(settingsControllerProvider.notifier)
        .saveCompany({'companyName': 'Nova'});

    final st2 = container.read(settingsControllerProvider);
    expect(
      st2.whenOrNull(data: (b) => b.company['companyName']),
      'Nova',
    );
  });
}
