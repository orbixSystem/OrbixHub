// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  email: json['email'] as String,
  fullName: json['fullName'] as String,
  emailVerified: json['emailVerified'] as bool? ?? false,
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'fullName': instance.fullName,
  'emailVerified': instance.emailVerified,
};

_Tenant _$TenantFromJson(Map<String, dynamic> json) => _Tenant(
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  cnpj: json['cnpj'] as String?,
  legalName: json['legalName'] as String?,
  tradeName: json['tradeName'] as String?,
);

Map<String, dynamic> _$TenantToJson(_Tenant instance) => <String, dynamic>{
  'id': instance.id,
  'slug': instance.slug,
  'name': instance.name,
  'cnpj': instance.cnpj,
  'legalName': instance.legalName,
  'tradeName': instance.tradeName,
};

_Membership _$MembershipFromJson(Map<String, dynamic> json) => _Membership(
  tenantId: json['tenantId'] as String,
  tenantSlug: json['tenantSlug'] as String,
  role: json['role'] as String,
);

Map<String, dynamic> _$MembershipToJson(_Membership instance) =>
    <String, dynamic>{
      'tenantId': instance.tenantId,
      'tenantSlug': instance.tenantSlug,
      'role': instance.role,
    };

_Me _$MeFromJson(Map<String, dynamic> json) => _Me(
  user: User.fromJson(json['user'] as Map<String, dynamic>),
  activeTenant: json['activeTenant'] == null
      ? null
      : Tenant.fromJson(json['activeTenant'] as Map<String, dynamic>),
  role: json['role'] as String,
  permissions:
      (json['permissions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  modules:
      (json['modules'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  vertical: json['vertical'] as String?,
  vocab:
      (json['vocab'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  features:
      (json['features'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  memberships:
      (json['memberships'] as List<dynamic>?)
          ?.map((e) => Membership.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Membership>[],
);

Map<String, dynamic> _$MeToJson(_Me instance) => <String, dynamic>{
  'user': instance.user.toJson(),
  'activeTenant': instance.activeTenant?.toJson(),
  'role': instance.role,
  'permissions': instance.permissions,
  'modules': instance.modules,
  'vertical': instance.vertical,
  'vocab': instance.vocab,
  'features': instance.features,
  'memberships': instance.memberships.map((e) => e.toJson()).toList(),
};

_Tokens _$TokensFromJson(Map<String, dynamic> json) => _Tokens(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
);

Map<String, dynamic> _$TokensToJson(_Tokens instance) => <String, dynamic>{
  'accessToken': instance.accessToken,
  'refreshToken': instance.refreshToken,
};

_CnpjCompany _$CnpjCompanyFromJson(Map<String, dynamic> json) => _CnpjCompany(
  cnpj: json['cnpj'] as String,
  razaoSocial: json['razaoSocial'] as String,
  nomeFantasia: json['nomeFantasia'] as String?,
  situacao: json['situacao'] as String?,
  municipio: json['municipio'] as String?,
  uf: json['uf'] as String?,
  alreadyRegistered: json['alreadyRegistered'] as bool? ?? false,
);

Map<String, dynamic> _$CnpjCompanyToJson(_CnpjCompany instance) =>
    <String, dynamic>{
      'cnpj': instance.cnpj,
      'razaoSocial': instance.razaoSocial,
      'nomeFantasia': instance.nomeFantasia,
      'situacao': instance.situacao,
      'municipio': instance.municipio,
      'uf': instance.uf,
      'alreadyRegistered': instance.alreadyRegistered,
    };

_LoginResult _$LoginResultFromJson(Map<String, dynamic> json) => _LoginResult(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
  user: User.fromJson(json['user'] as Map<String, dynamic>),
  memberships:
      (json['memberships'] as List<dynamic>?)
          ?.map((e) => Membership.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Membership>[],
);

Map<String, dynamic> _$LoginResultToJson(_LoginResult instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'user': instance.user.toJson(),
      'memberships': instance.memberships.map((e) => e.toJson()).toList(),
    };

_RegisterResult _$RegisterResultFromJson(Map<String, dynamic> json) =>
    _RegisterResult(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      tenant: Tenant.fromJson(json['tenant'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RegisterResultToJson(_RegisterResult instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'user': instance.user.toJson(),
      'tenant': instance.tenant.toJson(),
    };

_VerticalOption _$VerticalOptionFromJson(Map<String, dynamic> json) =>
    _VerticalOption(
      key: json['key'] as String,
      nome: json['nome'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$VerticalOptionToJson(_VerticalOption instance) =>
    <String, dynamic>{
      'key': instance.key,
      'nome': instance.nome,
      'isDefault': instance.isDefault,
    };
