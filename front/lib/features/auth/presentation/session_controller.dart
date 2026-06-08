import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/access_token_store.dart';
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
  SecureTokenStore get _secure => ref.read(secureTokenStoreProvider);

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
    final refreshToken = await _secure.readRefreshToken();
    if (refreshToken == null) {
      state = const SessionState.unauthenticated();
      return;
    }
    try {
      final tokens = await _auth.refresh(refreshToken);
      _access.set(tokens.accessToken);
      await _secure.writeRefreshToken(tokens.refreshToken);
      await _loadMe();
    } catch (_) {
      await _clear();
      state = const SessionState.unauthenticated();
    }
  }

  /// Logs in. Throws [AppException] on failure (the screen shows it inline);
  /// on success transitions to [SessionAuthenticated].
  Future<void> login({required String email, required String password}) async {
    final res = await _auth.login(email: email, password: password);
    _access.set(res.accessToken);
    await _secure.writeRefreshToken(res.refreshToken);
    await _loadMe();
  }

  Future<void> register({
    required String tenantName,
    required String slug,
    required String fullName,
    required String email,
    required String password,
  }) async {
    final res = await _auth.register(
      tenantName: tenantName,
      slug: slug,
      fullName: fullName,
      email: email,
      password: password,
    );
    _access.set(res.accessToken);
    await _secure.writeRefreshToken(res.refreshToken);
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
    _access.set(tokens.accessToken);
    await _secure.writeRefreshToken(tokens.refreshToken);
    await _loadMe();
  }

  /// Switches active workshop and reloads `/me` (new role/modules).
  Future<void> switchTenant(String tenantId) async {
    final tokens = await _auth.switchTenant(tenantId);
    _access.set(tokens.accessToken);
    await _secure.writeRefreshToken(tokens.refreshToken);
    await _loadMe();
  }

  Future<void> logout() async {
    final refreshToken = await _secure.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _auth.logout(refreshToken);
      } catch (_) {
        // Best-effort server revoke; local clear happens regardless.
      }
    }
    await _clear();
    state = const SessionState.unauthenticated();
  }

  /// Called by the network layer when refresh fails — drop to unauthenticated.
  Future<void> expire() async {
    await _clear();
    state = const SessionState.unauthenticated();
  }

  Future<void> reloadMe() => _loadMe();

  Future<void> _loadMe() async {
    final me = await _auth.fetchMe();
    state = SessionState.authenticated(me);
  }

  Future<void> _clear() async {
    _access.clear();
    await _secure.clear();
  }
}
