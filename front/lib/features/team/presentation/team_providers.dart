import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../domain/team_models.dart';

/// Tenant members from `GET /employees`. autoDispose so re-entering the Team
/// screen always re-fetches (e.g. after someone accepts an invite elsewhere).
final teamEmployeesProvider =
    FutureProvider.autoDispose<List<Employee>>((ref) {
  return ref.read(teamRepositoryProvider).employees();
});

/// Pending invitations from `GET /invites`. autoDispose (see above).
final pendingInvitesProvider =
    FutureProvider.autoDispose<List<PendingInvite>>((ref) {
  return ref.read(teamRepositoryProvider).pendingInvites();
});

/// Selectable roles from `GET /roles` (informational permissions per role).
final teamRolesProvider = FutureProvider<List<RoleOption>>((ref) {
  return ref.read(teamRepositoryProvider).roles();
});
