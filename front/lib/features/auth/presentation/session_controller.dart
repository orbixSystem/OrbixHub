import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/devtools/dev_role.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/access_token_store.dart';
import '../../../core/network/refresh_token_store.dart';
import '../../../core/network/server_time.dart';
import '../../../core/offline/connectivity_controller.dart';
import '../../../core/offline/db/local_db.dart';
import '../../../core/offline/offline_credentials.dart';
import '../../../core/offline/password_hasher.dart';
import '../../../core/offline/trusted_clock.dart';
import '../../../core/platform/app_reloader.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../di.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import 'session_state.dart';

/// Aviso a ser mostrado na tela de login (âmbar) — ex.: o cold-start não
/// conseguiu falar com a API mas há credencial offline válida neste device.
/// `null` = sem aviso.
class OfflineNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? message) => state = message;

  void clear() => state = null;
}

/// Owns the session lifecycle. After login / register / refresh / switch-tenant
/// it fetches `/me` and publishes [SessionAuthenticated]. The access token lives
/// in memory ([AccessTokenStore]); the refresh token in secure storage.
///
/// B6 — login offline: com falha de REDE (nunca com 401/403), verifica a senha
/// contra o hash argon2id local e publica [SessionOffline] com o snapshot do
/// último `/me`. Regras: janela de 7 dias desde o último login ONLINE (hora do
/// servidor), anti clock-rollback (S3), backoff após 5 erros, revogação da
/// réplica local quando a membership some (S5). Na web, nada disso existe.
class SessionController extends Notifier<SessionState> {
  /// Janela de validade da credencial offline desde o último login online.
  static const offlineWindow = Duration(days: 7);

  /// Erros consecutivos antes do primeiro bloqueio (backoff exponencial).
  static const maxOfflineAttempts = 5;

  /// Teto ABSOLUTO de erros offline — não depende do relógio do device (que o
  /// atacante pode adiantar para vencer o backoff). Atingido, o login offline é
  /// negado até um login ONLINE bem-sucedido zerar o contador.
  static const maxOfflineAttemptsAbsolute = 20;

  static const _expiredMessage =
      'Sua sessão offline expirou. É necessário conectar-se para entrar.';

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  AccessTokenStore get _access => ref.read(accessTokenStoreProvider);
  RefreshTokenStore get _refresh => ref.read(refreshTokenStoreProvider);
  SecureTokenStore get _secure => ref.read(secureTokenStoreProvider);
  AppReloader get _reloader => ref.read(appReloaderProvider);
  OfflineCredentialsStore? get _credentials =>
      kIsWeb ? null : ref.read(offlineCredentialsStoreProvider);
  PasswordHasher get _hasher => ref.read(passwordHasherProvider);
  TrustedClock get _clock => ref.read(trustedClockProvider);
  ServerTimeStore get _serverTime => ref.read(serverTimeStoreProvider);

  /// Aplica os tokens de uma sessão: access só em memória; refresh em memória
  /// (para o refresh 401 funcionar durante a sessão) e — só com "manter
  /// conectado" ([remember]) — também no secure storage (cold-start restaura).
  /// [remember] nulo mantém a preferência atual (refresh/switch-tenant).
  Future<void> _applyTokens(
    String accessToken,
    String refreshToken, {
    bool? remember,
  }) async {
    _access.set(accessToken);
    _refresh.set(refreshToken);
    if (remember != null) _refresh.remember = remember;
    if (_refresh.remember) {
      await _secure.writeRefreshToken(refreshToken);
    } else {
      await _secure.clear();
    }
  }

  /// `me` real (sem override de cargo dev). Usado para reaplicar o override.
  Me? _realMe;

  @override
  SessionState build() {
    // Dev (besouro): reaplica o override de cargo sempre que ele muda, mantendo
    // o resto da sessão. Sem efeito em produção (override fica null).
    ref.listen<String?>(devRoleOverrideProvider, (_, role) {
      final real = _realMe;
      if (real != null) {
        state = SessionState.authenticated(_applyDevRole(real, role));
      }
    });
    // Kick off the silent-login attempt; build returns synchronously.
    Future.microtask(_bootstrap);
    return const SessionState.loading();
  }

  /// Aplica o override de cargo (dev) sobre o `me` real: troca cargo + permissões
  /// pelo mapa do cargo escolhido. `null` = cargo real (no-op). Não toca módulos
  /// (são entitlements do tenant, independem de cargo).
  Me _applyDevRole(Me me, String? role) {
    if (role == null || role.isEmpty) return me;
    return me.copyWith(role: role, permissions: devPermissionsFor(role));
  }

  /// `me` da sessão — online (authenticated) OU offline (B6).
  Me? get currentMe => state.meOrNull;

  /// Cold-start silent login: if a refresh token is stored, exchange it for a
  /// fresh access token and load `/me`; otherwise we're unauthenticated.
  Future<void> _bootstrap() async {
    // Só há token no secure storage se a sessão anterior marcou "manter
    // conectado" — a presença do token É o sinal de remember.
    final refreshToken = await _secure.readRefreshToken();
    if (refreshToken == null) {
      state = const SessionState.unauthenticated();
      return;
    }
    try {
      final tokens = await _auth.refresh(refreshToken);
      await _applyTokens(tokens.accessToken, tokens.refreshToken,
          remember: true);
      await _loadMe();
    } catch (e) {
      // B6 — falha de REDE (não 401): o refresh token continua válido no
      // servidor; não pode ser descartado. Se há credencial offline neste
      // device, cai na tela de login COM aviso (o usuário entra offline
      // digitando a senha) em vez de "sessão morta".
      if (_isNetworkFailure(e) && await _hasOfflineCredential()) {
        ref.read(offlineNoticeProvider.notifier).set(
              'Sem conexão com o servidor — entre para usar o modo offline.',
            );
        state = const SessionState.unauthenticated();
        return;
      }
      await _clear();
      state = const SessionState.unauthenticated();
    }
  }

  bool _isNetworkFailure(Object e) => e is AppException && e.isNetwork;

  /// Roda uma operação do banco de credenciais offline em modo "best-effort":
  /// se o banco do device não abrir (plataforma sem suporte, disco cheio, banco
  /// corrompido), o app NÃO pode ficar impedido de logar online — só perde a
  /// capacidade offline. Nunca engole erro do caminho de login offline em si
  /// (esse propaga: é a resposta ao usuário).
  Future<T?> _offlineSafe<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasOfflineCredential() async {
    final store = _credentials;
    if (store == null) return false;
    final creds = await _offlineSafe(store.list);
    return creds != null && creds.isNotEmpty;
  }

  /// Logs in. Throws [AppException] on failure (the screen shows it inline);
  /// on success transitions to [SessionAuthenticated].
  /// [remember] = "manter conectado": quando `false` (padrão), o refresh fica
  /// só em memória (sessão vale até fechar o app); quando `true`, também vai ao
  /// secure storage e o cold-start restaura a sessão.
  Future<void> login({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    final LoginResult res;
    try {
      // SÓ a autenticação em si pode cair no fallback offline. Depois que o
      // servidor emitiu tokens, uma falha de rede posterior (ex.: no `/me`) NÃO
      // pode rebaixar a sessão para um snapshot velho — ela propaga como erro.
      res = await _auth.login(email: email, password: password);
    } on AppException catch (e) {
      // Só falha de REDE cai no offline. 401/403 (senha errada, sem acesso)
      // continua sendo erro online — o modo offline não é um bypass.
      if (!kIsWeb && e.isNetwork && _credentials != null) {
        await _loginOffline(email: email, password: password);
        return;
      }
      rethrow;
    }
    await _applyTokens(res.accessToken, res.refreshToken, remember: remember);
    await _loadMe();
    ref.read(offlineNoticeProvider.notifier).clear();
    await _rememberForOffline(email: email, password: password);
  }

  /// Grava/atualiza a credencial offline após um login ONLINE bem-sucedido:
  /// hash argon2id da senha (a senha em claro nunca é persistida), snapshot do
  /// `/me` e a hora do SERVIDOR (header `Date`) como `lastOnlineLoginAt`.
  /// Também alimenta o relógio confiável (S3).
  Future<void> _rememberForOffline({
    required String email,
    required String password,
  }) async {
    final store = _credentials;
    final me = _realMe;
    if (store == null || me == null) return;

    // Sem tenant ativo não há réplica local nem alvo para o wipe do S5 — gravar
    // a credencial com `tenantId` vazio criaria um registro que a revogação
    // nunca alcança. Ela é gravada no próximo `/me` COM tenant (switch-tenant).
    final tenantId = me.activeTenant?.id;
    if (tenantId == null || tenantId.isEmpty) return;

    await _offlineSafe(() async {
      // Hora do servidor; sem nenhuma resposta observada (fake/edge), cai no
      // relógio do device — que o TrustedClock (S3) ainda vigia.
      final serverNow = _serverTime.lastServerTime ?? _clock.now;
      await _clock.observe(serverNow);

      await store.save(
        OfflineCredential(
          email: email,
          userId: me.user.id,
          tenantId: tenantId,
          passwordHash: _hasher.hash(password),
          meSnapshot: jsonEncode(me.toJson()),
          lastOnlineLoginAt: serverNow,
        ),
      );
    });
  }

  /// B6 — login offline. Falha lançando [AppException] com mensagem PT-BR; em
  /// caso de sucesso publica [SessionOffline] com o snapshot do `/me`.
  Future<void> _loginOffline({
    required String email,
    required String password,
  }) async {
    final store = _credentials!;
    // Banco do device indisponível ⇒ trate como "sem credencial" (erro de rede
    // normal); nunca como um erro cru vazando para a tela.
    final cred = await _offlineSafe(() => store.find(email));
    if (cred == null) {
      // Ninguém logou online com este e-mail neste device: é só falta de rede.
      throw const AppException(
        statusCode: null,
        error: 'Network',
        message: 'Sem conexão com o servidor. '
            'Faça o primeiro acesso deste dispositivo conectado.',
      );
    }

    // CONTRATO (S3): o `max_seen_ts` persistido é carregado de forma assíncrona
    // — ler `clockRolledBack` antes de `ready` daria falso negativo no cold
    // start. Se o carregamento FALHAR, não há como provar que o relógio não foi
    // manipulado: nega o login offline (fail-safe).
    final clock = _clock;
    var clockReady = true;
    try {
      await clock.ready;
    } catch (_) {
      clockReady = false;
    }
    final now = clock.now;

    if (!clockReady || clock.clockRolledBack) {
      throw const AppException(
        statusCode: null,
        error: 'OfflineExpired',
        message: _expiredMessage,
      );
    }

    // Cap ABSOLUTO (independente de relógio): o lock exponencial usa `now` do
    // device, que pode ser adiantado à vontade para "vencer" cada bloqueio e
    // seguir com o brute-force (o TrustedClock/S3 só pega relógio ATRASADO).
    // Estourado o teto de tentativas, só um login ONLINE bem-sucedido (que
    // regrava a credencial com o contador zerado) reabre o modo offline.
    if (cred.failedAttempts >= maxOfflineAttemptsAbsolute) {
      throw const AppException(
        statusCode: null,
        error: 'OfflineLockedOut',
        message: 'Muitas tentativas. Conecte-se à internet para entrar.',
      );
    }

    final lockedUntil = cred.lockedUntil;
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      final minutes = math.max(1, lockedUntil.difference(now).inMinutes + 1);
      throw AppException(
        statusCode: null,
        error: 'OfflineLocked',
        message: 'Muitas tentativas. Tente novamente em $minutes min.',
      );
    }

    if (now.difference(cred.lastOnlineLoginAt) > offlineWindow) {
      throw const AppException(
        statusCode: null,
        error: 'OfflineExpired',
        message: _expiredMessage,
      );
    }

    if (!_hasher.verify(password, cred.passwordHash)) {
      final attempts = cred.failedAttempts + 1;
      await store.save(
        cred.copyWith(
          failedAttempts: attempts,
          lockedUntil: attempts >= maxOfflineAttempts
              ? now.add(_backoff(attempts))
              : null,
          clearLock: attempts < maxOfflineAttempts,
        ),
      );
      throw const AppException(
        statusCode: null,
        error: 'OfflineUnauthorized',
        message: 'E-mail ou senha inválidos.',
      );
    }

    await store.save(cred.copyWith(failedAttempts: 0, clearLock: true));

    final me = Me.fromJson(jsonDecode(cred.meSnapshot) as Map<String, dynamic>);
    _realMe = me;
    ref
        .read(offlineNoticeProvider.notifier)
        .set('Sem conexão — entrando no modo offline.');
    state = SessionState.offline(
      _applyDevRole(me, ref.read(devRoleOverrideProvider)),
    );
    _watchReconnect();
  }

  /// Backoff exponencial a partir da 5ª falha: 1, 2, 4, 8… minutos (teto 60).
  Duration _backoff(int attempts) {
    final steps = attempts - maxOfflineAttempts; // 0, 1, 2, ...
    final minutes = math.min(60, 1 << math.min(steps, 6));
    return Duration(minutes: minutes);
  }

  /// Assina o indicador de conectividade SÓ quando há sessão offline — assim
  /// nenhuma outra tela/teste instancia o ConnectivityController à toa.
  ProviderSubscription<ConnState>? _connSub;

  void _watchReconnect() {
    _connSub ??= ref.listen<ConnState>(connectivityControllerProvider, (_, next) {
      if (next.status != ConnStatus.offline && state is SessionOffline) {
        unawaited(_tryReconnect());
      }
    });
  }

  /// Voltou a rede com uma sessão offline aberta: tenta um refresh REAL e migra
  /// `offline → authenticated`. O push do outbox é do SyncEngine (B7). Sem
  /// refresh token guardado (login offline puro, sem "manter conectado"), não há
  /// o que renovar — a sessão segue offline até o usuário logar online.
  bool _reconnecting = false;

  Future<void> _tryReconnect() async {
    if (_reconnecting || state is! SessionOffline) return;
    _reconnecting = true;
    try {
      final token = _refresh.token ?? await _secure.readRefreshToken();
      if (token == null) return;
      final tokens = await _auth.refresh(token);
      await _applyTokens(tokens.accessToken, tokens.refreshToken);
      await _loadMe();
    } catch (_) {
      // Ainda sem rede / refresh recusado: permanece offline (a UI não muda).
    } finally {
      _reconnecting = false;
    }
  }

  Future<void> register({
    required String tenantName,
    required String slug,
    required String cnpj,
    required String legalName,
    String? tradeName,
    required String fullName,
    required String email,
    required String password,
    String? vertical,
  }) async {
    final res = await _auth.register(
      tenantName: tenantName,
      slug: slug,
      cnpj: cnpj,
      legalName: legalName,
      tradeName: tradeName,
      fullName: fullName,
      email: email,
      password: password,
      vertical: vertical,
    );
    // Criação de conta: mantém conectado (persiste).
    await _applyTokens(res.accessToken, res.refreshToken, remember: true);
    await _loadMe();
  }

  /// Accepts a team invite (public) and signs the new member in.
  Future<void> acceptInvite({
    required String token,
    String? fullName,
    required String password,
  }) async {
    final tokens = await _auth.acceptInvite(
      token: token,
      fullName: fullName,
      password: password,
    );
    await _applyTokens(tokens.accessToken, tokens.refreshToken,
        remember: true);
    await _loadMe();
  }

  /// Switches active workshop and reloads `/me` (new role/modules). Preserva a
  /// preferência de "manter conectado" da sessão atual.
  Future<void> switchTenant(String tenantId) async {
    final previousTenantId = state.meOrNull?.activeTenant?.id;
    // B7 — para o SyncEngine do tenant anterior (aguardando a rodada em voo),
    // mas NÃO fecha o banco ainda: se a troca FALHAR (rede instável), o tenant
    // ativo continua o mesmo e o `localDbProvider` (memoizado) devolveria uma
    // instância FECHADA a todos os repositórios — "database is closed" em cada
    // leitura/escrita offline até reiniciar o app.
    await _stopSyncEngine();
    try {
      final tokens = await _auth.switchTenant(tenantId);
      await _applyTokens(tokens.accessToken, tokens.refreshToken);
      await _loadMe();
    } catch (_) {
      // Nada mudou: força a reconstrução do `localDbProvider`/`syncEngineProvider`
      // (o banco continua aberto; o engine parado volta a ser criado e ligado).
      ref.invalidate(localDbProvider);
      rethrow;
    }
    // Sucesso: o `/me` novo já reconstruiu o `localDbProvider` no banco do tenant
    // NOVO — agora sim fecha só o banco do ANTERIOR (`closeAll` fecharia também
    // o que acabou de ser aberto).
    if (!kIsWeb &&
        previousTenantId != null &&
        previousTenantId != state.meOrNull?.activeTenant?.id) {
      try {
        await LocalDb.closeForTenant(previousTenantId);
      } catch (_) {
        // Fechar o banco antigo nunca pode derrubar a troca de oficina.
      }
    }
  }

  Future<void> logout() async {
    // Refresh vem da memória (a sessão pode não estar persistida no secure).
    final refreshToken = _refresh.token ?? await _secure.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _auth.logout(refreshToken);
      } catch (_) {
        // Best-effort server revoke; local clear happens regardless.
      }
    }
    await _clear();
    state = const SessionState.unauthenticated();
    // Reset total: descarta TODO o estado em memória (providers de todas as
    // features, access token) para que dados da conta anterior nunca vazem ao
    // logar em outra conta. Na web é um reload da página; no-op fora dela.
    _reloader.reload();
  }

  /// Called by the network layer when refresh fails — drop to unauthenticated.
  Future<void> expire() async {
    await _clear();
    state = const SessionState.unauthenticated();
    _reloader.reload();
  }

  Future<void> reloadMe() => _loadMe();

  Future<void> _loadMe() async {
    final me = await _auth.fetchMe();
    await _revokeStaleReplica(me);
    _realMe = me;
    state = SessionState.authenticated(
      _applyDevRole(me, ref.read(devRoleOverrideProvider)),
    );
  }

  /// S5 — revogação da réplica: se o `/me` fresco não traz mais a membership do
  /// tenant que este usuário replicou neste device (removido da oficina/
  /// desabilitado), o banco local daquele tenant é APAGADO e a credencial
  /// offline some — o device deixa de ser uma porta de entrada.
  Future<void> _revokeStaleReplica(Me me) async {
    final store = _credentials;
    if (store == null) return;
    await _offlineSafe(() async {
      final cred = await store.find(me.user.email);
      if (cred == null || cred.tenantId.isEmpty) return;

      final stillMember = me.memberships.any((m) => m.tenantId == cred.tenantId);
      if (stillMember) return;

      await LocalDb.deleteDbForTenant(cred.tenantId);
      await store.remove(cred.email);
    });
  }

  Future<void> _clear() async {
    _access.clear();
    _refresh.clear();
    // B6 — o aviso âmbar vale para UMA tentativa/sessão: sem limpar aqui, a tela
    // de login seguiria exibindo "Sem conexão — entrando no modo offline" depois
    // do logout/expire, mesmo com a rede de volta.
    ref.read(offlineNoticeProvider.notifier).clear();
    await _secure.clear();
    // B7 — logout/expire: fecha as réplicas locais abertas (os arquivos ficam,
    // a sessão offline do B6 depende deles; só as conexões são liberadas).
    await _closeLocalDbs();
  }

  /// Para o SyncEngine (aguardando a rodada em voo) e fecha as instâncias de
  /// [LocalDb] cacheadas por tenant. No-op na web.
  ///
  /// A ordem importa: fechar o banco com uma rodada de sync em voo seria
  /// use-after-close (erro não tratado). `ref.exists` evita CRIAR o engine só
  /// para pará-lo (o que dispararia um sync durante o logout).
  Future<void> _closeLocalDbs() async {
    if (kIsWeb) return;
    try {
      await _stopSyncEngine();
      await LocalDb.closeAll();
    } catch (_) {
      // Fechar o banco nunca pode impedir o logout/troca de oficina.
    }
  }

  /// Para o SyncEngine e AGUARDA a rodada em voo (nunca feche o banco antes).
  /// `ref.exists` evita CRIAR o engine só para pará-lo (o que dispararia um sync).
  Future<void> _stopSyncEngine() async {
    if (kIsWeb) return;
    try {
      if (ref.exists(syncEngineProvider)) {
        await ref.read(syncEngineProvider)?.stop();
      }
    } catch (_) {
      // idem: nunca bloqueia o fluxo de sessão.
    }
  }
}
