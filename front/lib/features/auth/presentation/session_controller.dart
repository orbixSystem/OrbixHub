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
/// it fetches `/me` and publishes [SessionAuthenticated].
///
/// Token layers: the access token lives in memory ([AccessTokenStore]); the
/// refresh token lives in memory ([RefreshTokenStore]) for the current session,
/// and is ALSO persisted to secure storage ([SecureTokenStore]) only when the
/// session opted into "Manter conectado" ([RefreshTokenStore.remember]). A cold
/// start restores the session only if a token was persisted.
class SessionController extends Notifier<SessionState> {
  AuthRepository get _auth => ref.read(authRepositoryProvider);
  AccessTokenStore get _access => ref.read(accessTokenStoreProvider);
  RefreshTokenStore get _refresh => ref.read(refreshTokenStoreProvider);
  SecureTokenStore get _secure => ref.read(secureTokenStoreProvider);
  AppReloader get _reloader => ref.read(appReloaderProvider);

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

  /// Cold-start silent login: only when a refresh token was PERSISTED (the user
  /// opted into "Manter conectado"). Exchange it for a fresh access token and
  /// load `/me`; otherwise we're unauthenticated.
  Future<void> _bootstrap() async {
    final refreshToken = await _secure.readRefreshToken();
    if (refreshToken == null) {
      state = const SessionState.unauthenticated();
      return;
    }
    // A persisted token means the session was "remembered".
    _refresh.remember = true;
    _refresh.set(refreshToken);
    try {
      final tokens = await _auth.refresh(refreshToken);
      _access.set(tokens.accessToken);
      _refresh.set(tokens.refreshToken);
      await _secure.writeRefreshToken(tokens.refreshToken);
      await _loadMe();
    } catch (_) {
      await _clear();
      state = const SessionState.unauthenticated();
    }
  }

  /// Logs in. [remember] persists the refresh token so a cold start restores
  /// the session (~1 month); when false the session is memory-only and closing
  /// the app requires signing in again. Throws [AppException] on failure.
  Future<void> login({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    final res = await _auth.login(email: email, password: password);
    await _establishSession(res.accessToken, res.refreshToken, remember: remember);
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
    // A brand-new signup stays logged in (persisted).
    await _establishSession(res.accessToken, res.refreshToken, remember: true);
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
    await _establishSession(tokens.accessToken, tokens.refreshToken,
        remember: true);
  }

  /// Switches active workshop and reloads `/me` (new role/modules). Preserves
  /// the current session's persistence choice.
  Future<void> switchTenant(String tenantId) async {
    final tokens = await _auth.switchTenant(tenantId);
    await _establishSession(tokens.accessToken, tokens.refreshToken,
        remember: _refresh.remember);
  }

  /// Sets the access token in memory and the refresh token in memory + (iff
  /// [remember]) secure storage, then loads `/me`.
  Future<void> _establishSession(
    String accessToken,
    String refreshToken, {
    required bool remember,
  }) async {
    _access.set(accessToken);
    _refresh.remember = remember;
    _refresh.set(refreshToken);
    if (remember) {
      await _secure.writeRefreshToken(refreshToken);
    } else {
      // Never leave a stale persisted token behind for a memory-only session.
      await _secure.clear();
    }
    await _loadMe();
  }

  Future<void> logout() async {
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
