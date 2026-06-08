import '../domain/team_models.dart';
import '../domain/team_repository.dart';

/// In-memory [TeamRepository] mirroring the contract for tests/offline. Invite
/// mutations are reflected in [pendingInvites] so flows can be exercised end to
/// end without a backend.
class FakeTeamRepository implements TeamRepository {
  FakeTeamRepository({
    List<RoleOption>? roles,
    List<Employee>? employees,
    List<PendingInvite>? invites,
  })  : _roles = roles ?? List.of(_defaultRoles),
        _employees = employees ?? List.of(_defaultEmployees),
        _invites = invites ?? List.of(_defaultInvites);

  final List<RoleOption> _roles;
  final List<Employee> _employees;
  final List<PendingInvite> _invites;

  var _nextInviteId = 100;

  static const _defaultRoles = [
    RoleOption(
      key: 'owner',
      name: 'Proprietário',
      permissions: [
        'billing.manage',
        'team.manage',
        'os.manage',
        'inventory.manage',
        'cash.manage',
      ],
    ),
    RoleOption(
      key: 'gerente',
      name: 'Gerente',
      permissions: ['team.manage', 'os.manage', 'inventory.manage'],
    ),
    RoleOption(
      key: 'mechanic',
      name: 'Mecânico',
      permissions: ['os.read', 'os.update'],
    ),
    RoleOption(
      key: 'caixa',
      name: 'Caixa',
      permissions: ['cash.manage', 'os.read'],
    ),
  ];

  static final _defaultEmployees = [
    Employee(
      membershipId: 'm-1',
      userId: 'u-1',
      fullName: 'Ana Owner',
      email: 'ana@oficina.com',
      role: 'owner',
      status: 'active',
      lastAccess: DateTime.utc(2026, 6, 5, 14, 30),
    ),
    Employee(
      membershipId: 'm-2',
      userId: 'u-2',
      fullName: 'Bruno Mecânico',
      email: 'bruno@oficina.com',
      role: 'mechanic',
      status: 'active',
      lastAccess: DateTime.utc(2026, 6, 4, 9),
    ),
  ];

  static final _defaultInvites = [
    PendingInvite(
      id: 'inv-1',
      email: 'carla@oficina.com',
      role: 'caixa',
      expiresAt: DateTime.utc(2026, 6, 12),
      createdAt: DateTime.utc(2026, 6, 5),
    ),
  ];

  @override
  Future<List<RoleOption>> roles() async => List.of(_roles);

  @override
  Future<List<Employee>> employees() async => List.of(_employees);

  @override
  Future<List<PendingInvite>> pendingInvites() async => List.of(_invites);

  @override
  Future<void> invite({
    required String email,
    required String role,
    required String expiresIn,
    required String currentPassword,
    String? accessExpiresAt,
  }) async {
    _invites.add(
      PendingInvite(
        id: 'inv-${_nextInviteId++}',
        email: email,
        role: role,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> resendInvite(
    String inviteId, {
    required String expiresIn,
    required String currentPassword,
  }) async {
    final i = _invites.indexWhere((inv) => inv.id == inviteId);
    if (i != -1) {
      _invites[i] = _invites[i].copyWith(
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
    }
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    _invites.removeWhere((inv) => inv.id == inviteId);
  }

  @override
  Future<void> changeRole({
    required String membershipId,
    required String role,
    required String currentPassword,
  }) async {
    final i = _employees.indexWhere((e) => e.membershipId == membershipId);
    if (i != -1) {
      _employees[i] = _employees[i].copyWith(role: role);
    }
  }

  @override
  Future<void> deactivate({
    required String membershipId,
    required String currentPassword,
  }) async {
    final i = _employees.indexWhere((e) => e.membershipId == membershipId);
    if (i != -1) {
      _employees[i] = _employees[i].copyWith(status: 'inactive');
    }
  }

  @override
  Future<void> activate({
    required String membershipId,
    required String currentPassword,
  }) async {
    final i = _employees.indexWhere((e) => e.membershipId == membershipId);
    if (i != -1) {
      _employees[i] = _employees[i].copyWith(status: 'active');
    }
  }
}
