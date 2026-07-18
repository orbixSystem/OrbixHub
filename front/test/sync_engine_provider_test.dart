import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sessão autenticada — reproduz o estado logo APÓS o login (há usuário, então
/// `currentUserId()` não é null e a 1ª rodada do engine chama `markSyncing`).
class _AuthedSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
          role: 'owner',
          permissions: [],
          modules: ['os'],
        ),
      );
}

/// Conectividade fake — não assina o platform channel real.
class _FakeConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Regressão: no desktop, ao logar, criar o `syncEngineProvider` disparava
  // `SyncEngine.start()` → `nudge()` → `_runOnce()` → `conn.markSyncing()` de
  // forma SÍNCRONA durante o build do provider. Riverpod proíbe um provider
  // modificar outro durante sua inicialização (AssertionError). O disparo
  // inicial deve ser adiado (microtask) para fora do build.
  test('criar o syncEngineProvider com sessão + db local não viola o build do '
      'Riverpod (bug de login no desktop)', () {
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(_AuthedSession.new),
        connectivityControllerProvider.overrideWith(_FakeConn.new),
        localDbProvider.overrideWithValue(LocalDb(NativeDatabase.memory())),
      ],
    );

    // Antes do fix: lança AssertionError ("Providers are not allowed to modify
    // other providers during their initialization").
    expect(() => container.read(syncEngineProvider), returnsNormally);

    // Fecha o engine ANTES do microtask do disparo inicial rodar (o `stop()`
    // seta `_closed` de forma síncrona), evitando I/O de rede no teste.
    container.dispose();
  });
}
