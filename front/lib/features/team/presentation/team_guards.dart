import '../../auth/domain/auth_models.dart';
import '../domain/team_models.dart';

/// Which actions the current user [me] may take on [target], given the full
/// [employees] list. Mirrors the backend guardrails (which remain source of truth).
class TeamActions {
  const TeamActions({required this.canChangeRole, required this.canDeactivate, required this.canAssignOwner});
  final bool canChangeRole;   // false for self
  final bool canDeactivate;   // false for self or the last active owner
  final bool canAssignOwner;  // only an owner may grant the owner role
}

TeamActions teamActions(Me me, Employee target, List<Employee> employees) {
  final isSelf = target.userId == me.user.id;
  final activeOwners = employees.where((e) => e.role == 'owner' && e.status == 'active').length;
  final isLastActiveOwner = target.role == 'owner' && target.status == 'active' && activeOwners <= 1;
  return TeamActions(
    // No one edits an owner's role (not even another owner) — the option is
    // hidden entirely, never just disabled. Also never for self.
    canChangeRole: !isSelf && target.role != 'owner',
    canDeactivate: !isSelf && !isLastActiveOwner,
    canAssignOwner: me.role == 'owner',
  );
}
