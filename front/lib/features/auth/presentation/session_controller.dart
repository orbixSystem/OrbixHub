import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/access_token_store.dart';
import '../../../core/network/refresh_token_store.dart';
import '../../../core/platform/app_reloader.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../di.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import 'session_state.dart';

/// Owns the session lifecycle. After login / register / refresh / switch-tenant
/// it fetches `/me` and publishes [SessionAuthenticated]. The access token lives
/// in memory ([AccessTokenStore]); the refresh token in secure storage.
class SessionController extends Notifier<SessionState> {
  AuthRepository get _auth => ref.read(authRepositoryProvider);
  AccessTokenStore get _access => ref.read(accessTokenStoreProvider);
  RefreshTokenStore get _refresh => ref.read(refreshTokenStoreProvider);
  SecureTokenStore get _secure => ref.read(secureTokenStoreProvider);
  AppReloader get _reloader => ref.read(appReloaderProvider);

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

  @override
  SessionState build() {
    // Kick off the silent-login attempt; build returns synchronously.
    Future.microtask(_bootstrap);
    return const SessionState.loading();
  }

  Me? get currentMe {
    final s = state;
    return s is SessionAuthenticated ? s.me : null;
  }

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
    } catch (_) {
      await _clear();
      state = const SessionState.unauthenticated();
    }
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
    final res = await _auth.login(email: email, password: password);
    await _applyTokens(res.accessToken, res.refreshToken, remember: remember);
    await _loadMe();
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
    final tokens = await _auth.switchTenant(tenantId);
    await _applyTokens(tokens.accessToken, tokens.refreshToken);
    await _loadMe();
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
    state = SessionState.authenticated(me);
  }

  Future<void> _clear() async {
    _access.clear();
    _refresh.clear();
    await _secure.clear();
  }
}
