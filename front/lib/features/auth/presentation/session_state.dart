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

  /// Signed out — router sends to /login (except public routes).
  const factory SessionState.unauthenticated() = SessionUnauthenticated;

  /// Fatal/unexpected session error (e.g. bootstrap failure).
  const factory SessionState.error(String message) = SessionError;
}
