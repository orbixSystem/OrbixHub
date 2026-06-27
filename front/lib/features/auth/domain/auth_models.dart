import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

/// The authenticated user. `emailVerified` is absent on login/register payloads
/// (defaults false) and present on `/me`.
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String fullName,
    @Default(false) bool emailVerified,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

/// The active tenant (workshop) on `/me`.
@freezed
abstract class Tenant with _$Tenant {
  const factory Tenant({
    required String id,
    required String slug,
    required String name,
    String? cnpj,
    String? legalName,
    String? tradeName,
  }) = _Tenant;

  factory Tenant.fromJson(Map<String, dynamic> json) => _$TenantFromJson(json);
}

/// One workshop the user belongs to, with the role held there.
@freezed
abstract class Membership with _$Membership {
  const factory Membership({
    required String tenantId,
    required String tenantSlug,
    required String role,
  }) = _Membership;

  factory Membership.fromJson(Map<String, dynamic> json) =>
      _$MembershipFromJson(json);
}

/// The `/me` projection — the single source of truth driving the UI: role,
/// permissions and enabled modules.
@freezed
abstract class Me with _$Me {
  const Me._();

  const factory Me({
    required User user,
    Tenant? activeTenant,
    required String role,
    @Default(<String>[]) List<String> permissions,
    @Default(<String>[]) List<String> modules,
    @Default(<Membership>[]) List<Membership> memberships,
  }) = _Me;

  factory Me.fromJson(Map<String, dynamic> json) => _$MeFromJson(json);

  bool hasModule(String key) => modules.contains(key);
  bool hasPermission(String key) => permissions.contains(key);
  bool get hasMultipleTenants => memberships.length > 1;
}

/// A token pair. `switch-tenant` and `refresh` return exactly this.
@freezed
abstract class Tokens with _$Tokens {
  const factory Tokens({
    required String accessToken,
    required String refreshToken,
  }) = _Tokens;

  factory Tokens.fromJson(Map<String, dynamic> json) =>
      _$TokensFromJson(json);
}

/// Dados públicos de empresa retornados por `POST /auth/cnpj-lookup` no
/// pré-cadastro (proxy do backend para a Receita).
@freezed
abstract class CnpjCompany with _$CnpjCompany {
  const factory CnpjCompany({
    required String cnpj,
    required String razaoSocial,
    String? nomeFantasia,
    String? situacao,
    String? municipio,
    String? uf,
    @Default(false) bool alreadyRegistered,
  }) = _CnpjCompany;

  factory CnpjCompany.fromJson(Map<String, dynamic> json) =>
      _$CnpjCompanyFromJson(json);
}

/// `POST /auth/login` response.
@freezed
abstract class LoginResult with _$LoginResult {
  const factory LoginResult({
    required String accessToken,
    required String refreshToken,
    required User user,
    @Default(<Membership>[]) List<Membership> memberships,
  }) = _LoginResult;

  factory LoginResult.fromJson(Map<String, dynamic> json) =>
      _$LoginResultFromJson(json);
}

/// `POST /auth/register` response (creates the workshop + trial).
@freezed
abstract class RegisterResult with _$RegisterResult {
  const factory RegisterResult({
    required String accessToken,
    required String refreshToken,
    required User user,
    required Tenant tenant,
  }) = _RegisterResult;

  factory RegisterResult.fromJson(Map<String, dynamic> json) =>
      _$RegisterResultFromJson(json);
}
