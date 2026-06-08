import '../../../core/error/app_exception.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// In-memory [AuthRepository] mirroring the backend contract. Used for offline
/// development and widget/unit tests. Behaviour is seedable via the constructor.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    Me? me,
    List<Membership>? loginMemberships,
    this.failRefresh = false,
  })  : _me = me ?? _defaultMe,
        _loginMemberships = loginMemberships ?? const [
          Membership(
            tenantId: 't1',
            tenantSlug: 'oficina-teste',
            role: 'owner',
          ),
        ];

  Me _me;
  final List<Membership> _loginMemberships;

  /// When true, [refresh] throws a 401 [AppException] (simulates expired family).
  bool failRefresh;

  int loginCount = 0;
  int refreshCount = 0;
  int logoutCount = 0;

  static const _defaultUser = User(
    id: 'u1',
    email: 'dono@teste.com',
    fullName: 'Dono Teste',
    emailVerified: true,
  );

  static const _defaultMe = Me(
    user: _defaultUser,
    activeTenant: Tenant(id: 't1', slug: 'oficina-teste', name: 'Oficina Teste'),
    role: 'owner',
    permissions: ['os.read', 'os.write', 'billing.manage', 'tenant.manage'],
    modules: ['os', 'customers'],
    memberships: [
      Membership(tenantId: 't1', tenantSlug: 'oficina-teste', role: 'owner'),
    ],
  );

  void seedMe(Me me) => _me = me;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    loginCount++;
    return LoginResult(
      accessToken: 'fake-access',
      refreshToken: 'fake-refresh',
      user: _me.user,
      memberships: _loginMemberships,
    );
  }

  @override
  Future<RegisterResult> register({
    required String tenantName,
    required String slug,
    required String fullName,
    required String email,
    required String password,
  }) async {
    return RegisterResult(
      accessToken: 'fake-access',
      refreshToken: 'fake-refresh',
      user: User(id: 'u-new', email: email, fullName: fullName),
      tenant: Tenant(id: 't-new', slug: slug, name: tenantName),
    );
  }

  @override
  Future<void> verifyEmail(String token) async {}

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<Tokens> acceptInvite({
    required String token,
    String? fullName,
    required String password,
  }) async =>
      const Tokens(accessToken: 'fake-access', refreshToken: 'fake-refresh');

  @override
  Future<Tokens> switchTenant(String tenantId) async =>
      const Tokens(accessToken: 'fake-access-2', refreshToken: 'fake-refresh-2');

  @override
  Future<Tokens> refresh(String refreshToken) async {
    refreshCount++;
    if (failRefresh) {
      throw const AppException(
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Sessão expirada.',
      );
    }
    return const Tokens(accessToken: 'fake-access-2', refreshToken: 'fake-refresh-2');
  }

  @override
  Future<void> logout(String refreshToken) async {
    logoutCount++;
  }

  @override
  Future<Me> fetchMe() async => _me;
}
