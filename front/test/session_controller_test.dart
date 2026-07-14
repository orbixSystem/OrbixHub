import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/network/access_token_store.dart';
import 'package:orbixhub_front/core/platform/app_reloader.dart';
import 'package:orbixhub_front/core/storage/secure_token_store.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/data/fake_auth_repository.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';

/// In-memory stand-in for the platform secure store (no plugin channel in tests).
class InMemorySecureTokenStore extends SecureTokenStore {
  String? _token;

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> writeRefreshToken(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// Registra quantas vezes o app pediu reset total (reload).
class _RecordingReloader implements AppReloader {
  int count = 0;
  @override
  void reload() => count++;
}

void main() {
  late AccessTokenStore access;
  late InMemorySecureTokenStore secure;
  late FakeAuthRepository auth;
  late _RecordingReloader reloader;

  /// Quantas vezes o `localDbProvider` foi (re)construído — proxy do "os
  /// repositórios recebem um LocalDb VÁLIDO" (I5).
  late int localDbBuilds;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      accessTokenStoreProvider.overrideWithValue(access),
      secureTokenStoreProvider.overrideWithValue(secure),
      authRepositoryProvider.overrideWithValue(auth),
      appReloaderProvider.overrideWithValue(reloader),
      // Nunca abre o banco cifrado real (SQLCipher + secure storage) em teste:
      // só contamos as reconstruções do provider.
      localDbProvider.overrideWith((ref) {
        localDbBuilds++;
        return null;
      }),
      // Caminho ONLINE puro: sem banco de credenciais offline (B6 é coberto em
      // offline_login_test.dart) — não toca no `orbix_device.db` nem em plugins.
      offlineCredentialsStoreProvider.overrideWithValue(null),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    localDbBuilds = 0;
    access = AccessTokenStore();
    secure = InMemorySecureTokenStore();
    auth = FakeAuthRepository();
    reloader = _RecordingReloader();
  });

  test(
      'criterion 3: access em memória; refresh persiste no secure APENAS com "manter conectado"',
      () async {
    final container = makeContainer();
    final controller = container.read(sessionControllerProvider.notifier);
    final refresh = container.read(refreshTokenStoreProvider);
    await pumpEventQueue(); // let bootstrap settle (no stored token)

    // Opt-out (default): sessão só em memória, nada no secure storage.
    await controller.login(email: 'dono@teste.com', password: 'senha12345');
    expect(container.read(sessionControllerProvider), isA<SessionAuthenticated>());
    expect(access.token, isNotNull, reason: 'access token lives in memory');
    expect(refresh.token, 'fake-refresh',
        reason: 'refresh token lives in memory for the session');
    expect(await secure.readRefreshToken(), isNull,
        reason: 'sem "manter conectado" NÃO persiste no secure storage');

    // Opt-in: persiste no secure storage (cold start restaura).
    await controller.login(
        email: 'dono@teste.com', password: 'senha12345', remember: true);
    expect(await secure.readRefreshToken(), 'fake-refresh',
        reason: 'com "manter conectado" persiste no secure storage');
  });

  test('criterion 1: logout revokes, clears both stores, goes unauthenticated',
      () async {
    final container = makeContainer();
    final controller = container.read(sessionControllerProvider.notifier);
    await pumpEventQueue();
    await controller.login(email: 'dono@teste.com', password: 'senha12345');

    await controller.logout();

    expect(
        container.read(sessionControllerProvider), isA<SessionUnauthenticated>());
    expect(access.token, isNull);
    expect(await secure.readRefreshToken(), isNull);
    expect(auth.logoutCount, 1);
  });

  test('logout pede reset total do app (limpa todo estado em memória)', () async {
    final container = makeContainer();
    final controller = container.read(sessionControllerProvider.notifier);
    await pumpEventQueue();
    await controller.login(email: 'dono@teste.com', password: 'senha12345');

    await controller.logout();

    expect(reloader.count, 1,
        reason: 'logout deve recarregar o app para não vazar dados entre contas');
  });

  test('expire() também pede reset total do app', () async {
    await secure.writeRefreshToken('seed-refresh');
    final container = makeContainer();
    final controller = container.read(sessionControllerProvider.notifier);
    await pumpEventQueue();

    await controller.expire();

    expect(reloader.count, 1);
  });

  test('bootstrap with a stored refresh token authenticates silently', () async {
    await secure.writeRefreshToken('seed-refresh');
    final container = makeContainer();

    container.read(sessionControllerProvider); // triggers build + bootstrap
    await pumpEventQueue();

    expect(container.read(sessionControllerProvider), isA<SessionAuthenticated>());
    expect(access.token, isNotNull);
    expect(auth.refreshCount, 1);
  });

  test('expire() drops the session (refresh-failure path)', () async {
    await secure.writeRefreshToken('seed-refresh');
    final container = makeContainer();
    final controller = container.read(sessionControllerProvider.notifier);
    await pumpEventQueue();
    expect(container.read(sessionControllerProvider), isA<SessionAuthenticated>());

    await controller.expire();

    expect(
        container.read(sessionControllerProvider), isA<SessionUnauthenticated>());
    expect(access.token, isNull);
    expect(await secure.readRefreshToken(), isNull);
  });

  test(
      'I5: switchTenant que FALHA não deixa os repositórios com um LocalDb '
      'fechado (o provider é reconstruído e a sessão continua a mesma)',
      () async {
    final container = makeContainer();
    final controller = container.read(sessionControllerProvider.notifier);
    await pumpEventQueue();
    await controller.login(email: 'dono@teste.com', password: 'senha12345');
    container.read(localDbProvider); // materializa o banco do tenant atual
    final buildsBefore = localDbBuilds;
    final before = container.read(sessionControllerProvider).meOrNull;

    auth.failSwitchTenant = true;
    await expectLater(
      controller.switchTenant('outro-tenant'),
      throwsA(isA<AppException>()),
    );

    // A sessão (e o tenant ativo) não mudou...
    final after = container.read(sessionControllerProvider).meOrNull;
    expect(after?.activeTenant?.id, before?.activeTenant?.id);
    // ...e o `localDbProvider` foi invalidado: quem ler agora recebe uma
    // instância NOVA/aberta — antes, o banco era fechado ANTES da troca e o
    // provider memoizado seguia entregando a instância FECHADA.
    container.read(localDbProvider);
    expect(localDbBuilds, greaterThan(buildsBefore));
  });
}
