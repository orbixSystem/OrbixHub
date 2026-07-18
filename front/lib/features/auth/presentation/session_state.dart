import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/auth_models.dart';

part 'session_state.freezed.dart';

/// Sealed session state driving routing, guards and the shell. Consume with Dart
/// pattern matching (`switch`), e.g.:
///   switch (state) { SessionAuthenticated(:final me) => ..., _ => ... }
@freezed
sealed class SessionState with _$SessionState {
  /// Initial / in-flight (bootstrap, login, switch-tenant).
  const factory SessionState.loading() = SessionLoading;

  /// Signed in; [me] is the `/me` projection (role, permissions, modules).
  const factory SessionState.authenticated(Me me) = SessionAuthenticated;

  /// B6 — sessão OFFLINE: o usuário provou a senha contra o hash argon2id local
  /// e [me] é o snapshot do último `/me` online. Vale como "logado" para o
  /// router/guards (módulos offline); nada aqui dispara rede.
  const factory SessionState.offline(Me me) = SessionOffline;

  /// Signed out — router sends to /login (except public routes).
  const factory SessionState.unauthenticated() = SessionUnauthenticated;

  /// Fatal/unexpected session error (e.g. bootstrap failure).
  const factory SessionState.error(String message) = SessionError;
}

/// Açúcar para os consumidores: a sessão tem `me` tanto online quanto offline.
/// **Use [meOrNull] em vez de `is SessionAuthenticated`** ao ler papel/permissões/
/// módulos — senão a sessão offline (B6) some da UI.
extension SessionStateX on SessionState {
  /// O `/me` da sessão (online ou offline), ou `null` se não há sessão.
  Me? get meOrNull => switch (this) {
        SessionAuthenticated(:final me) => me,
        SessionOffline(:final me) => me,
        _ => null,
      };

  /// `true` quando há sessão (online OU offline) — o que o router considera
  /// autenticado.
  bool get isSignedIn => meOrNull != null;

  /// `true` só no modo offline (B6) — telas online-only (B9) se apoiam nisto.
  bool get isOffline => this is SessionOffline;
}
