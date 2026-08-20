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
    required String cnpj,
    required String legalName,
    String? tradeName,
    required String fullName,
    required String email,
    required String password,
    /// Nicho escolhido no cadastro. null = pacote padrão do servidor.
    String? vertical,
  });

  /// Catálogo de nichos para a tela de cadastro. Vem do servidor — nicho
  /// hardcoded no app seria a mesma dívida que planos e módulos já não têm.
  Future<List<VerticalOption>> listVerticals();

  /// Consulta pública de dados da empresa pelo CNPJ (pré-cadastro).
  /// Lança [AppException] (400 inválido, 404 não encontrado, 503 fonte fora).
  Future<CnpjCompany> lookupCnpj(String cnpj);

  Future<void> verifyEmail(String token);

  /// Always succeeds with a generic result (anti-enumeration), mirroring backend.
  Future<void> forgotPassword(String email);

  Future<void> resetPassword({required String token, required String newPassword});

  /// Accepts a team invite (public). Returns a fresh token pair on success;
  /// throws [AppException] (400, generic message) on invalid/expired/used token.
  Future<Tokens> acceptInvite({
    required String token,
    String? fullName,
    required String password,
  });

  Future<Tokens> switchTenant(String tenantId);

  /// Exchanges a refresh token for a new pair. Used by bootstrap and by the
  /// network single-flight refresher on 401.
  Future<Tokens> refresh(String refreshToken);

  Future<void> logout(String refreshToken);

  /// The `/me` projection for the currently-active access token.
  Future<Me> fetchMe();
}
