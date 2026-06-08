import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../domain/team_models.dart';

/// Tenant members from `GET /employees`.
final teamEmployeesProvider = FutureProvider<List<Employee>>((ref) {
  return ref.read(teamRepositoryProvider).employees();
});

/// Pending invitations from `GET /invites`.
final pendingInvitesProvider = FutureProvider<List<PendingInvite>>((ref) {
  return ref.read(teamRepositoryProvider).pendingInvites();
});

/// Selectable roles from `GET /roles` (informational permissions per role).
final teamRolesProvider = FutureProvider<List<RoleOption>>((ref) {
  return ref.read(teamRepositoryProvider).roles();
});
