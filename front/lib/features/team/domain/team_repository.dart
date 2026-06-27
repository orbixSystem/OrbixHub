import 'team_models.dart';

/// Team management contract: list roles/employees/invites, send & manage invites,
/// and change member role / activation. Owner-gated operations require the
/// caller's current password; the backend enforces permissions, the client only
/// reflects them for UX. Real (dio) + fake impls, swapped via Riverpod.
abstract interface class TeamRepository {
  Future<List<RoleOption>> roles();

  Future<List<Employee>> employees();

  Future<List<PendingInvite>> pendingInvites();

  Future<void> invite({
    required String email,
    required String role,
    required String expiresIn,
    required String currentPassword,
    String? accessExpiresAt, // ISO 8601; when the member's ACCESS expires
  });

  Future<void> resendInvite(
    String inviteId, {
    required String expiresIn,
    required String currentPassword,
  });

  Future<void> cancelInvite(String inviteId);

  Future<void> changeRole({
    required String membershipId,
    required String role,
    required String currentPassword,
  });

  Future<void> deactivate({
    required String membershipId,
    required String currentPassword,
  });

  Future<void> activate({
    required String membershipId,
    required String currentPassword,
  });
}
