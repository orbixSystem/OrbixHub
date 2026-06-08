import 'auth_models.dart';

/// The contract the UI/session layer depends on. Implemented by the real dio
/// client ([AuthRepositoryImpl]) and by an in-memory fake ([FakeAuthRepository])
/// used in tests and offline development. Swapped via Riverpod injection.
///
/// Implementations throw [AppException] on failure (mapped from the backend
/// `{ statusCode, error, message }` envelope).
abstract interface class AuthRepository {
  Future<LoginResult> login({required String email, required String password});

  Future<RegisterResult> register({
    required String tenantName,
    required String slug,
    required String fullName,
    required String email,
    required String password,
  });

  Future<void> verifyEmail(String token);

  /// Always succeeds with a generic result (anti-enumeration), mirroring backend.
  Future<void> forgotPassword(String email);

  Future<void> resetPassword({required String token, required String newPassword});

  Future<Tokens> switchTenant(String tenantId);

  /// Exchanges a refresh token for a new pair. Used by bootstrap and by the
  /// network single-flight refresher on 401.
  Future<Tokens> refresh(String refreshToken);

  Future<void> logout(String refreshToken);

  /// The `/me` projection for the currently-active access token.
  Future<Me> fetchMe();
}
