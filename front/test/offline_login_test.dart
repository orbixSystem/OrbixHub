import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/network/access_token_store.dart';
import 'package:orbixhub_front/core/network/server_time.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/offline/db/db_native.dart' as db_native;
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/offline_credentials.dart';
import 'package:orbixhub_front/core/offline/password_hasher.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/core/platform/app_reloader.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/data/fake_auth_repository.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'session_controller_test.dart' show InMemorySecureTokenStore;

/// B6 — login offline (argon2id local, janela de 7 dias, S3/S4/S5).

/// AuthRepository fake com controle de REDE (offline) vs. credencial inválida
/// (401): a distinção é o coração do B6 — senha errada COM rede continua sendo
/// senha errada; só falha de rede cai no caminho offline.
class _FakeAuth extends FakeAuthRepository {
  static const _network = AppException(
    statusCode: null,
    error: 'Network',
    message: 'Sem conexão com o servidor.',
  );
  static const _badCredentials = AppException(
    statusCode: 401,
    error: 'Unauthorized',
    message: 'E-mail ou senha inválidos.',
  );

  bool networkDown = false;
  bool badCredentials = false;
  int fetchMeCount = 0;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) {
    if (networkDown) throw _network;
    if (badCredentials) throw _badCredentials;
    return super.login(email: email, password: password);
  }

  @override
  Future<Tokens> refresh(String refreshToken) {
    if (networkDown) throw _network;
    return super.refresh(refreshToken);
  }

  @override
  Future<Me> fetchMe() {
    fetchMeCount++;
    if (networkDown) throw _network;
    return super.fetchMe();
  }
}

/// Store de credenciais em memória (o drift real é coberto por um teste próprio
/// abaixo — aqui interessa a lógica do controller, não a persistência).
class _MemStore implements OfflineCredentialsStore {
  final Map<String, OfflineCredential> rows = {};

  @override
  Future<OfflineCredential?> find(String email) => Future.value(
        rows[email.trim().toLowerCase()],
      );

  @override
  Future<List<OfflineCredential>> list() => Future.value(rows.values.toList());

  @override
  Future<void> save(OfflineCredential c) async {
    rows[c.email] = c;
  }

  @override
  Future<void> remove(String email) async {
    rows.remove(email.trim().toLowerCase());
  }

  @override
  Future<void> close() async {}
}

Me _meWith({List<Membership>? memberships}) => Me(
      user: const User(
        id: 'u1',
        email: 'dono@teste.com',
        fullName: 'Dono Teste',
        emailVerified: true,
      ),
      activeTenant:
          const Tenant(id: 't1', slug: 'oficina-teste', name: 'Oficina Teste'),
      role: 'owner',
      permissions: const ['os.read', 'os.write'],
      modules: const ['os', 'customers'],
      memberships: memberships ??
          const [
            Membership(tenantId: 't1', tenantSlug: 'oficina-teste', role: 'owner'),
          ],
    );

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  const password = 'senha12345';
  const email = 'dono@teste.com';

  late AccessTokenStore access;
  late InMemorySecureTokenStore secure;
  late _FakeAuth auth;
  late _MemStore store;
  late ServerTimeStore serverTime;
  late DateTime deviceNow;
  late StreamController<List<ConnectivityResult>> conn;
  late bool reachable;

  /// Instante "servidor" do último login online bem-sucedido.
  final loginAt = DateTime.utc(2026, 7, 1, 12);

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      accessTokenStoreProvider.overrideWithValue(access),
      secureTokenStoreProvider.overrideWithValue(secure),
      authRepositoryProvider.overrideWithValue(auth),
      appReloaderProvider.overrideWithValue(AppReloader()),
      offlineCredentialsStoreProvider.overrideWithValue(store),
      serverTimeStoreProvider.overrideWithValue(serverTime),
      trustedClockProvider.overrideWith(
        (ref) => TrustedClock(clock: () => deviceNow),
      ),
      // Conectividade: stream controlável + ping fake (nenhum canal/HTTP real).
      connectivityStreamProvider.overrideWithValue(conn.stream),
      healthPingProvider.overrideWithValue(() async => reachable),
      pingIntervalProvider.overrideWithValue(const Duration(hours: 1)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    access = AccessTokenStore();
    secure = InMemorySecureTokenStore();
    auth = _FakeAuth()..seedMe(_meWith());
    store = _MemStore();
    serverTime = ServerTimeStore()..observe(loginAt);
    deviceNow = loginAt;
    conn = StreamController<List<ConnectivityResult>>.broadcast();
    reachable = false;
    addTearDown(conn.close);
  });

  tearDown(() async {
    db_native.supportDirOverride = null;
    db_native.executorFactory = null;
    await LocalDb.closeAll();
  });

  /// Login online bem-sucedido → semeia a credencial offline no store.
  Future<ProviderContainer> onlineLogin() async {
    final c = makeContainer();
    final controller = c.read(sessionControllerProvider.notifier);
    await pumpEventQueue();
    await controller.login(email: email, password: password, remember: true);
    return c;
  }

  test('login online salva credencial + snapshot do /me + hora do SERVIDOR',
      () async {
    final c = await onlineLogin();

    expect(c.read(sessionControllerProvider), isA<SessionAuthenticated>());
    final cred = await store.find(email);
    expect(cred, isNotNull, reason: 'credencial offline foi gravada');
    expect(cred!.userId, 'u1');
    expect(cred.tenantId, 't1');
    expect(cred.lastOnlineLoginAt, loginAt,
        reason: 'hora do SERVIDOR (header Date), não o relógio do device');
    expect(cred.failedAttempts, 0);
    expect(cred.passwordHash.startsWith(r'$argon2id$'), isTrue,
        reason: 'S4 — argon2id; a senha em claro nunca é persistida');
    expect(cred.passwordHash.contains(password), isFalse);
    expect(
      Me.fromJson(jsonDecode(cred.meSnapshot) as Map<String, dynamic>).modules,
      ['os', 'customers'],
      reason: 'snapshot do /me utilizável offline',
    );
    // S3 — o login online alimenta o relógio confiável.
    expect(c.read(trustedClockProvider).maxSeenTs, loginAt);
  });

  test('offline (falha de rede) + senha certa → SessionState.offline', () async {
    await onlineLogin();

    auth.networkDown = true;
    final c2 = makeContainer();
    final controller = c2.read(sessionControllerProvider.notifier);
    await pumpEventQueue();
    final before = auth.fetchMeCount;

    await controller.login(email: email, password: password);

    final s = c2.read(sessionControllerProvider);
    expect(s, isA<SessionOffline>());
    expect((s as SessionOffline).me.modules, ['os', 'customers']);
    expect(s.me.user.id, 'u1');
    expect(auth.fetchMeCount, before,
        reason: 'sessão offline não dispara chamadas de rede');
    expect(s.meOrNull, isNotNull, reason: 'guards tratam offline como logado');
  });

  test('senha errada COM rede (401) NÃO cai no modo offline', () async {
    await onlineLogin();

    auth.badCredentials = true;
    final c2 = makeContainer();
    final controller = c2.read(sessionControllerProvider.notifier);
    await pumpEventQueue();

    await expectLater(
      controller.login(email: email, password: 'errada'),
      throwsA(isA<AppException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(c2.read(sessionControllerProvider), isNot(isA<SessionOffline>()));
  });

  test('senha errada 5x offline → bloqueio com backoff (lockedUntil)', () async {
    await onlineLogin();

    auth.networkDown = true;
    final c2 = makeContainer();
    final controller = c2.read(sessionControllerProvider.notifier);
    await pumpEventQueue();

    for (var i = 0; i < 5; i++) {
      await expectLater(
        controller.login(email: email, password: 'errada$i'),
        throwsA(isA<AppException>()),
      );
    }

    final cred = await store.find(email);
    expect(cred!.failedAttempts, 5);
    expect(cred.lockedUntil, isNotNull, reason: 'backoff após 5 falhas');
    expect(cred.lockedUntil!.isAfter(deviceNow), isTrue);

    // Mesmo com a senha CERTA, o bloqueio vale enquanto durar.
    await expectLater(
      controller.login(email: email, password: password),
      throwsA(isA<AppException>()
          .having((e) => e.message, 'msg', contains('Muitas tentativas'))),
    );
    expect(c2.read(sessionControllerProvider), isNot(isA<SessionOffline>()));

    // Passado o bloqueio, a senha certa entra e zera o contador.
    deviceNow = cred.lockedUntil!.add(const Duration(seconds: 1));
    await controller.login(email: email, password: password);
    expect(c2.read(sessionControllerProvider), isA<SessionOffline>());
    expect((await store.find(email))!.failedAttempts, 0);
  });

  test(
      'cap absoluto: adiantar o relógio NÃO vence o bloqueio depois de 20 erros',
      () async {
    await onlineLogin();

    auth.networkDown = true;
    final c2 = makeContainer();
    final controller = c2.read(sessionControllerProvider.notifier);
    await pumpEventQueue();

    // O atacante com o device na mão: a cada bloqueio, adianta o relógio para
    // "vencer" o backoff (o TrustedClock/S3 só denuncia relógio ATRASADO) e
    // continua o brute-force. Depois de 20 erros o cap absoluto fecha a porta.
    for (var i = 0; i < 20; i++) {
      await expectLater(
        controller.login(email: email, password: 'errada$i'),
        throwsA(isA<AppException>()),
      );
      final lock = (await store.find(email))!.lockedUntil;
      if (lock != null) deviceNow = lock.add(const Duration(seconds: 1));
    }
    expect((await store.find(email))!.failedAttempts, 20);

    // Mesmo com o relógio adiantado (nenhum lock vigente) e a senha CERTA:
    // negado até um login ONLINE.
    deviceNow = deviceNow.add(const Duration(hours: 5));
    await expectLater(
      controller.login(email: email, password: password),
      throwsA(isA<AppException>().having(
        (e) => e.message,
        'msg',
        contains('Conecte-se à internet para entrar.'),
      )),
    );
    expect(c2.read(sessionControllerProvider), isNot(isA<SessionOffline>()));

    // Um login ONLINE bem-sucedido regrava a credencial e zera o contador.
    auth.networkDown = false;
    deviceNow = loginAt;
    await controller.login(email: email, password: password);
    expect((await store.find(email))!.failedAttempts, 0);
  });

  test('aviso offline é limpo no logout (não sobra na tela de login)', () async {
    await onlineLogin();

    auth.networkDown = true;
    final c2 = makeContainer();
    final controller = c2.read(sessionControllerProvider.notifier);
    await pumpEventQueue();
    await controller.login(email: email, password: password);
    expect(c2.read(sessionControllerProvider), isA<SessionOffline>());
    expect(c2.read(offlineNoticeProvider), isNotNull);

    await controller.logout();

    expect(c2.read(offlineNoticeProvider), isNull,
        reason: 'o banner âmbar não pode persistir depois do logout');
  });

  test('credencial com mais de 7 dias → expirada (precisa conectar)', () async {
    await onlineLogin();

    auth.networkDown = true;
    deviceNow = loginAt.add(const Duration(days: 7, minutes: 1));
    final c2 = makeContainer();
    final controller = c2.read(sessionControllerProvider.notifier);
    await pumpEventQueue();

    await expectLater(
      controller.login(email: email, password: password),
      throwsA(isA<AppException>().having(
        (e) => e.message,
        'msg',
        contains('É necessário conectar-se para entrar.'),
      )),
    );
    expect(c2.read(sessionControllerProvider), isNot(isA<SessionOffline>()));
  });

  test('S3: relógio voltado (max_seen_ts persistido) → expirada', () async {
    await onlineLogin();

    // Cold start: o `max_seen_ts` só existe no disco (SharedPreferences) — o
    // TrustedClock novo ainda NÃO carregou. Se o controller ler `clockRolledBack`
    // antes de `await clock.ready`, o rollback passa despercebido e o login
    // offline é aceito → este teste falha. É a prova do contrato.
    auth.networkDown = true;
    deviceNow = loginAt.subtract(const Duration(days: 3)); // relógio para trás
    final c2 = makeContainer();
    final controller = c2.read(sessionControllerProvider.notifier);
    await pumpEventQueue();

    await expectLater(
      controller.login(email: email, password: password),
      throwsA(isA<AppException>().having(
        (e) => e.message,
        'msg',
        contains('É necessário conectar-se para entrar.'),
      )),
    );
    expect(c2.read(sessionControllerProvider), isNot(isA<SessionOffline>()));
  });

  test('sem store offline (web/online-only) → falha de rede vira erro normal',
      () async {
    // Na web `offlineCredentialsStoreProvider` é null — nenhum caminho offline.
    final c = ProviderContainer(overrides: [
      accessTokenStoreProvider.overrideWithValue(access),
      secureTokenStoreProvider.overrideWithValue(secure),
      authRepositoryProvider.overrideWithValue(auth),
      appReloaderProvider.overrideWithValue(AppReloader()),
      offlineCredentialsStoreProvider.overrideWithValue(null),
      serverTimeStoreProvider.overrideWithValue(serverTime),
      trustedClockProvider.overrideWith(
        (ref) => TrustedClock(clock: () => deviceNow),
      ),
    ]);
    addTearDown(c.dispose);
    final controller = c.read(sessionControllerProvider.notifier);
    await pumpEventQueue();
    auth.networkDown = true;

    await expectLater(
      controller.login(email: email, password: password),
      throwsA(isA<AppException>().having((e) => e.isNetwork, 'isNetwork', true)),
    );
    expect(c.read(sessionControllerProvider), isNot(isA<SessionOffline>()));
  });

  test('S5: membership revogada no /me → apaga o banco local + a credencial',
      () async {
    final tmp = await Directory.systemTemp.createTemp('orbix_b6');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    db_native.supportDirOverride = () async => tmp;
    db_native.executorFactory = (id, file) async => NativeDatabase(file);

    final c = await onlineLogin();
    // Réplica local do tenant t1 existe no disco.
    final db = LocalDb.forTenant('t1');
    await db.saveCursor('customer', ts: 'x', id: 'y');
    final file = File(p.join(tmp.path, 'orbix_t1.db'));
    expect(await file.exists(), isTrue);
    expect(await store.find(email), isNotNull);

    // O usuário foi removido da oficina: o /me volta sem a membership de t1.
    auth.seedMe(_meWith(memberships: const []));
    await c.read(sessionControllerProvider.notifier).reloadMe();

    expect(await file.exists(), isFalse, reason: 'S5: réplica local apagada');
    expect(await store.find(email), isNull,
        reason: 'S5: credencial offline removida');
  });

  test('bootstrap: refresh falha por rede + credencial válida → aviso offline',
      () async {
    await onlineLogin();

    auth.networkDown = true;
    final c2 = makeContainer();
    c2.read(sessionControllerProvider); // dispara o bootstrap
    await pumpEventQueue();

    expect(c2.read(sessionControllerProvider), isA<SessionUnauthenticated>(),
        reason: 'vai para a tela de login — com aviso, não como sessão morta');
    expect(c2.read(offlineNoticeProvider), isNotNull);
    expect(await secure.readRefreshToken(), isNotNull,
        reason: 'falha de REDE não pode descartar o refresh token válido');
  });

  test('reconexão: sessão offline volta a ser online (authenticated)', () async {
    await onlineLogin();

    auth.networkDown = true;
    final c2 = makeContainer();
    final controller = c2.read(sessionControllerProvider.notifier);
    await pumpEventQueue();
    await controller.login(email: email, password: password, remember: true);
    expect(c2.read(sessionControllerProvider), isA<SessionOffline>());

    // A rede volta: o indicador vira online e a sessão migra para real.
    auth.networkDown = false;
    reachable = true;
    conn.add([ConnectivityResult.wifi]);
    await pumpEventQueue();

    expect(c2.read(sessionControllerProvider), isA<SessionAuthenticated>());
  });

  group('PasswordHasher (S4 — argon2id 64MB / 3 iterações)', () {
    test('hash/verify round-trip; parâmetros no encoded', () {
      const hasher = PasswordHasher();
      final encoded = hasher.hash(password);

      expect(encoded.startsWith(r'$argon2id$'), isTrue);
      expect(encoded.contains('m=65536'), isTrue, reason: '64 MB');
      expect(encoded.contains('t=3'), isTrue, reason: '3 iterações');
      expect(hasher.verify(password, encoded), isTrue);
      expect(hasher.verify('outra-senha', encoded), isFalse);
    });

    test('salt aleatório: dois hashes da mesma senha diferem', () {
      const hasher = PasswordHasher();
      expect(hasher.hash(password), isNot(hasher.hash(password)));
    });
  });

  group('DriftOfflineCredentialsStore (device-scoped)', () {
    test('save/find/remove round-trip', () async {
      final db = DeviceDb(NativeDatabase.memory());
      addTearDown(db.close);
      final s = DriftOfflineCredentialsStore(db);

      final cred = OfflineCredential(
        email: 'Dono@Teste.com',
        userId: 'u1',
        tenantId: 't1',
        passwordHash: r'$argon2id$fake',
        meSnapshot: '{}',
        lastOnlineLoginAt: loginAt,
      );
      await s.save(cred);

      final found = await s.find('dono@teste.com');
      expect(found, isNotNull);
      expect(found!.email, 'dono@teste.com', reason: 'e-mail normalizado');
      expect(found.lastOnlineLoginAt, loginAt);
      expect(found.failedAttempts, 0);

      // Multi-usuário no mesmo device.
      await s.save(cred.copyWith(email: 'mecanico@teste.com', userId: 'u2'));
      expect(await s.list(), hasLength(2));

      await s.remove('DONO@TESTE.COM');
      expect(await s.find('dono@teste.com'), isNull);
      expect(await s.list(), hasLength(1));
    });
  });
}
