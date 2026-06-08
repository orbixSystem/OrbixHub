import 'package:freezed_annotation/freezed_annotation.dart';

part 'team_models.freezed.dart';
part 'team_models.g.dart';

/// A selectable role from `GET /roles`. The `permissions` list is informational
/// (rendered for the admin); the backend remains the source of truth.
@freezed
abstract class RoleOption with _$RoleOption {
  const factory RoleOption({
    required String key,
    required String name,
    @Default(<String>[]) List<String> permissions,
  }) = _RoleOption;

  factory RoleOption.fromJson(Map<String, dynamic> json) =>
      _$RoleOptionFromJson(json);
}

/// A tenant member from `GET /employees`.
@freezed
abstract class Employee with _$Employee {
  const factory Employee({
    required String membershipId,
    required String userId,
    required String fullName,
    required String email,
    required String role,
    required String status,
    DateTime? lastAccess,
    DateTime? accessExpiresAt,
  }) = _Employee;

  factory Employee.fromJson(Map<String, dynamic> json) =>
      _$EmployeeFromJson(json);
}

/// A pending invitation from `GET /invites`.
@freezed
abstract class PendingInvite with _$PendingInvite {
  const factory PendingInvite({
    required String id,
    required String email,
    required String role,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) = _PendingInvite;

  factory PendingInvite.fromJson(Map<String, dynamic> json) =>
      _$PendingInviteFromJson(json);
}
