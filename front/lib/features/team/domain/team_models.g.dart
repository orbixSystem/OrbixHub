// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoleOption _$RoleOptionFromJson(Map<String, dynamic> json) => _RoleOption(
  key: json['key'] as String,
  name: json['name'] as String,
  permissions:
      (json['permissions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
);

Map<String, dynamic> _$RoleOptionToJson(_RoleOption instance) =>
    <String, dynamic>{
      'key': instance.key,
      'name': instance.name,
      'permissions': instance.permissions,
    };

_Employee _$EmployeeFromJson(Map<String, dynamic> json) => _Employee(
  membershipId: json['membershipId'] as String,
  userId: json['userId'] as String,
  fullName: json['fullName'] as String,
  email: json['email'] as String,
  role: json['role'] as String,
  status: json['status'] as String,
  lastAccess: json['lastAccess'] == null
      ? null
      : DateTime.parse(json['lastAccess'] as String),
  accessExpiresAt: json['accessExpiresAt'] == null
      ? null
      : DateTime.parse(json['accessExpiresAt'] as String),
);

Map<String, dynamic> _$EmployeeToJson(_Employee instance) => <String, dynamic>{
  'membershipId': instance.membershipId,
  'userId': instance.userId,
  'fullName': instance.fullName,
  'email': instance.email,
  'role': instance.role,
  'status': instance.status,
  'lastAccess': instance.lastAccess?.toIso8601String(),
  'accessExpiresAt': instance.accessExpiresAt?.toIso8601String(),
};

_PendingInvite _$PendingInviteFromJson(Map<String, dynamic> json) =>
    _PendingInvite(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$PendingInviteToJson(_PendingInvite instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'role': instance.role,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
    };
